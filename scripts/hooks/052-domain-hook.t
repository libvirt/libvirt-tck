# -*- perl -*-
#
# Copyright (C) 2010 Red Hat, Inc.
# Copyright (C) 2010 Osier Yang
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

domain/052-domain-hook.t - domain hook testing

=head1 DESCRIPTION

This test case validates that the hook for QEMU or LXC domain is
invoked correctly while start/stop domain, and if the exit status
of testing hook script is 0, it expects domain could be started and
stopped successfully. Otherwise, it expects domain 'start' will be
failed, 'stop' is fine.

=cut

use strict;
use warnings;

use File::Slurp;

use Test::More tests => 12;

use Sys::Virt::TCK;
use Sys::Virt::TCK::Hooks;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

SKIP: {
    my $uri = $conn->get_uri();

    skip "NOT using QEMU/LXC driver", 12 unless
        $uri eq "qemu:///system" or $uri eq "lxc:///";

    my $xml = $tck->generic_domain(name => "tck")->as_xml;

    diag "Creating a new persistent domain";
    my $dom;
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

    my $hook_type = $uri eq "qemu:///system" ? 'qemu' : 'lxc';

    my $hook = Sys::Virt::TCK::Hooks->new(type => $hook_type,
                                          conf_dir => '/etc/libvirt/hooks',
                                          expect_result => 0);
    eval { $hook->prepare(); };
    BAIL_OUT "failed to setup hooks testing ENV: $@" if $@;

    diag "reload libvirtd for hooks scripts taking effect";
    $hook->action('reload');
    $hook->service_libvirtd();

    # start domain
    my $domain_state = $dom->get_info()->{state};
    my $domain_name = $dom->get_name();

    $hook->domain_name($domain_name);
    $hook->domain_state($domain_state);
    $hook->action('start');
    $hook->expect_log();

    diag "start $domain_name";
    $dom->create();

    diag "check if the domain is running";
    $domain_state = $dom->get_info()->{state};
    ok($domain_state eq &Sys::Virt::Domain::STATE_RUNNING, "domain is running");

    my $hook_data = read_file($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    my $actual_log_data = read_file($hook->{log_name});
    diag "actual log: $hook->{log_name} '$actual_log_data'";

    diag "expect log:\n $hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log, "$hook->{name} is invoked correctly while start $domain_name");

    diag "truncate $hook->{log_name}";
    truncate $hook->{log_name}, 0 if -f $hook->{log_name};

    # stop domain
    $domain_state = $dom->get_info()->{state};

    $hook->domain_state($domain_state);
    $hook->action('destroy');
    $hook->expect_log();

    diag "destroy $domain_name";
    $dom->destroy();

    diag "check if the domain is shut off";
    $domain_state = $dom->get_info()->{state};
    ok($domain_state eq &Sys::Virt::Domain::STATE_SHUTOFF, "domain is shut off");

    $hook_data = read_file($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    $actual_log_data = read_file($hook->{log_name});
    diag "acutal log: $hook->{log_name} '$actual_log_data'";

    diag "expect log:\n $hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log(), "$hook->{name} is invoked correctly while start $domain_name");

    $hook->cleanup();

    # Create a new testing hook script with exit status is 1.
    $hook = Sys::Virt::TCK::Hooks->new(type => $hook_type,
                                          conf_dir => '/etc/libvirt/hooks',
                                          expect_result => 1);
    eval { $hook->prepare(); };
    BAIL_OUT "failed to setup hooks testing ENV: $@" if $@;

    diag "reload libvirtd for hooks scripts taking effect";
    $hook->action('reload');
    $hook->service_libvirtd();

    # start domain once more after the testing hook script is changed.
    $domain_state = $dom->get_info()->{state};
    $domain_name = $dom->get_name();

    $hook->domain_name($domain_name);
    $hook->domain_state($domain_state);
    $hook->action('failstart');
    $hook->expect_log();

    diag "start $domain_name";
    eval { $dom->create(); };
    ok($@, $@);

    diag "check if the domain is running";
    $domain_state = $dom->get_info()->{state};
    ok($domain_state eq &Sys::Virt::Domain::STATE_SHUTOFF, "domain is not started ");

    $hook_data = read_file($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    $actual_log_data = read_file($hook->{log_name});
    diag "acutal log: $hook->{log_name} '$actual_log_data'";

    diag "expect log:\n $hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log, "$hook->{name} is invoked correctly while failing to start $domain_name");

    # undefine domain
    diag "undefine $domain_name";
    $dom->undefine();

    ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
         Sys::Virt::Error::ERR_NO_DOMAIN);

    $hook->cleanup();

    diag "reload libvirtd after hook cleanup";
    $hook->action('reload');
    $hook->service_libvirtd();
};
