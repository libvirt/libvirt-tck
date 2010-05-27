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

pool/065-persistent-redefine.t - Persistent pool config update

=head1 DESCRIPTION

The test case validates that an existing persistent pool
config can be updated without needing it to be first undefined.

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
my $cfg = $tck->generic_pool("dir", $name)
    ->uuid("11111111-1111-1111-1111-111111111111");

$cfg->mode("0700");
my $xml1 = $cfg->as_xml;
$cfg->mode("0777");
my $xml2 = $cfg->as_xml;

my $dir = $tck->create_empty_dir("storage-fs", $name);


diag "Defining an inactive pool config";
my $pool;
ok_pool(sub { $pool = $conn->define_storage_pool($xml1) }, "defined persistent pool config");

diag "Updating inactive pool config";
ok_pool(sub { $pool = $conn->define_storage_pool($xml2) }, "re-defined persistent pool config");

diag "Undefining inactive pool config";
$pool->undefine;
$pool->DESTROY;
$pool = undef;

diag "Checking that persistent pool has gone away";
ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);

diag "Defining inactive pool config again";
ok_pool(sub { $pool = $conn->define_storage_pool($xml1) }, "defined persistent pool config");


diag "Starting inactive pool config";
$pool->create;
is($pool->get_info()->{state}, Sys::Virt::StoragePool::STATE_RUNNING, "pool is in RUNNING state");


diag "Updating inactive pool config";
ok_pool(sub { $pool = $conn->define_storage_pool($xml2) }, "re-defined persistent pool config");

diag "Destroying the running pool";
$pool->destroy();


my $pool1;
diag "Checking there is still an inactive pool config";
ok_pool(sub { $pool1 = $conn->get_storage_pool_by_name("tck") }, "the inactive pool object");
is($pool->get_info()->{state}, Sys::Virt::StoragePool::STATE_INACTIVE, "pool is in INACTIVE state");

diag "Undefining the inactive pool config";
$pool->undefine;

ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);
