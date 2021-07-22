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

domain/100-disk-encryption.t - LUKS disk encryption

=head1 DESCRIPTION

The test case verifies that libvirt is able to both create LUKS encrypted
storage volumes as well as start a domain with such disks assigned.

=cut

use strict;
use warnings;

use Test::More tests => 8;

use Sys::Virt::TCK;
use Test::Exception;
use File::Spec::Functions qw(catfile);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

SKIP: {
    skip "Only relevant to QEMU driver", 8 unless $conn->get_type() eq "QEMU";

my $dir = $tck->bucket_dir("300-disk-encryption");
my $disk = catfile($dir, "demo.img");


my $secretXML = <<EOF;
<secret ephemeral='no' private='no'>
  <uuid>212c459b-b02c-41fc-8ae2-714cc31612c5</uuid>
  <usage type='volume'>
    <volume>$disk</volume>
  </usage>
</secret>
EOF

my $secret;

lives_ok(sub { $secret = Sys::Virt::Secret->_new(connection => $conn, xml => $secretXML) }, "secret created");

$secret->set_value("Hello World");

my $secretUUID = $secret->get_uuid_string();

my $poolXML = Sys::Virt::TCK::StoragePoolBuilder->new()
    ->source_dir($dir)->target($dir)->as_xml();

my $pool;

diag "Creating pool $poolXML";
lives_ok(sub { $pool = $conn->create_storage_pool($poolXML) }, "pool created");


my $volXML = Sys::Virt::TCK::StorageVolBuilder->new(name => "demo.img")
    ->capacity(1024*1024*1024)
    ->format("raw")
    ->encryption_format("luks")
    ->secret($secretUUID)
    ->as_xml();

my $vol;

diag "Creating volume $volXML";
lives_ok(sub { $vol = $pool->create_volume($volXML) }, "volume created");

my $xml = $tck->generic_domain(name => "tck")
    ->disk(format => { name => "qemu", type => "raw" },
	   encryption_format => "luks",
	   secret => $secretUUID,
	   type => "file",
	   src => $disk,
	   dst => "hdb")
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


diag "Destroying the running domain";
$dom->destroy();

diag "Undefining the inactive domain config";
$dom->undefine;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

$secret->undefine;
}
