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

storage/100-create-vol-fs.t - Create volume with a filesystem pool

=head1 DESCRIPTION

The test case validates that it is possible to create volumes
with a filesystem pool.

=cut

use strict;
use warnings;

use Test::More tests => 29;

use Sys::Virt::TCK;
use Test::Exception;
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}


my $xml = $tck->generic_pool("dir")->as_xml;


diag "Defining transient storage pool";
my $pool;
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");

lives_ok(sub { $pool->build(0) }, "built storage pool");

lives_ok(sub { $pool->create }, "started storage pool");


my $volsparsexml = $tck->generic_volume("tck1", "raw", 1024*1024*50)->allocation(0)->as_xml;
my $volallocxml = $tck->generic_volume("tck2", "raw", 1024*1024*50)->allocation(1024*1024*50)->as_xml;
my $volqcow1xml = $tck->generic_volume("tck4", "qcow", 1024*1024*50)->as_xml;
my $volqcow2xml = $tck->generic_volume("tck5", "qcow2", 1024*1024*50)->as_xml;
my $volvmdkxml = $tck->generic_volume("tck6", "vmdk", 1024*1024*50)->as_xml;
my $volvpcxml = $tck->generic_volume("tck7", "vpc", 1024*1024*50)->as_xml;

my ($vol, $path, $st);

ok_volume(sub { $vol = $pool->create_volume($volsparsexml) }, "create sparse raw volume");

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);

ok($st, "path $path exists");

is($st->size, 1024*1024*50, "size is 50M");

# In theory 0 blocks are allocated, but most FS have a couple of blocks
# overhead for a sparse file
ok($st->blocks < 10, "not many blocks allocated");

lives_ok(sub { $vol->delete(0) }, "deleted volume");




ok_volume { $vol = $pool->create_volume($volallocxml) } "create fully allocated raw volume";

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);

ok($st, "path $path exists");

is($st->size, 1024*1024*50, "size is 50M");

# In theory exact number blocks are allocated, but most FS have a couple of blocks
# overhead for a file
ok($st->blocks >= (1024*1024*50/512), "alot of blocks allocated");

lives_ok(sub { $vol->delete(0) }, "deleted volume");




ok_volume(sub { $vol = $pool->create_volume($volqcow1xml) }, "create qcow volume");

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);

ok($st, "path $path exists");

# Don't know exactly how large a qcow1 empty file is, but it
# should be quite small :-)
ok($st->size < 1024*1024, "basic qcow1 header is allocated");

lives_ok(sub { $vol->delete(0) }, "deleted volume");




ok_volume(sub { $vol = $pool->create_volume($volqcow2xml) }, "create qcow volume");

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);

ok($st, "path $path exists");

# Don't know exactly how large a qcow2 empty file is, but it
# should be quite small :-)
ok($st->size < 1024*1024, "basic qcow2 header is allocated");

lives_ok(sub { $vol->delete(0) }, "deleted volume");




ok_volume(sub { $vol = $pool->create_volume($volvmdkxml) }, "create qcow volume");

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);

ok($st, "path $path exists");

# Don't know exactly how large a vmdk empty file is, but it
# should be quite small :-)
ok($st->size < 1024*1024, "basic vmdk header is allocated");

lives_ok(sub { $vol->delete(0) }, "deleted volume");




ok_volume(sub { $vol = $pool->create_volume($volvpcxml) }, "create qcow volume");

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);

ok($st, "path $path exists");

# Don't know exactly how large a vpc empty file is, but it
# should be quite small :-)
ok($st->size < 1024*1024, "basic vpc header is allocated");

lives_ok(sub { $vol->delete(0) }, "deleted volume");

