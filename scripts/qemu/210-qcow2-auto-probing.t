#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat, Inc.
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

qemu/200-qcow2-auto-probing.t - check that disk probing is disabled

=head1 DESCRIPTION

In this test are three files

 - last.img is a raw file
 - back.img is a qcow2 file, with backing file pointing to last.img
 - main.img is a qcow2 file, with backing file pointing to back.img

The guest is configured to point at 'main.img' as
without any format, so it should be treated as raw.
When main.img is created, the embedded backing store
(back.img) is not labelled explicitly, so it should
be treated as raw, even though on disk it is qcow2
format.

Thus, libvirt's security drivers should *not* grant
access to the back.img or last.img file & the guest
should not see the back.img or last.img data or have
any error.

=cut

use strict;
use warnings;

use Test::More tests => 26;

use Sys::Virt::TCK;
use Test::Exception;
use File::Spec::Functions qw(catfile);
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

SKIP: {
    skip "Only relevant to QEMU driver", 26 unless $conn->get_type() eq "QEMU";
    skip "Only relevant when run as root", 26 unless $< == 0;
    skip "Only relevant for system driver", 26 unless
	$conn->get_uri() =~ m/system/;


    my $xml = $tck->generic_pool("dir")
	->mode("0755")->as_xml;


    diag "Defining transient storage pool $xml";
    my $pool;
    ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");

    lives_ok(sub { $pool->build(0) }, "built storage pool");

    lives_ok(sub { $pool->create }, "started storage pool");


    my $vollastxml = $tck->generic_volume("tck-last", "raw", 1024*1024*50)
	->allocation(0)->as_xml;

    my $st;

    my ($vollast, $pathlast);
    diag "last $vollastxml";
    ok_volume(sub { $vollast = $pool->create_volume($vollastxml) }, "create raw lasting file volume");

    $pathlast = xpath($vollast, "string(/volume/target/path)");
    $st = stat($pathlast);

    ok($st, "path $pathlast exists");

    is($st->size, 1024*1024*50, "size is 50M");


    my $volbackxml = $tck->generic_volume("tck-back", "qcow2", 1024*1024*50)
	->backing_file($pathlast)
	->allocation(0)->as_xml;


    my ($volback, $pathback);
    diag "back $volbackxml";
    ok_volume(sub { $volback = $pool->create_volume($volbackxml) }, "create raw backing file volume");

    $pathback = xpath($volback, "string(/volume/target/path)");
    $st = stat($pathback);

    ok($st, "path $pathback exists");

    ok($st->size < 1024*1024, "size is < 1M");


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


    # We point the guest at a qcow2 image, but tell it that is
    # is raw. Thus *nothing* should ever try to open the backing
    # store in this qcow2 image.
    $xml = $tck->generic_domain(name => "tck")
	->disk(type => "file",
	       src => $pathmain,
	       dst => "vdb",
	       cache => "unsafe")
	->as_xml;

    diag "Defining an inactive domain config $xml";
    my $dom;
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain config");

    diag "Starting inactive domain config";
    $dom->create;
    ok($dom->get_id() > 0, "running domain has an ID > 0");


    diag "Trying another domain lookup by name";
    my $dom1;
    ok_domain(sub { $dom1 = $conn->get_domain_by_name("tck") }, "the running domain object");
    ok($dom1->get_id() > 0, "running domain has an ID > 0");

    open PID, "/var/run/libvirt/qemu/tck.pid"
	or die "cannot read PID /var/run/libvirt/qemu/tck.pid: $!";
    my $pid = <PID>;
    chomp $pid;
    close PID;

    open STAT, "/proc/$pid/status"
	or die "cannot read status /proc/$pid/status: $!";

    my ($gid, $uid);
    while (<STAT>) {
	if (/Uid:\s*(\d+)/) {
	    $uid = $1;
	} elsif (/Gid:\s*(\d+)/) {
	    $gid = $1;
	}
    }
    close STAT;

    $st = stat($pathmain);
    ok($st, "path $pathmain exists");
    diag "UID:GID on $pathmain is " . $st->uid . ":" . $st->gid;
    my $aclmain = `getfacl -n $pathmain`;
    diag "ACL on $pathmain is $aclmain";

    ok (($aclmain =~ "user:$uid:rw-") ||
	($st->uid == $uid), "Ownership or ACL of file $pathmain allows $uid");
    ok (($aclmain =~ "group:$gid:rw-") ||
	($st->gid == $gid), "Ownership or ACL of file $pathmain allows $gid");


    $st = stat($pathback);
    ok($st, "path $pathback exists");
    diag "UID:GID on $pathback is " . $st->uid . ":" . $st->gid;
    my $aclback = `getfacl -n $pathback`;
    diag "ACL on $pathback is $aclback";

    ok (($aclback !~ "user:$uid:") &&
	(($uid == $<) || $st->uid != $uid),
	"Ownership or ACL of file $pathback does not allow $uid");
    ok (($aclback !~ "group:$gid:") &&
	(($gid == $(+0) || $st->gid != $gid),
	"Ownership or ACL of file $pathback does not allow $gid");


    $st = stat($pathlast);
    ok($st, "path $pathlast exists");
    diag "UID:GID on $pathlast is " . $st->uid . ":" . $st->gid;
    my $acllast = `getfacl -n $pathlast`;
    diag "ACL on $pathlast is $acllast";

    ok (($acllast !~ "user:$uid:") &&
	(($uid == $<) || $st->uid != $uid),
	"Ownership or ACL of file $pathlast does not allow $uid");
    ok (($acllast !~ "group:$gid:") &&
	(($gid == $(+0) || $st->gid != $gid),
	"Ownership or ACL of file $pathlast does not allow $gid");

    diag "Destroying the running domain";
    $dom->destroy();

    diag "Undefining the inactive domain config";
    $dom->undefine;

    ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);
}
