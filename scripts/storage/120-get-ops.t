#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2012 Red Hat, Inc.
# Copyright (C) 2012 Kyla Zhang <weizhan@redhat.com>
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

storage/120-get-opts.t - Get command testing for pool and vol including
pool->get_uuid
pool->get_name
pool->refresh
pool->get_volume_by_name
vol->get_name
vol->get_key
vol->get_path
vol->get_info

=head1 DESCRIPTION

The test case validates the get commands for pool and vol works well

=cut

use strict;
use warnings;

use Test::More tests => 15;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name = "tck1";
my $xml = $tck->generic_pool("dir", $name)->as_xml;
my $dir = $tck->create_empty_dir("storage-fs", $name);
my $vol1_name = "tck_vol1";
my $vol2_name = "tck_vol2";


diag "Creating a new transient pool";
my $pool;
ok_pool(sub { $pool = $conn->create_storage_pool($xml) }, "created transient pool object");


diag "Get pool uuid";
my $pool_uuid=$pool->get_uuid();
is ($conn->get_storage_pool_by_uuid($pool_uuid)->get_name(), $name, "Get pool uuid succeed");


diag "Get pool name";
is($pool->get_name(), $name, "Get pool name $name");


diag "Get volume by name";
my $vol1_xml = $tck->generic_volume($vol1_name, "raw", 1024*1024*50)->allocation(0)->as_xml;
my $vol1 = $pool->create_volume($vol1_xml);
is($pool->get_volume_by_name($vol1_name)->get_name(), $vol1_name, "Get volume $vol1_name");


diag "Get volume without refresh after creating image with dd";
system("dd if=/dev/zero of=$dir/$vol2_name count=7 bs=1048576");
ok_error(sub { $pool->get_volume_by_name($vol2_name) },
	"Can't get volume $vol2_name without refresh", Sys::Virt::Error::ERR_NO_STORAGE_VOL);


diag "Refresh pool and get volume again";
lives_ok(sub { $pool->refresh() }, "Pool refresh succeed");
my $vol2=$pool->get_volume_by_name($vol2_name);
is($vol2->get_name(), $vol2_name, "Get volume $vol2_name");


diag "get vol key";
my $vol2_key=xpath($vol2, "string(/volume/key)");
is($vol2->get_key(), $vol2_key, "Get vol key $vol2_key");


diag "Get vol path";
my $vol2_path=xpath($vol2, "string(/volume/target/path)");
is($vol2->get_path(), $vol2_path, "Get vol path $vol2_path");


diag "Get vol info";
is($vol2->get_info()->{type}, Sys::Virt::StorageVol::TYPE_FILE, "Get vol type file");
my $vol2_capacity=xpath($vol2, "string(/volume/capacity)");
is($vol2->get_info()->{capacity}, $vol2_capacity, "Get vol capacity $vol2_capacity");
my $vol2_allocation=xpath($vol2, "string(/volume/allocation)");
is($vol2->get_info()->{allocation}, $vol2_allocation, "Get vol allocation $vol2_allocation");


diag "Destroy volume";
lives_ok(sub { $vol1->delete(0) }, "deleted volume 1");
lives_ok(sub { $vol2->delete(0) }, "deleted volume 2");

diag "Destroying the transient pool";
$pool->destroy;

diag "Checking that transient pool has gone away";
ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

# end
