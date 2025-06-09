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

storage/250-vol-qcow2-backing-store-auto.t - verify setup of qcow2 backing stores

=head1 DESCRIPTION

The test case validates that qcow2 backing stores are correctly
setup to default to a raw format if not otherwise specified in
the XML to avoid potential security holes when loading into a VM.

=cut

use strict;
use warnings;

use Test::More tests => 14;

use Sys::Virt::TCK;
use Test::Exception;
use File::stat;
use Fcntl;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

SKIP: {
    eval { require 5.9.2 };
    skip "unpacking qcow header requires perl >= 5.9.2 for unpack byte order modifiers", 14 if $@;

    my $xml = $tck->generic_pool("dir")->as_xml;


    diag "Defining transient storage pool";
    my $pool;
    ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");

    lives_ok(sub { $pool->build(0) }, "built storage pool");

    lives_ok(sub { $pool->create }, "started storage pool");


    my $volbackxml = $tck->generic_volume("tck-back", "raw", 1024*1024*50)
	->allocation(0)->as_xml;

    my $st;

    my ($volback, $pathback);
    diag "back $volbackxml";
    ok_volume(sub { $volback = $pool->create_volume($volbackxml) }, "create raw backing file volume");

    $pathback = xpath($volback, "string(/volume/target/path)");
    $st = stat($pathback);

    ok($st, "path $pathback exists");

    is($st->size, 1024*1024*50, "size is 50M");


    my $volmainxml = $tck->generic_volume("tck-main", "qcow2", 1024*1024*50)
	->backing_file($pathback)
	->allocation(0)->as_xml;


    my ($volmain, $pathmain);
    diag "main $volmainxml";
    ok_volume(sub { $volmain = $pool->create_volume($volmainxml) }, "create qcow2 backing file volume");

    $pathmain = xpath($volmain, "string(/volume/target/path)");
    $st = stat($pathmain);

    ok($st, "path $pathmain exists");

    ok($st->size < 1024*1024, "size is < 1M");

    my $QCOW2_HDR_BACKING_FILE_OFFSET = 4+4;
    my $QCOW2_HDR_BACKING_FILE_SIZE = 4+4+8;
    my $QCOW2_HDR_TOTAL_SIZE = 4+4+8+4+4+8+4+4+8+8+4+4+8;
    my $QCOW2_HDR_EXTENSION_END = 0;
    my $QCOW2_HDR_EXTENSION_BACKING_FORMAT = 0xE2792ACA;

    open FILE, "<$pathmain" or die "cannot read $pathmain: $!";


    seek FILE, $QCOW2_HDR_BACKING_FILE_OFFSET, Fcntl::SEEK_SET
	or die "cannot seek to backing file header offset at $QCOW2_HDR_BACKING_FILE_OFFSET: $!";

    my $bytes;
    read FILE, $bytes, 8;
    my $backing_file_offset = unpack "Q>", $bytes;
    read FILE, $bytes, 4;
    my $backing_file_length = unpack "L>", $bytes;

    diag "Backing file at $backing_file_offset length $backing_file_length";
    seek FILE, $backing_file_offset, Fcntl::SEEK_SET
	or die "cannot seek to backing file name at $backing_file_offset: $!";

    my $name;
    read FILE, $name, $backing_file_length;

    is($name, $pathback, "backing file path in '$pathmain' is '$pathback'");

    seek FILE, $QCOW2_HDR_TOTAL_SIZE, Fcntl::SEEK_SET
	or die "cannot seek to $QCOW2_HDR_TOTAL_SIZE: $!";

    my $offset = $QCOW2_HDR_TOTAL_SIZE;
    my $format = "";

    ok($offset < $backing_file_offset, "qcow2 extensions are present in '$pathmain'");

    while ($offset < ($backing_file_offset-8)) {
	read FILE, $bytes, 4;
	my $magic = unpack "L>", $bytes;
	read FILE, $bytes, 4;
	my $len = unpack "L>", $bytes;

	$offset += 8;

	read FILE, $bytes, $len;

	$offset += $len;

	if ($magic == $QCOW2_HDR_EXTENSION_BACKING_FORMAT) {
	    $format = $bytes;
	}
    }

    is($format, "raw", "backing format in $pathmain is raw");

    close FILE;

    lives_ok(sub { $volback->delete(0) }, "deleted volume");
    lives_ok(sub { $volmain->delete(0) }, "deleted volume");

}
