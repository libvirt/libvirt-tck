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

domain/200-disk-hotplug.t - verify driver ordering during hot plug of disks

=head1 DESCRIPTION

The test case validates that drive ordering does not get messed up
during hotplug of disks.

=cut

use strict;
use warnings;

use Test::More tests => 7;

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

my $supported = 1;
foreach my $dev (qw/vdb sdb/) {
    my $path = $tck->create_sparse_disk("200-disk-hotplug", "extra-$dev.img", 100);

    my $diskxml = <<EOF;
<disk type='file' device='disk'>
  <source file='$path'/>
  <target dev='$dev'/>
</disk>
EOF

    diag "Attaching the new disk $path";
    eval {
	$dom->attach_device($diskxml);
    };
    if ($@) {
        diag "Unable to attach device $diskxml: $@";
        $supported = 0;
    };
    eval {
	$dom->detach_device($diskxml);
    };
    if ($@) {
        diag "Unable to detach device $diskxml: $@";
        $supported = 0;
    };
}

SKIP: {
    skip "hotplugging VirtIO and/or SCSI disks not supported", 6 unless $supported;

    # Hotplug in this order
    my @disks = ("vdb", "sda", "sdc", "vdc", "sdb");
    # Expect them back in this order
    # XXXX this is presuming 'sda' isn't used for root disk
    # currently true, but beware...
    my @expect = ("vdb", "vdc", "sda", "sdb", "sdc");

    foreach my $dev (@disks) {
	my $path = $tck->create_sparse_disk("200-disk-hotplug", "extra-$dev.img", 100);

	my $diskxml = <<EOF;
<disk type='file' device='disk'>
  <source file='$path'/>
  <target dev='$dev'/>
</disk>
EOF

        diag "Attaching the new disk $dev from $path";
	lives_ok(sub { $dom->attach_device($diskxml); }, "disk $dev has been attached");
    }

    my $devset = xpath($dom, "/domain/devices/disk/target/\@dev");

    my @actual = map { $_->getNodeValue } $devset->get_nodelist();

    # Discard first disk, since that's already there from basic guest
    shift @actual;

    is_deeply(\@expect, \@actual, "disk ordering is " . join(',', @expect));
}

