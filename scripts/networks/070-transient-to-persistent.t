#!/usr/bin/env perl
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

network/070-transient-to-persistent.t - Converting transient to persistent

=head1 DESCRIPTION

The test case validates that a transient network can be converted
to a persistent one. This is achieved by defining a configuration
file while the transient network is running.

=cut

use strict;
use warnings;

use Test::More tests => 4;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_network("tck")->as_xml;

diag "Creating a new transient network";
my $dom;
ok_network(sub { $dom = $conn->create_network($xml) }, "created transient network");

my $livexml = $dom->get_xml_description();

diag "Defining config for transient network";
my $dom1;
ok_network(sub { $dom1 = $conn->define_network($livexml) }, "defined transient network");

diag "Destroying active network";
$dom->destroy;

diag "Checking that an inactive network config still exists";
ok_network(sub { $dom1 = $conn->get_network_by_name("tck") }, "transient network config");

diag "Removing inactive network config";
$dom->undefine;

diag "Checking that inactive network has really gone";
ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	 Sys::Virt::Error::ERR_NO_NETWORK);
