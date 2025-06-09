#!/usr/bin/env perl
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

pool/050-transient-lifecycle.t - Transient pool lifecycle

=head1 DESCRIPTION

The test case validates the core lifecycle operations on
transient pools. A transient pool has no configuration
file so, once destroyed, all trace of the pool should
disappear.

=cut

use strict;
use warnings;

use Test::More tests => 2;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name = "tck1";
my $xml = $tck->generic_pool("dir", $name)->as_xml;

my $dir = $tck->create_empty_dir("storage-fs", $name);

diag "Creating a new transient pool";
my $dom;
ok_pool(sub { $dom = $conn->create_storage_pool($xml) }, "created transient pool object");

diag "Destroying the transient pool";
$dom->destroy;

diag "Checking that transient pool has gone away";
ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

# end
