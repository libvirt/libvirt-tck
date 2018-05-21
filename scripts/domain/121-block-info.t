# -*- perl -*-
#
# Copyright (C) 2013 Red Hat, Inc.
# Copyright (C) 2013 Zhe Peng <zpeng@redhat.com>
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

domain/121-block-info.t

=head1 DESCRIPTION

The test case validates that all following APIs work well include
dom->block_resize
dom->get_block_info
dom->block_peek

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

# test is_alive
my $live = $conn->is_alive();
ok($live > 0, "Connection is alive");

my $xml = $tck->generic_pool("dir")->as_xml;

diag "Defining transient storage pool";
my $pool;
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");
lives_ok(sub { $pool->build(0) }, "built storage pool");
lives_ok(sub { $pool->create }, "started storage pool");

my $volallocxml = $tck->generic_volume("tck", "raw", 1024*1024*50)->allocation(1024*1024*50)->as_xml;
my ($vol, $path, $st);
ok_volume { $vol = $pool->create_volume($volallocxml) } "create fully allocated raw volume";

my $volallocxml2 = $tck->generic_volume("tck2", "raw", 1024*1024*50)->allocation(1024*1024)->as_xml;
my ($vol2, $path2, $st2);
ok_volume { $vol2 = $pool->create_volume($volallocxml2) } "create not fully allocated raw volume";

my $volallocxml3 = $tck->generic_volume("tck3", "qcow2", 1024*1024*50)->allocation(1024*1024)->as_xml;
my ($vol3, $path3, $st3);
ok_volume { $vol3 = $pool->create_volume($volallocxml3) } "create qcow2 volume";

$path = xpath($vol, "string(/volume/target/path)");
$st = stat($path);
ok($st, "path $path exists");
is($st->size, 1024*1024*50, "size is 50M");

$path2 = xpath($vol2, "string(/volume/target/path)");
$st2 = stat($path2);
ok($st2, "path $path2 exists");

$path3 = xpath($vol3, "string(/volume/target/path)");
$st3 = stat($path3);
ok($st3, "path $path3 exists");

diag "Generic guest with previous created vol";
my $disktype = "raw";
my $dst = "vda";
my $dst2 = "vdb";
my $dst3 = "vdc";
my $guest = $tck->generic_domain(name => "tck");
$guest->rmdisk();

$guest->disk(format => { name => "qemu", type => $disktype }, type => "file", src => $path, dst => $dst);
$guest->disk(format => { name => "qemu", type => $disktype }, type => "file", src=> $path2, dst => $dst2);
$guest->disk(format => { name => "qemu", type => "qcow2" }, type => "file", src=> $path3, dst => $dst3);

$xml = $guest->as_xml;
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "Create domain");
$xml = $dom->get_xml_description();

is($dom->get_block_info($dst2,0)->{capacity}, 1024*1024*50, "Get disk capacity info");
is($dom->get_block_info($dst2,0)->{allocation}, 1024*1024, "Get disk allocation info");
is($dom->get_block_info($dst2,0)->{physical}, 1024*1024*50, "Get disk physical info");


is($dom->get_block_info($dst,0)->{capacity}, 1024*1024*50, "Get disk capacity info");
ok($dom->get_block_info($dst,0)->{allocation} >= 1024*1024*50, "Get disk allocation info");
ok($dom->get_block_info($dst,0)->{physical} >= 1024*1024*50, "Get disk physical info");

diag "Test block_resize";
lives_ok(sub {$dom->block_resize($dst, 512*50)}, "resize to 512*50 KB");
$st = stat($path);
is($st->size, 512*1024*50, "size is 25M");

is($dom->get_block_info($dst,0)->{capacity}, 1024*512*50, "Get disk capacity info");
ok($dom->get_block_info($dst,0)->{allocation} >= 1024*512*50, "Get disk allocation info");
ok($dom->get_block_info($dst,0)->{physical} >= 1024*512*50, "Get disk physical info");

lives_ok(sub {$dom->block_resize($dst, 1024*50)}, "resize to 1024*50 KB");
$st = stat($path);
is($st->size, 1024*1024*50, "size is 50M");

diag "Test block_peek";
my $date = "test";
system("echo $date > $path");
is($dom->block_peek($path,0,4,0), $date, "Get date from raw image");

dies_ok(sub { $dom->block_peek($path3,0,3,0) }, "Get date from qcow2 image");

lives_ok(sub { $vol->delete(0) }, "deleted volume");

diag "Destroy domain";
$dom->destroy;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);
