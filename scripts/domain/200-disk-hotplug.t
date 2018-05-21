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

domain/200-disk-hotplug.t - verify hot plug & unplug of a disk

=head1 DESCRIPTION

The test case validates that it is possible to hotplug a disk
to a running domain, and then unplug it again.

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


my $xml = $tck->generic_domain(name => "tck", fullos => 1)->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

diag "Waiting 30 seconds for guest to finish booting";
sleep(30);

my $path = $tck->create_sparse_disk("200-disk-hotplug", "extra.img", 100);

my $dev = "vdb";
my $bus = "virtio";

my $diskxml = <<EOF;
<disk type='file' device='disk'>
  <source file='$path'/>
  <target dev='$dev' bus='$bus'/>
</disk>
EOF


my $initialxml = $dom->get_xml_description;

diag "Attaching the new disk $path";
lives_ok(sub { $dom->attach_device($diskxml); }, "disk has been attached");

my $newxml = $dom->get_xml_description;

ok($newxml =~ m|$path|, "new XML has extra disk present");

diag "Detaching the new disk $path";
lives_ok(sub { $dom->detach_device($diskxml); }, "disk has been detached");


my $finalxml = $dom->get_xml_description;

is($initialxml, $finalxml, "final XML has removed the disk")
