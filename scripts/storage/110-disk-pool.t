# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat, Inc
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

storage/110-disk-pool.t - test disk storage pools

=head1 DESCRIPTION

The test case validates that it is possible to use all core
functions of the disk pool type.

=cut

use strict;
use warnings;

use Test::More tests => 20;

use Sys::Virt::TCK;
use Test::Exception;
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}


SKIP: {
    my $dev = $tck->get_host_block_device();

    skip "no host block device available", 20 unless defined $dev;

    # Blow away partition table (if any)
    open DEV, ">$dev" or die "cannot write to $dev: $!";
    my $data = " "x 512;

    print DEV $data;
    close DEV or die "cannot save $dev: $!";

    my $poolxml = $tck->generic_pool("disk", "tck")
	->source_device($dev)
	->format("dos")
	->target("/dev/")
	->as_xml;

    diag "Defining persistent storage pool $poolxml";
    my $pool;
    ok_pool(sub { $pool = $conn->define_storage_pool($poolxml) }, "define persistent storage pool");

    # Since we blew away the partition table we should not be able to
    # start the pool yet
    ok_error(sub { $pool->create }, "unable to start un-built storage pool");

    lives_ok(sub { $pool->build(0) }, "built storage pool");

    # We should get an error if trying to build a pool which already
    # has a partition table written.
    ok_error(sub { $pool->build(0) }, "prevent rebuilding existing storage pool");

    lives_ok(sub { $pool->create }, "started storage pool");

    my @vols = $pool->list_volumes();

    is($#vols, -1, "no storage volumes in new pool");

    my $poolinfo = $pool->get_info();

    ok($poolinfo->{available} > 1000, "there is some space available in the pool");

    my $volbase = $dev;
    $volbase =~ s,/dev/,,;

    my $vol1xml = $tck->generic_volume($volbase . "1", undef, 1024*1024*256)->as_xml;
    my $vol2xml = $tck->generic_volume($volbase . "2", undef, 1024*1024*64)->as_xml;

    diag "Vol $vol1xml $vol2xml";
    my $vol1;
    my $vol2;
    ok_volume(sub { $vol1 = $pool->create_volume($vol1xml) }, "create disk partition");
    ok_volume(sub { $vol2 = $pool->create_volume($vol2xml) }, "create disk partition");

    for my $vol (($vol1, $vol2)) {
	my $path = xpath($vol, "string(/volume/target/path)");
	my $st = stat($path);

	ok($st, "path $path exists");
    }

    @vols = $pool->list_volumes();
    is($#vols, 1, "two storage volumes in pool");

    lives_ok(sub { $vol1->delete(0) }, "deleted volume");

    @vols = $pool->list_volumes();
    is($#vols, 0, "one storage volume in pool");

    lives_ok(sub { $vol2->delete(0) }, "deleted volume");

    @vols = $pool->list_volumes();
    is($#vols, -1, "zero storage volume in pool");

    lives_ok(sub { $pool->destroy() }, "destroyed pool");
    lives_ok(sub { $pool->delete(0) }, "deleted pool");

    # Since we blew away the partition table we should not be able to
    # start the pool anymore
    ok_error(sub { $pool->create }, "unable to start un-built storage pool");

    lives_ok(sub { $pool->undefine() }, "undefined pool");
}
