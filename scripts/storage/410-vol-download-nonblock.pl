# -*- perl -*-
#
# Copyright (C) 2011 Red Hat, Inc.
# Copyright (C) 2011 Daniel P. Berrange
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

storage/400-vol-download.pl - storage volume download

=head1 DESCRIPTION

The test case validates that it is possible to download storage
volumes using blocking virStreamRecv API calls.

=cut

use strict;
use warnings;

use Test::More tests => 16;

use Digest;
use File::Spec::Functions qw(catfile);
use Sys::Virt::TCK;
use Test::Exception;
use File::stat;
use Fcntl qw(SEEK_SET);

Sys::Virt::Event::register_default();

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

my $volxml = $tck->generic_volume("tck", "raw", 1024*1024*2)->allocation(1024*1024*2)->as_xml;


my $vol;

ok_volume(sub { $vol = $pool->create_volume($volxml) }, "create raw volume");

my $path = xpath($vol, "string(/volume/target/path)");

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
    }
}
close FILE or die "cannot save $path: $!";

my $quit = 0;
my $quitref = \$quit;

&onetest(0, 0);
&onetest(1024*1024, 0);
&onetest(1024*1024, 1024*1024);
&onetest(0, 1024*1024);

sub onetest {
    my $offset = shift;
    my $length = shift;

    my $origdigest = &digest($path, $offset, $length);


    my $st = $conn->new_stream(Sys::Virt::Stream::NONBLOCK);

    my $newfile = catfile($tck->bucket_dir("vol-stream"), "local.img");
    unlink $newfile;

    open FILE, ">$newfile" or die "cannot create $newfile: $!";

    sub streamevent {
	my $st = shift;
 	my $events = shift;

	if ($events & (Sys::Virt::Stream::EVENT_HANGUP |
		       Sys::Virt::Stream::EVENT_ERROR)) {
	    ${$quitref} = 1;
	    return;
	}

	my $data;
	my $rv = $st->recv($data, 65536);
	if ($rv == 0) {
	    ${$quitref} = 1;
	    $st->remove_callback();
	    return;
	}

	while ($rv > 0) {
	    my $ret = syswrite FILE, $data, $rv;
	    $data = substr $data, $ret;
	    $rv -= $ret;
	}
    }

    lives_ok(sub { $vol->download($st, $offset, $length) }, "started download");

    $st->add_callback(Sys::Virt::Stream::EVENT_READABLE, \&streamevent);

    ${$quitref} = 0;
    alarm 15;
    while (!${$quitref}) {
	Sys::Virt::Event::run_default();
    }
    alarm 0;

    lives_ok(sub { $st->finish(); }, "finished stream");

    close FILE or die "cannot save $newfile: $!";

    my $newdigest = &digest($newfile, 0, 0);

    is($origdigest, $newdigest, "File digests match");

    unlink $newfile;
}


sub digest {
    my $file = shift;
    my $offset = shift;
    my $length = shift;

    open FILE, "<$file" or die "cannot open $file: $!";

    my $digest = Digest->new("MD5");

    my $done = 0;
    seek FILE, $offset, SEEK_SET;
    while (1) {
	my $want = 1024;
	if ($length && (($length - $done) < $want)) {
	    $want = ($length - $done);
	}
	my $str;
	my $got = sysread FILE, $str, $want;
	last if $got == 0;
	$done += $got;
	$digest->add($str);
    }

    close FILE;

    return $digest->hexdigest;
}
