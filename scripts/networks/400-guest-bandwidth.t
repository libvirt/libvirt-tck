# -*- perl -*-
#
# Copyright (C) 2019 Red Hat, Inc.
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

network/400-guest-bandwidth.t - guest with bandwidth limits

=head1 DESCRIPTION

This test case validates that a guest is connected a network
can have bandwidth limits set

=cut

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my %subnet = Sys::Virt::TCK->find_free_ipv4_subnet();

SKIP: {
    skip "No available IPv4 subnet", 4 unless defined $subnet{address};

    my $netbuilder = Sys::Virt::TCK::NetworkBuilder->new(name => "tck");
    $netbuilder->bridge("tck");
    $netbuilder->ipaddr($subnet{address}, $subnet{netmask});
    $netbuilder->dhcp_range($subnet{dhcpstart}, $subnet{dhcpend});
    my $netxml = $netbuilder->as_xml();

    diag "Creating a new transient network";
    diag $netxml;
    my $net;
    ok_network(sub { $net = $conn->create_network($netxml) }, "created transient network object");

    my $dombuilder = $tck->generic_domain(name => "tck");
    $dombuilder->interface(type => "network",
		  source => "tck",
		  model => "virtio",
		  mac => "52:54:00:11:11:11",
		  bandwidth => {
		      in => {
			  average => 1000,
			  peak => 5000,
			  floor => 2000,
			  burst => 1024,
		      },
		      out => {
			  average => 128,
			  peak => 256,
			  burst => 256,
		      },
		  });
    my $domxml = $dombuilder->as_xml();

    diag "Creating a new transient domain";
    diag $domxml;
    my $dom;
    ok_error(sub { $dom = $conn->create_domain($domxml) }, "Unsupported op requesting bandwidth",
	     Sys::Virt::Error::ERR_OPERATION_UNSUPPORTED);

    diag "Destroying the transient network";
    $net->destroy;

    $netbuilder->bandwidth(
	in => {
	    average => 1000,
	    peak => 5000,
	    burst => 1024,
	},
	out => {
	    average => 128,
	    peak => 256,
	    burst => 256,
	});

    $netxml = $netbuilder->as_xml();

    diag "Creating a new transient network";
    diag $netxml;
    ok_network(sub { $net = $conn->create_network($netxml) }, "created transient network object");

    ok_domain(sub { $dom = $conn->create_domain($domxml) }, "created transient domain object");

    lives_ok(sub {
	$dom->set_interface_parameters(
	    "52:54:00:11:11:11",
	    {
		Sys::Virt::Domain::BANDWIDTH_IN_AVERAGE => 1000,
		Sys::Virt::Domain::BANDWIDTH_IN_PEAK => 5000,
		Sys::Virt::Domain::BANDWIDTH_IN_FLOOR => 4000,
		Sys::Virt::Domain::BANDWIDTH_IN_BURST => 1024,
		Sys::Virt::Domain::BANDWIDTH_OUT_AVERAGE => 128,
		Sys::Virt::Domain::BANDWIDTH_OUT_PEAK => 256,
		Sys::Virt::Domain::BANDWIDTH_OUT_BURST => 256,
	    })});

    ok_error(sub {
	$dom->set_interface_parameters(
	    "52:54:00:11:11:11",
	    {
		Sys::Virt::Domain::BANDWIDTH_IN_AVERAGE => 1000,
		Sys::Virt::Domain::BANDWIDTH_IN_PEAK => 5000,
		Sys::Virt::Domain::BANDWIDTH_IN_FLOOR => 40000,
		Sys::Virt::Domain::BANDWIDTH_IN_BURST => 1024,
		Sys::Virt::Domain::BANDWIDTH_OUT_AVERAGE => 128,
		Sys::Virt::Domain::BANDWIDTH_OUT_PEAK => 256,
		Sys::Virt::Domain::BANDWIDTH_OUT_BURST => 256,
	    }) }, "Canot overcommit bandwidth",
	Sys::Virt::Error::ERR_OPERATION_INVALID);

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
