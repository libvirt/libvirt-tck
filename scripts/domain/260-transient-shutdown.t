#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2009 Red Hat, Inc.
# Copyright (C) 2009 Daniel P. Berrange
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

domain/260-transient-shutdown.t - Transient domain shutdown

=head1 DESCRIPTION

The test case validates that gracefully shutting down a transient
domain removes all trace of the domain.

=cut

use strict;
use warnings;

use Test::More tests => 2;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_domain(name => "tck", fullos => 1,
                               netmode => "network")->as_xml;

diag "Creating a transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

$tck->wait_for_vm_to_boot($dom);
$dom->shutdown();

ok_error(sub {
    my $timeout = 30;
    eval {
        local $SIG{ALRM} = sub {
            die "timeout while waiting for transient domain to shutdown\n";
        };

        alarm($timeout);
        while (1) {
            sleep(1);
            $conn->get_domain_by_name("tck");
        }
    };
    my $err = $@;
    alarm(0);
    die $err if $err;
}, "NO_DOMAIN error raised after shutdown",
	 Sys::Virt::Error::ERR_NO_DOMAIN);

# end
