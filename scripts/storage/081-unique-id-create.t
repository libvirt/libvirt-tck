#!/usr/bin/perl
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

storage/081-unique-id-create.t - Unique identifier checking at create

=head1 DESCRIPTION

The test case validates the unique identifiers are being
validated for uniqueness, and appropriate errors raised
upon error.

 - If existing VM has same UUID
      - If name also matches
           - If existing VM is running => raise error
           - Else => allow
      - Else => raise error

 - Else
      - If name matches => raise error
      - Else => allow

=cut

use strict;
use warnings;

use Test::More tests => 12;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name1 = "tck1";
my $name2 = "tck2";
my $uuid1 = "11111111-1111-1111-1111-111111111111";
my $uuid2 = "22222222-1111-1111-1111-111111111111";

# The initial config
my $xml = $tck->generic_pool("dir", $name1)->uuid($uuid1)->as_xml;
# One with a different UUID, matching name
my $xml_diffuuid = $tck->generic_pool("dir", $name1)->uuid($uuid2)->as_xml;
# One with a matching UUID, different name
my $xml_diffname = $tck->generic_pool("dir", $name2)->uuid($uuid1)->as_xml;
# One with a different UUID, different name
my $xml_diffboth = $tck->generic_pool("dir", $name2)->uuid($uuid2)->as_xml;

my $dir1 = $tck->create_empty_dir("storage-fs", $name1);
my $dir2 = $tck->create_empty_dir("storage-fs", $name2);

diag "Defining persistent pool config";
my ($pool, $pool1);
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "defined persistent pool", $name1);
#$pool->DESTROY;

diag "Trying to create a active pool with same name, same UUID";
ok_pool(sub { $pool = $conn->create_storage_pool($xml) }, "created persistent pool again", $name1);
$pool->destroy;

diag "Trying to create a active pool with same UUID, different name";
ok_error(sub { $conn->create_storage_pool($xml_diffname) }, "error raised from duplicate pool");

diag "Trying to create a active pool with different UUID, same name";
ok_error(sub { $conn->create_storage_pool($xml_diffuuid) }, "error raised from duplicate pool");

diag "Trying to create a active pool with different UUID, different name";
ok_pool(sub { $pool1 = $conn->create_storage_pool($xml_diffboth) }, "created transient pool", $name2);

diag "Destroying active transient pool";
$pool1->destroy;
#$pool->DESTROY;


diag "Checking that pool has now gone";
ok_error(sub { $conn->get_storage_pool_by_name($name2) }, "NO_POOL error raised from undefined pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);


diag "Starting persistent pool config";
$pool->create();
#$pool->DESTROY;

diag "Trying to create a active pool with same name, same UUID";
ok_error(sub { $pool = $conn->create_storage_pool($xml) }, "cannot create already running pool");

diag "Trying to create a active pool with same UUID, different name";
ok_error(sub { $pool = $conn->create_storage_pool($xml_diffname) }, "error raised from duplicate pool");

diag "Trying to create a active pool with different UUID, same name";
ok_error(sub { $pool = $conn->create_storage_pool($xml_diffuuid) }, "error raised from duplicate pool");

diag "Trying to create a active pool with different UUID, different name";
ok_pool(sub { $pool1 = $conn->create_storage_pool($xml_diffboth) }, "created persistent pool", $name2);

diag "Destroying transient pool config";
$pool1->destroy;
#$pool->DESTROY;


diag "Checking that pool has now gone";
ok_error(sub { $conn->get_storage_pool_by_name($name2) }, "NO_POOL error raised from undefined pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

diag "Stopping & undefining persistent pool config";
$pool->destroy;
$pool->undefine;
diag "Checking that pool has now gone";
ok_error(sub { $conn->get_storage_pool_by_name($name1) }, "NO_POOL error raised from undefined pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

