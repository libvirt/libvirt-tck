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

pool/060-persistent-lifecycle.t - Persistent pool lifecycle

=head1 DESCRIPTION

The test case validates the core lifecycle operations on
persistent pools. A persistent pool is one with a
configuration enabling it to be tracked when inactive.

=cut

use strict;
use warnings;

use Test::More tests => 9;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name = "tck";
my $xml = $tck->generic_pool("dir", $name)->as_xml;

my $dir = $tck->create_empty_dir("storage-fs", $name);

diag "Defining an inactive pool config";
my $pool;
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "defined persistent pool config");

diag "Undefining inactive pool config";
$pool->undefine;
$pool->DESTROY;
$pool = undef;

diag "Checking that persistent pool has gone away";
ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

diag "Defining inactive pool config again";
ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "defined persistent pool config");


diag "Starting inactive pool config";
$pool->create;
is($pool->get_info()->{state}, Sys::Virt::StoragePool::STATE_RUNNING, "pool is in RUNNING state");


diag "Trying another pool lookup by name";
my $pool1;
ok_pool(sub { $pool1 = $conn->get_storage_pool_by_name("tck") }, "the running pool object");
is($pool->get_info()->{state}, Sys::Virt::StoragePool::STATE_RUNNING, "pool is in RUNNING state");


diag "Destroying the running pool";
$pool->destroy();


diag "Checking there is still an inactive pool config";
ok_pool(sub { $pool1 = $conn->get_storage_pool_by_name("tck") }, "the inactive pool object");
is($pool->get_info()->{state}, Sys::Virt::StoragePool::STATE_INACTIVE, "pool is in INACTIVE state");

diag "Undefining the inactive pool config";
$pool->undefine;

ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);
