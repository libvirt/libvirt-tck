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

use Test::More tests => 16;
use Test::Exception;
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

my $auto = $pool->get_autostart();
ok (!$auto, "autostart is disabled for a newly defined pool");

diag "Trying to enable autostart on the pool";
lives_ok(sub { $pool->set_autostart(1); }, "set autostart on pool");

$auto = $pool->get_autostart();
ok ($auto, "autostart is now enabled for the new pool");


diag "Trying to disable autostart on the pool";
lives_ok(sub { $pool->set_autostart(0); }, "unset autostart on pool");

$auto = $pool->get_autostart();
ok (!$auto, "autostart is now disabled for the new pool");



diag "Starting inactive pool config";
$pool->create;
is($pool->get_info()->{state}, Sys::Virt::StoragePool::STATE_RUNNING, "pool is in RUNNING state");


$auto = $pool->get_autostart();
ok (!$auto, "autostart is disabled for a newly running pool");

diag "Trying to enable autostart on the running pool";
lives_ok(sub { $pool->set_autostart(1); }, "set autostart on pool");

$auto = $pool->get_autostart();
ok ($auto, "autostart is now enabled for the new pool");


diag "Trying to disable autostart on the running pool";
lives_ok(sub { $pool->set_autostart(0); }, "unset autostart on pool");

$auto = $pool->get_autostart();
ok (!$auto, "autostart is now disabled for the new pool");


diag "Trying to enable autostart on the running pool yet again";
lives_ok(sub { $pool->set_autostart(1); }, "set autostart on pool");

$auto = $pool->get_autostart();
ok ($auto, "autostart is now enabled for the new pool");


diag "Destroying the running pool";
$pool->destroy();

$auto = $pool->get_autostart();
ok ($auto, "autostart is still enabled for the shutoff pool");


diag "Undefining the inactive pool config";
$pool->undefine;

ok_error(sub { $conn->get_storage_pool_by_name("tck") }, "NO_POOL error raised from missing pool",
	 Sys::Virt::Error::ERR_NO_STORAGE_POOL);
