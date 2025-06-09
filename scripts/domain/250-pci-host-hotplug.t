#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat, Inc.
# Copyright (C) 2009-2010 Daniel P. Berrange
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

domain/250-pci-host-hotplug.t - verify hot plug & unplug of a host PCI device

=head1 DESCRIPTION

The test case validates that it is possible to hotplug a pci
host device to a running domain, and then unplug it again.
This requires that the TCK configuration file have at least
one host PCI device listed.

This first searches for the node device, then detachs it from
the host OS. Next it performs a reset. Then does the hotplug
and unplug, before finally reattaching to the host.

=cut

use strict;
use warnings;

use Test::More tests => 10;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");
diag "Waiting 10 seconds for guest to initialize";
sleep(10);


my ($domain, $bus, $slot, $function) = $tck->get_host_pci_device();

SKIP: {
    # Must have one item be non-zero
    unless ($domain || $bus || $slot || $function) {
	skip "No host pci device available in configuration file", 9;
    }

    my $nodedev;
    my @devs = $conn->list_node_devices("pci");
    foreach my $dev (@devs) {
	my $thisxml = $dev->get_xml_description();

	my $xp = XML::XPath->new(xml => $thisxml);

	#warn $thisxml;
	my $ndomain = $xp->find("string(/device/capability[\@type='pci']/domain[text()])")->value();
	my $nbus = $xp->find("string(/device/capability[\@type='pci']/bus[text()])")->value();
	my $nslot = $xp->find("string(/device/capability[\@type='pci']/slot[text()])")->value();
	my $nfunction = $xp->find("string(/device/capability[\@type='pci']/function[text()])")->value();

	if ($ndomain == $domain &&
	    $nbus == $bus &&
	    $nslot == $slot &&
	    $nfunction == $function) {
	    $nodedev = $dev;
	    last;
	}
    }

    ok(defined $nodedev, "found PCI device $domain:$bus:$slot.$function on host");

    lives_ok(sub { $nodedev->dettach(undef, 0) }, "detached device from host OS");
    lives_ok(sub { $nodedev->reset() }, "reset the host PCI device");

    my $devxml =
	"<hostdev mode='subsystem' type='pci' managed='no'>\n" .
	"  <source>\n" .
	"    <address domain='$domain' bus='$bus' slot='$slot' function='$function'/>\n" .
	"  </source>\n" .
	"</hostdev>\n";

    my $initialxml = $dom->get_xml_description;

    diag "Attaching the new dev $devxml";
    lives_ok(sub { $dom->attach_device($devxml); }, "PCI dev has been attached");

    my $newxml = $dom->get_xml_description;
    ok($newxml =~ m|<hostdev|, "new XML has extra PCI dev present");

    diag "Detaching the new dev $devxml";
    lives_ok(sub { $dom->detach_device($devxml); }, "PCI dev has been detached");

    lives_ok(sub { $nodedev->reset() }, "reset the host PCI device");
    lives_ok(sub { $nodedev->reattach() }, "reattached device to host OS");

    my $finalxml = $dom->get_xml_description;

    is($initialxml, $finalxml, "final XML has removed the PCI device")
}

