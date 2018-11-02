# -*- perl -*-
#
# Copyright (C) 2018 Red Hat, Inc.
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

network/370-guest-network-passthrough.t - guest connect to passthrough network

=head1 DESCRIPTION

This test case validates that a guest is connected to a passthrough
virtual network

=cut

use strict;
use warnings;

use Test::More tests => 4;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $hostnet = $tck->get_host_network_device();

SKIP: {
    skip "No host device available", 4 unless $hostnet;

    my $b = Sys::Virt::TCK::NetworkBuilder->new(name => "tck");
    $b->forward(mode => "passthrough");
    $b->interfaces($hostnet);
    my $xml = $b->as_xml();

    diag "Creating a new transient network";
    diag $xml;
    my $net;
    ok_network(sub { $net = $conn->create_network($xml) }, "created transient network object");

    $b = $tck->generic_domain(name => "tck");
    $b->interface(type => "network",
		  source => "tck",
		  model => "virtio",
		  mac => "52:54:00:11:11:11");
    $xml = $b->as_xml();

    diag "Creating a new transient domain";
    diag $xml;
    my $dom;
    ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

    diag "Destroying the transient guest";
    $dom->destroy;

    diag "Checking that transient domain has gone away";
    ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	     Sys::Virt::Error::ERR_NO_DOMAIN);

    diag "Destroying the transient network";
    $net->destroy;

    diag "Checking that transient network has gone away";
    ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	     Sys::Virt::Error::ERR_NO_NETWORK);
}

# end
