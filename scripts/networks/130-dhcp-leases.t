#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2014 Red Hat, Inc.
# Copyright (C) 2014 Zhe Peng <zpeng@redhat.com>
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

networks/130-dhcp-leases.t

=head1 DESCRIPTION

The test case validates below APIs and flags:

$net->get_dhcp_leases


=cut

use strict;
use warnings;

use Test::More tests => 6;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

#Create a transient network

my $net_xml = $tck->generic_network("tck")->as_xml;

diag "Creating a new transient network";
my $net;
ok_network(sub { $net = $conn->create_network($net_xml) }, "created transient network object");

my $network = $conn->get_network_by_name("tck");

lives_ok(sub {$network->get_dhcp_leases();}, "Get leases for all VMs" );

#Create a transient guest with mac

my $mac = "52:54:00:22:22:22";

my $xml = $tck->generic_domain(name => "tck")
              ->interface(type => "network", source => "tck", model => "virtio", mac => $mac)
              ->as_xml;

my $dom;

ok_domain(sub { $dom = $conn->create_domain($xml) }, "Created a domain");

lives_ok(sub {$network->get_dhcp_leases($mac,0);}, "Get leases for one VM with mac address" );

is(Sys::Virt::IP_ADDR_TYPE_IPV4, 0, "Check type ipv4 constants value");
is(Sys::Virt::IP_ADDR_TYPE_IPV6, 1, "Check type ipv6 constants value");

