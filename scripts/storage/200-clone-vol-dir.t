#!/usr/bin/env perl
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

storage/200-clone-vol-fs.t - Clone a volume with a directory pool

=head1 DESCRIPTION

The test case validates that it is possible to clone volumes
within a directory pool. It starts by creating a raw volume
with a magic pattern. It then clones this to another format,
and then clones back to raw. The source and destinations are
checksummed and validated

=cut

use strict;
use warnings;

use Test::More tests => 52;

use Sys::Virt::TCK;
use Test::Exception;
use File::stat;
use Digest;

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


diag "Preparing initial source volume with some special data";
my $volsrcxml = $tck->generic_volume("tcksrc", "raw", 1024*1024*50)->as_xml;

my ($vol, $path, $st);

ok_volume(sub { $vol = $pool->create_volume($volsrcxml) }, "create source raw volume");

$path = xpath($vol, "string(/volume/target/path)");

open FILE, ">$path"
    or die "cannot create $path: $!";

for (my $i = 0 ; $i < 50 ; $i++) {
    for (my $j = 0 ; $j < 1024 ; $j++) {
	# 64 bytes
	my $str = join('', ('a'..'z', 'A'..'Z', '0'..'9', '.',"\n"));
        # 1 kb
	my $data = join('', $str, $str, $str, $str,
			$str, $str, $str, $str,
			$str, $str, $str, $str,
			$str, $str, $str, $str);
	print FILE $data;

	# Hack for VPC, add an extra 4k of data to round
	# out 50 MB size upto a size that is mappable to
	# VPC's CHS geometry without needing rounding
	if ($i == 0 && $j == 0) {
	    print FILE $data;
	    print FILE $data;
	    print FILE $data;
	    print FILE $data;
	}
    }
}
close FILE or die "cannot save $path: $!";
$st = stat($path);

ok($st, "path $path exists");

is($st->size, ((1024*1024*50)+4096), "size is 50M");

my $srcdigest = &digest($path);

diag "Now testing cloning of various formats";

my @formats = qw(raw qcow qcow2 vmdk vpc);

foreach my $format (@formats) {
    SKIP: {
        if (($format eq "qcow") and (`qemu-img -help` !~ "^Supported formats: .* qcow ")) {
            skip "qcow1 format not supported", 9;
        }

        diag "Cloning source volume to $format format";
        my $volclonexml = $tck->generic_volume("tck$format", $format, ((1024*1024*50)+4096))->as_xml;

        my $clone;
        ok_volume(sub { $clone = $pool->clone_volume($volclonexml, $vol) }, "clone to $format volume");

        $path = xpath($clone, "string(/volume/target/path)");
        $st = stat($path);
        ok($st, "path $path exists");
        ok($st->size >= ((1024*1024*50)+4096), "size is at least 50M");


        diag "Cloning cloned volume back to raw format";
        my $voldstxml = $tck->generic_volume("tckdst", "raw", ((1024*1024*50)+4096))->as_xml;
        my $result;
        ok_volume(sub { $result = $pool->clone_volume($voldstxml, $clone) }, "clone back to raw volume");


        $path = xpath($result, "string(/volume/target/path)");

        $st = stat($path);
        ok($st, "path $path exists");

        is($st->size, ((1024*1024*50)+4096), "size is 50M");

        diag "Comparing data between source & result volume";

        my $dstdigest = &digest($path);

        is($srcdigest, $dstdigest, "digests match");

        lives_ok(sub { $clone->delete(0) }, "deleted clone volume");
        lives_ok(sub { $result->delete(0) }, "deleted result volume");
    }
}


lives_ok(sub { $vol->delete(0) }, "deleted source vol");



sub digest {
    my $file = shift;

    open FILE, "<$file" or die "cannot open $file: $!";

    my $digest = Digest->new("MD5");
    $digest->addfile(\*FILE);

    close FILE;

    return $digest->hexdigest;
}
