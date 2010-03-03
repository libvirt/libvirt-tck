# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat
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

domain/240-usb-host-hotplug.t - verify hot plug & unplug of a host USB device

=head1 DESCRIPTION

The test case validates that it is possible to hotplug a usb
host device to a running domain, and then unplug it again.
This requires that the TCK configuration file have at least
one host USB device listed.

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
}


my $xml = $tck->generic_domain("tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");


my ($bus, $device, $vendor, $product) = $tck->get_host_usb_device();

SKIP: {
    # Must have one of the pairs at least
    unless (($bus && $device) || ($vendor && $product)) {
	skip "No host usb device available in configuration file", 4;
    }

    my $devxml = "<hostdev mode='subsystem' type='usb'>\n" .
	"<source>\n";
    if ($bus && $device) {
        $devxml .= "<address bus='$bus' device='$device'/>\n"
    }
    if ($vendor && $product) {
        $devxml .= "<vendor id='$vendor'/>\n";
        $devxml .= "<product id='$product'/>\n";
    }
    $devxml .= "</source>\n" .
	"</hostdev>\n";

    my $initialxml = $dom->get_xml_description;

    diag "Attaching the new dev $devxml";
    lives_ok(sub { $dom->attach_device($devxml); }, "USB dev has been attached");

    my $newxml = $dom->get_xml_description;
    ok($newxml =~ m|<hostdev|, "new XML has extra USB dev present");

    diag "Detaching the new dev $devxml";
    lives_ok(sub { $dom->detach_device($devxml); }, "USB dev has been detached");


    my $finalxml = $dom->get_xml_description;

    is($initialxml, $finalxml, "final XML has removed the disk")
}

