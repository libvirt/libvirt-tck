#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2026 The FreeBSD Foundation
#
# This program is free software; You can redistribute it and/or modify
# it under the GNU General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any
# later version
#
# The file "LICENSE" distributed along with this file provides full
# details of the terms and conditions
#

=pod

=head1 NAME

domain/500-guest-agent-reboot-shutdown.t - Test reboot and shutdown using the guest agent

=head1 DESCRIPTION

This test validates that reboot and shutdown via the guest agent works.

=cut

use strict;
use warnings;

use Test::More tests => 5;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink "tck.img" if -f "tck.img";
}

my $type = $conn->get_type();
my $domain = eval {
    $tck->generic_domain(
        name => "tck",
        fullos => 1,
        image_features => ["qga"],
    );
};

if ($@) {
    die $@ unless $@ =~ /cannot find any supported image configuration/;

    SKIP: {
        skip "no image with QEMU guest agent support", 5;
    }
    exit 0;
}

$domain->channel(
    mode => "bind",
    path => "/var/run/libvirt/" . lc($type) . "/tck.agent",
    type => "unix",
    name => "org.qemu.guest_agent.0",
);
my $xml = $domain->as_xml;

diag "Creating a new persistent domain";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

diag "Starting inactive domain";
$dom->create;
ok($dom->get_id > 0, "running domain with ID > 0");
$dom->set_agent_response_timeout(10);

my $hostname;
my $agent_ready = 0;
my $timeout = 120;

eval {
    local $SIG{ALRM} = sub { die "timeout\n" };

    diag "Waiting $timeout seconds for QEMU guest agent";
    alarm($timeout);

    while (1) {
        sleep(5);

        eval { $hostname = $dom->get_hostname(Sys::Virt::Domain::GET_HOSTNAME_AGENT) };

        if (!$@ && defined $hostname && $hostname ne '') {
            $agent_ready = 1;
            last;
        }
    }

    alarm(0);
};

if ($@) {
    die $@ unless $@ eq "timeout\n";
}

SKIP: {
    skip "QEMU guest agent did not respond within $timeout seconds", 3 unless $agent_ready;

    $dom->reboot(Sys::Virt::Domain::REBOOT_GUEST_AGENT);
    my $reboot_successful = 0;

    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm($timeout);

        diag "Waiting for guest agent to go offline (reboot initiating)";
        while (1) {
            sleep(1);
            my $hostname;
            eval { $hostname = $dom->get_hostname(Sys::Virt::Domain::GET_HOSTNAME_AGENT) };

            if ($@ || !defined $hostname || $hostname eq '') {
                diag "Guest agent is offline.";
                last;
            }
        }

        diag "Waiting for guest agent to come back online (reboot finishing)";
        while (1) {
            sleep(5);
            my $hostname;
            eval { $hostname = $dom->get_hostname(Sys::Virt::Domain::GET_HOSTNAME_AGENT) };

            if (!$@ && defined $hostname && $hostname ne '') {
                diag "Guest agent is back online.";
                $reboot_successful = 1;
                last;
            }
        }

        alarm(0);
    };

    if ($@ && $@ ne "timeout\n") {
        diag "Unexpected error during reboot check: $@";
    }

    ok($reboot_successful, "Guest rebooted successfully (agent went offline and returned)");
    ok($dom->get_state() == Sys::Virt::Domain::STATE_RUNNING, "Domain is running");

    $dom->shutdown(Sys::Virt::Domain::SHUTDOWN_GUEST_AGENT);
    my $shutdown_successful = 0;

    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(60);

        while (1) {
            sleep(1);

            my ($state, $reason) = $dom->get_state();

            if ($state == Sys::Virt::Domain::STATE_SHUTOFF) {
                $shutdown_successful = 1;
                last;
            }
        }
        alarm(0);
    };

    ok($shutdown_successful, "Domain transitioned to shutoff state via guest agent");
}
