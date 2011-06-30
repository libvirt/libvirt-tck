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

use Test::More tests => 24;

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

my $olddigest = &digest($oldfile, 0, 0);

my $quit = 0;
my $quitref = \$quit;

my $nextdata;
my $nextdatalen = 0;

&onetest(0, 0);
&onetest(0, 1024*1024);
&onetest(1024*1024, 0);
&onetest(1024*1024, 1024*1024);

sub onetest {
    my $offset = shift;
    my $length = shift;

    my $origdigestpre = $offset ? &digest($path, 0, $offset) : "";
    my $origdigestpost = &digest($path, $offset + 1024*1024, 0);

    my $st = $conn->new_stream(Sys::Virt::Stream::NONBLOCK);

    open FILE, "<$oldfile" or die "cannot read $oldfile: $!";

    $nextdatalen = 0;

    sub streamevent {
	my $st = shift;
	my $events = shift;

	if ($events & (Sys::Virt::Stream::EVENT_HANGUP |
		       Sys::Virt::Stream::EVENT_ERROR)) {
	    $quit = 1;
	    return;
	}

	if (!$nextdatalen) {
	    $nextdatalen = sysread FILE, $nextdata, 65536
	}
	if ($nextdatalen == 0) {
	    $quit = 1;
	    $st->remove_callback();
	    return;
	}

	my $rv = $st->send($nextdata, $nextdatalen);

	if ($rv > 0) {
	    $nextdata = substr $nextdata, $rv;
	    $nextdatalen -= $rv;
	}
    }

    lives_ok(sub { $vol->upload($st, $offset, $length) }, "started upload");

    $st->add_callback(Sys::Virt::Stream::EVENT_WRITABLE, \&streamevent);

    ${$quitref} = 0;
    alarm 15;
    while (!${$quitref}) {
	Sys::Virt::Event::run_default();
    }
    alarm 0;

    lives_ok(sub { $st->finish(); }, "finished stream");

    close FILE or die "cannot close $oldfile: $!";

    my $newdigest = &digest($path, $offset, 1024*1024);
    my $newdigestpre = $offset ? &digest($path, 0, $offset) : "";
    my $newdigestpost = &digest($path, $offset + 1024*1024, 0);

    is($origdigestpre, $newdigestpre, "File pre region digest matches");
    is($olddigest, $newdigest, "File digests match");
    is($origdigestpost, $newdigestpost, "File post region digest matches");
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
