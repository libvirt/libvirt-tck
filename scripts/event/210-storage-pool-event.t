#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2017 Red Hat, Inc.
# Copyright (C) 2017 Dan Zheng <dzheng@redhat.com>
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

event/210-storage-pool-event.t

=head1 DESCRIPTION

The testcase validate the register/unregister a storage pool event and
check callback to be invoked when the storage pool status is changed.

$conn->storage_pool_event_register_any()
Sys::Virt::StoragePool::EVENT_ID_LIFECYCLE
Sys::Virt::StoragePool::EVENT_ID_REFRESH
Sys::Virt::StoragePool::EVENT_DEFINED
Sys::Virt::StoragePool::EVENT_STARTED
Sys::Virt::StoragePool::EVENT_STOPPED
Sys::Virt::StoragePool::EVENT_UNDEFINED
Sys::Virt::StoragePool::EVENT_CREATED
Sys::Virt::StoragePool::EVENT_DELETED

=cut

use strict;
use warnings;

use Test::More tests => 11;

use Sys::Virt::TCK;
use Test::Exception;

Sys::Virt::Event::register_default();

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name_dir = "dir-pool-tck";
my $xml = $tck->generic_pool("dir", $name_dir)->as_xml;
my $dir = $tck->create_empty_dir("storage-fs", $name_dir);
my ($event, $event_pool);
my $storage_pool;
my ($callback_lifecycle, $callback_refresh);

sub check_event {
    my $test_event = shift;
    my $event_name = shift;
    $event = '';
    while ($event eq '') {
        Sys::Virt::Event::run_default();
    }
    my $event_pool_name = $event_pool->get_name();
    is($event, $test_event, "Get event '$event_name' for storage pool '$event_pool_name'");
}

sub lifecycle_cb {
    my $con = shift;
    $event_pool = shift;
    $event = shift;
}

sub refresh_cb {
    my $con = shift;
    $event_pool = shift;
    my $event_pool_name = $event_pool->get_name();
    is($event_pool_name, $storage_pool->get_name(),
          "The callback of event 'refresh' is invoked for storage pool '$event_pool_name'");
}

lives_ok(sub {
        $callback_lifecycle = $conn->storage_pool_event_register_any(undef,
            Sys::Virt::StoragePool::EVENT_ID_LIFECYCLE,
            \&lifecycle_cb);
    }, "registered storage pool lifecycle event");

lives_ok(sub {
        $callback_refresh = $conn->storage_pool_event_register_any(undef,
            Sys::Virt::StoragePool::EVENT_ID_REFRESH,
            \&refresh_cb);
    }, "registered storage pool refresh event");


diag "Defining inactive storage pool config";
$storage_pool = $conn->define_storage_pool($xml);
check_event(Sys::Virt::StoragePool::EVENT_DEFINED, "defined");

diag "Building inactive storage pool";
$storage_pool->build(0);
check_event(Sys::Virt::StoragePool::EVENT_CREATED, "built");

diag "Starting inactive storage pool config";
$storage_pool->create();
check_event(Sys::Virt::StoragePool::EVENT_STARTED, "started");

diag "Refreshing active storage pool";
$storage_pool->refresh();

diag "Destroying the storage pool";
$storage_pool->destroy();
check_event(Sys::Virt::StoragePool::EVENT_STOPPED, "stopped");

diag "Deleting the inactive storage pool";
$storage_pool->delete();
check_event(Sys::Virt::StoragePool::EVENT_DELETED, "deleted");

diag "Undefining the inactive storage pool config";
$storage_pool->undefine();
check_event(Sys::Virt::StoragePool::EVENT_UNDEFINED, "undefined");

lives_ok(sub { $conn->storage_pool_event_deregister_any($callback_lifecycle); },
    "deregistered storage pool lifecycle event");
lives_ok(sub { $conn->storage_pool_event_deregister_any($callback_refresh); },
    "deregistered storage pool refresh event");

