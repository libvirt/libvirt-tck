#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2011 Red Hat, Inc.
# Copyright (C) 2018 Dan Zheng (dzheng@redhat.com)
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

storage/421-vol-upload-sparse-all.t

=head1 DESCRIPTION

The test case validates that it is possible to upload storage to
volumes with sparse stream.

Sys::Virt::StorageVol::VOL_UPLOAD_SPARSE_STREAM
$st->sparse_send_all()

=cut

use strict;
use warnings;

use Test::More tests => 5;

use Sys::Virt::TCK;
use Test::Exception;
use File::Spec::Functions qw(catfile);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

my $pool;
my $FILE;
my ($vol_disk_size, $vol_virtual_size, $local_filename);
my $st = $conn->new_stream();

diag "Defining a storage pool";
my $xml = $tck->generic_pool("dir")->as_xml;
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define a storage pool");
lives_ok(sub { $pool->build(0) }, "built storage pool");
lives_ok(sub { $pool->create }, "started storage pool");

diag "Preparing a volume";
my $poolpath = xpath($pool, "string(/pool/target/path)");
my $target_filename = "$poolpath/upload-sparse";
system("qemu-img create -f raw $target_filename 1G");
($vol_disk_size, $vol_virtual_size) = check_vol_size($target_filename);
diag "Before uploading, the volume disk size: $vol_disk_size "; 
diag "Before uploading, the volume virtual size: $vol_virtual_size";
$pool->refresh;

diag "Preparing a local file and write 1M data in it";
$local_filename = prepare_local_file();

# When using Sys::Virt::StorageVol::VOL_UPLOAD_SPARSE_STREAM,
# if the local file is not empty, the target volume should have non-zero disk size (same with local file),
# but virtual size is same as before.

diag "Uploading '$local_filename' to the target volume";
my $vol = $pool->get_volume_by_name("upload-sparse");
upload($vol, $st, $local_filename);

($vol_disk_size, $vol_virtual_size) = check_vol_size($target_filename);
ok($vol_disk_size eq '1.0M' | $vol_disk_size eq '1', 'After uploading, the volume disk size is 1 MiB as expected');
is($vol_virtual_size, 1024*1024*1024, 'After uploading, the volume virtual size is 1 GiB as expected');

diag "Cleaning up the local file";
unlink $local_filename;

sub check_vol_size {
    my $filename = shift;

    diag `qemu-img info $filename`;
    my $vol_disk_size = `qemu-img info $filename |grep 'disk size:'|cut -d' ' -f3`;
    chomp($vol_disk_size);
    my $vol_virtual_size = `qemu-img info $filename |grep 'virtual size:'|cut -d'(' -f2|cut -d' ' -f1`;
    chomp($vol_virtual_size);
    return (int($vol_disk_size), int($vol_virtual_size));
}

sub prepare_local_file {
    my $oldfile = catfile($tck->bucket_dir("vol-stream"), "local.img");
    unlink $oldfile;

    open FILE, ">$oldfile"
        or die "cannot create $oldfile: $!";

    for (my $j = 0 ; $j < 1024 ; $j++) {
        # 64 bytes
        my $str = join('', ('a'..'z', 'A'..'Z', '0'..'9', '.',"\n"));
        # 1 kb
        my $data = join('', $str, $str, $str, $str,
                        $str, $str, $str, $str,
                        $str, $str, $str, $str,
                        $str, $str, $str, $str);
        print FILE $data;
    }
    close FILE or die "cannot save $oldfile: $!";
    return $oldfile;
}

sub upload_handler {
    my $st = $_[0];
    my $nbytes = $_[2];
    return sysread FILE, $_[1], $nbytes;
}

sub upload_hole_handler {
    my $st = shift;
    my $in_data;
    my $section_len;

    # HACK, Perl lacks SEEK_DATA and SEEK_HOLE.
    my $SEEK_DATA = 3;
    my $SEEK_HOLE = 4;

    my $cur = sysseek FILE, 0, Fcntl::SEEK_CUR;
    eval {
        my $data = sysseek FILE, $cur, $SEEK_DATA;
        # There are three options:
        # 1) $data == $cur;  $cur is in data
        # 2) $data > $cur; $cur is in a hole, next data at $data
        # 3) $data < 0; either $cur is in trailing hole, or $cur is beyond EOF.

        if (!defined($data)) {
            # case 3
            $in_data = 0;
            my $end = sysseek FILE, 0, Fcntl::SEEK_END or die "Unable to get EOF position: $!";
            $section_len = $end - $cur;
        } elsif ($data > $cur) {
            #case 2
            $in_data = 0;
            $section_len = $data - $cur;
        } else {
            #case 1
            my $hole = sysseek FILE, $data, $SEEK_HOLE;
            if (!defined($hole) or $hole eq $data) {
                die "Unexpected error happens";
            }
            $in_data = 1;
            $section_len = $hole - $data;
        }
    };

    die "An error happens" if ($@);

    # reposition file back
    sysseek FILE, $cur, Fcntl::SEEK_SET;

    return ($in_data, $section_len);
}

sub upload_skip_handler {
    my $st = shift;
    my $offset = shift;
    sysseek FILE, $offset, Fcntl::SEEK_CUR or die "Unable to seek in $FILE";
    return 0;
}

sub upload {
    my $vol = shift;
    my $st = shift;
    my $filename = shift;
    my $offset = 0;
    my $length = 0;

    open FILE, "<$filename" or die "unable to open $filename: $!";
    eval {
        $vol->upload($st, $offset, $length, Sys::Virt::StorageVol::VOL_UPLOAD_SPARSE_STREAM);
        $st->sparse_send_all(\&upload_handler, \&upload_hole_handler, \&upload_skip_handler);
        $st->finish();
    };
    if ($@) {
        close FILE;
        die $@;
    }

    close FILE or die "cannot close $filename: $!"
}

