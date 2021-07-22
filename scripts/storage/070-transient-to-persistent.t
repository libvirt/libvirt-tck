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

storage/070-transient-to-persistent.t - Converting transient to persistent

=head1 DESCRIPTION

The test case validates that a transient poolain can be converted
to a persistent one. This is achieved by defining a configuration
file while the transient poolain is running.

=cut

use strict;
use warnings;

use Test::More tests => 4;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name = "tck";
my $xml = $tck->generic_pool("dir", $name)->as_xml;

my $dir = $tck->create_empty_dir("storage-fs", $name);

diag "Creating a new transient pool";
my $pool;
ok_pool(sub { $pool = $conn->create_storage_pool($xml) }, "created transient pool");

my $livexml = $pool->get_xml_description();

diag "Defining config for transient guest";
my $pool1;
ok_pool(sub { $pool1 = $conn->define_storage_pool($livexml) }, "defined transient pool");

diag "Destroying active pool";
$pool->destroy;

diag "Checking that an inactive pool config still exists";
ok_pool(sub { $pool1 = $conn->get_storage_pool_by_name("tck") }, "transient pool config");

diag "Removing inactive pool config";
$pool->undefine;

diag "Checking that inactive pool has really gone";
ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);
