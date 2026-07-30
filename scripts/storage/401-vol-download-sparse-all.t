#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2011 Red Hat, Inc.
# Copyright (C) 2017 Dan Zheng (dzheng@redhat.com)
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

storage/401-vol-download-sparse-all.t

=head1 DESCRIPTION

The test case validates that it is possible to download storage
volumes with sparse stream.

Sys::Virt::StorageVol::VOL_DOWNLOAD_SPARSE_STREAM
$st->sparse_recv_all()

=cut

use strict;
use warnings;

use Test::More tests => 6;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

my $pool;
my $xml;
my $vol;
my $FILE;
my $volxml;
my $download_disk_size;
my $download_virtual_size;

my $st = $conn->new_stream();
my $filename = $tck->scratch_dir() . '/sparse-download';

diag "Defining transient storage pool";

$xml = $tck->generic_pool("dir")->as_xml;
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");
lives_ok(sub { $pool->build(0) }, "built storage pool");
lives_ok(sub { $pool->create }, "started storage pool");
$volxml = $tck->generic_volume("tck", "raw", 1024*1024*2)->allocation(0)->as_xml;
ok_volume(sub { $vol = $pool->create_volume($volxml) }, "create raw volume");

# When using Sys::Virt::StorageVol::VOL_DOWNLOAD_SPARSE_STREAM,
# if the volume file is empty, the downloaded file should have 0 disk size(removing holes),
# but virtual size is same as the volume's.

diag "Downloading the volume to $filename";

download($vol, $st, $filename);
$download_disk_size = `qemu-img info $filename |grep 'disk size:'|cut -d' ' -f3`;
chomp($download_disk_size);
is(int($download_disk_size), 0, "download the volume successfully to '$filename' with disk size $download_disk_size bytes");
$download_virtual_size = `qemu-img info $filename |grep 'virtual size:'|cut -d'(' -f2|cut -d' ' -f1`;
chomp($download_virtual_size);
is($download_virtual_size, 1024*1024*2, "download the volume successfully to '$filename' with virtual size $download_virtual_size bytes");

diag "Cleaning up the local file";

system("rm -f $filename");

sub download_handler {
        my $st = shift;
        my $data = shift;
        my $nbytes = shift;
        return syswrite FILE, $data, $nbytes;
}

sub download_hole_handler {
    my $st = shift;
    my $offset = shift;
    my $pos = sysseek FILE, $offset, Fcntl::SEEK_CUR or die "Unable to seek in $FILE: $!";
    truncate FILE, $pos;
}

sub download {
    my $vol = shift;
    my $st = shift;
    my $filename = shift;
    my $offset = 0;
    my $length = 0;

    open FILE, ">$filename" or die "unable to create $filename: $!";
    eval {
	$vol->download($st, $offset, $length, Sys::Virt::StorageVol::VOL_DOWNLOAD_SPARSE_STREAM);
        $st->sparse_recv_all(\&download_handler, \&download_hole_handler);
        $st->finish();
    };
    if ($@) {
        unlink $filename if $@;
        close FILE;
        die $@;
    }

    close FILE or die "cannot save $filename: $!"
}
