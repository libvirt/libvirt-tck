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

domain/081-unique-id-caching.t - Unique identifier caching

=head1 DESCRIPTION

The test case validates that caching of virDomainPtr objects
is not causing incorrect unique identifiers to be reported
to apps.

The scheme is:

 - Create guest 'tck' with random UUID
 - Destroy guest, but keep $dom object referenced
 - Create guest 'tck' with random UUID

The bug is that the 2nd $dom object will still show the UUID
of the first. So verify that the 2nd $dom object has the
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
my $xml1 = $tck->generic_domain(name => $name)->uuid($uuid1)->as_xml;
# One with a different UUID, matching name
my $xml2 = $tck->generic_domain(name => $name)->uuid($uuid2)->as_xml;

diag "Creating & destroying initial guest with $name, $uuid1";
my $dom1;
ok_domain(sub { $dom1 = $conn->create_domain($xml1) }, "created persistent domain again", $name);

is($dom1->get_uuid_string(), $uuid1, "matching uuid");

diag "Killing initial guest";
lives_ok(sub {$dom1->destroy}, "destroyed initial domain");

diag "Checking that domain has now gone";
ok_error(sub { $conn->get_domain_by_name($name) }, "NO_DOMAIN error raised from undefined domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);

diag "Creating & destroying second guest with $name, $uuid2";
my $dom2;
ok_domain(sub { $dom2 = $conn->create_domain($xml2) }, "created persistent domain again", $name);

is($dom2->get_uuid_string(), $uuid2, "matching uuid");

diag "Killing second guest";
lives_ok(sub {$dom2->destroy}, "destroyed second domain");

diag "Checking that domain has now gone";
ok_error(sub { $conn->get_domain_by_name($name) }, "NO_DOMAIN error raised from undefined domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);

