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

storage/402-vol-download-sparse.t

=head1 DESCRIPTION

The test case validates that it is possible to download storage
volumes with sparse stream and hole processing. The following APIs and
flags can work correctly.

$st->recv_hole()
Sys::Virt::StorageVol::VOL_DOWNLOAD_SPARSE_STREAM
Sys::Virt::Stream::RECV_STOP_AT_HOLE

=cut

use strict;
use warnings;

use Test::More tests => 6;

use Digest;
use File::Spec::Functions qw(catfile);
use Sys::Virt::TCK;
use Test::Exception;
use File::stat;
use Fcntl qw(SEEK_SET);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}


my $pool;
my $vol;
my $FILE;
my $xml;
my $volxml;
my $st = $conn->new_stream();
my $filename = $tck->scratch_dir() . '/sparse-download';

# Prepare a pool and raw volume
diag "Defining transient storage pool";

$xml = $tck->generic_pool("dir")->as_xml;
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");
lives_ok(sub { $pool->build(0) }, "built storage pool");
lives_ok(sub { $pool->create }, "started storage pool");
$volxml = $tck->generic_volume("tck", "raw", 1024*1024*2)->allocation(0)->as_xml;
ok_volume(sub { $vol = $pool->create_volume($volxml) }, "create raw volume");

# Begin to download the volume
diag "Downloading the volume to $filename";

download($vol, $st, $filename);
$st = stat($filename);
ok($st, "download the volume successfully to '$filename'");

# Clean up the local file
diag "Cleaning up the local file";
system("rm -f $filename");

sub download {
    my $vol = shift;
    my $st = shift;
    my $filename = shift;
    my $offset = 0;
    my $length = 0;

    open FILE, ">$filename" or die "unable to create $filename: $!";
    eval {
        $vol->download($st, $offset, $length, Sys::Virt::StorageVol::VOL_DOWNLOAD_SPARSE_STREAM);
        while (1) {
          my $nbytes = 65535;
          my $data;
          my $rv = $st->recv($data, $nbytes, Sys::Virt::Stream::RECV_STOP_AT_HOLE);
          last if $rv == 0;
          while ($rv > 0) {
            diag "receive $rv (bytes)";
            my $done = syswrite FILE, $data, $rv;
            if ($done) {
                $data = substr $data, $done;
                $rv -= $done;
            }
          }
	  if ($rv == -3) {# reach a hole
	      my $hole_size = $st->recv_hole(0);
	      ok($hole_size > 0, "Reach a hole with size $hole_size(bytes)");
              last;
	  }elsif ($rv == -1) {
	      diag "Error";	    
	  }elsif ($rv == -2) {
	      diag "I/O block";
	  }
        }
        $st->finish();
    };
    if ($@) {
        unlink $filename if $@;
        close FILE;
        die $@;
    }

    close FILE or die "cannot save $filename: $!"
}
