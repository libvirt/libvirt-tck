#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2009 Red Hat, Inc.
# Copyright (C) 2009 Daniel P. Berrange
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

network/050-transient-lifecycle.t - Transient network lifecycle

=head1 DESCRIPTION

The test case validates the core lifecycle operations on
transient networks. A transient network has no configuration
file so, once destroyed, all trace of the network should
disappear.

=cut

use strict;
use warnings;

use Test::More tests => 2;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_network("tck")->as_xml;

diag "Creating a new transient network";
my $net;
ok_network(sub { $net = $conn->create_network($xml) }, "created transient network object");

diag "Destroying the transient network";
$net->destroy;

diag "Checking that transient network has gone away";
ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	 Sys::Virt::Error::ERR_NO_NETWORK);

# end
