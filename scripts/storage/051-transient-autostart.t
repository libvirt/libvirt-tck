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

storage/051-transient-autostart.t - Transient pool autostart

=head1 DESCRIPTION

The test case validates that the autostart command returns a
suitable error message when used on a transient VM.

=cut

use strict;
use warnings;

use Test::More tests => 4;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name = "tck1";
my $xml = $tck->generic_pool("dir", $name)->as_xml;

my $dir = $tck->create_empty_dir("storage-fs", $name);

diag "Creating a new transient pool";
my $pool;
ok_pool(sub { $pool = $conn->create_storage_pool($xml) }, "created transient pool object");

my $auto = $pool->get_autostart();

ok(!$auto, "autostart is disabled for transient VMs");

ok_error(sub { $pool->set_autostart(1) }, "Set autostart not supported on transient VMs", Sys::Virt::Error::ERR_INTERNAL_ERROR);

diag "Destroying the transient pool";
$pool->destroy;

diag "Checking that transient pool has gone away";
ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_STORAGE_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

# end
