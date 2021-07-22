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

storage/081-unique-id-caching.t - Unique identifier caching

=head1 DESCRIPTION

The test case validates that caching of virStoragePtr objects
is not causing incorrect unique identifiers to be reported
to apps.

The scheme is:

 - Create guest 'tck' with random UUID
 - Destroy guest, but keep $pool object referenced
 - Create guest 'tck' with random UUID

The bug is that the 2nd $pool object will still show the UUID
of the first. So verify that the 2nd $pool object has the
expected name and UUID.

This problem hit with provisioning in apps where an attempt
to start a guest failed, and the app re-tried with a slight
change in XML but same original name. If they relied on random
UUID generation, it could hit this caching bug.

The fix for this scheme actually allows for the reverse
problem to now emerge, if an app re-uses a UUID with a
different name. This is not a scenario that is expected
to happen during normal provisioning.

=cut

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name = "tck";
my $uuid1 = "11111111-1111-1111-1111-111111111111";
my $uuid2 = "22222222-1111-1111-1111-111111111111";

# The initial config
my $xml1 = $tck->generic_pool("dir", $name)->uuid($uuid1)->as_xml;
# One with a different UUID, matching name
my $xml2 = $tck->generic_pool("dir", $name)->uuid($uuid2)->as_xml;

my $dir1 = $tck->create_empty_dir("storage-fs", $name);

diag "Creating & destroying initial guest with $name, $uuid1";
my $pool1;
ok_pool(sub { $pool1 = $conn->create_storage_pool($xml1) }, "created persistent storage again", $name);

is($pool1->get_uuid_string(), $uuid1, "matching uuid");

diag "Killing initial guest";
lives_ok(sub {$pool1->destroy}, "destroyed initial storage");

diag "Checking that storage has now gone";
ok_error(sub { $conn->get_storage_pool_by_name($name) }, "NO_STORAGE error raised from undefined storage",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

diag "Creating & destroying second guest with $name, $uuid2";
my $pool2;
ok_pool(sub { $pool2 = $conn->create_storage_pool($xml2) }, "created persistent storage again", $name);

is($pool2->get_uuid_string(), $uuid2, "matching uuid");

diag "Killing second guest";
lives_ok(sub {$pool2->destroy}, "destroyed second storage");

diag "Checking that storage has now gone";
ok_error(sub { $conn->get_storage_pool_by_name($name) }, "NO_STORAGE error raised from undefined storage",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

