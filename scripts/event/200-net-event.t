#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2014 Red Hat, Inc.
# Copyright (C) 2014 Hao Liu <hliu@redhat.com>
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

event/200-net-event.t

=head1 DESCRIPTION

The testcase validate the register/unregister a network event and
check callback to be invoked when the network status is changed.

$conn->network_event_register_any()
Sys::Virt::Network::EVENT_ID_LIFECYCLE
Sys::Virt::Network::EVENT_DEFINED
Sys::Virt::Network::EVENT_STARTED
Sys::Virt::Network::EVENT_STOPPED
Sys::Virt::Network::EVENT_UNDEFINED

=cut

use strict;
use warnings;

use Test::More tests => 6;

use Sys::Virt::TCK;
use Test::Exception;

Sys::Virt::Event::register_default();

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $xml = $tck->generic_network("tck")->as_xml;
my $event;
my $net;
my $callback;

sub check_event {
    my $test_event = shift;
    my $event_name = shift;
    $event = '';
    while ($event eq '') {
        Sys::Virt::Event::run_default();
    }
    is($event, $test_event, "Get network event: $event_name");
}

sub lifecycle_cb {
    my $con = shift;
    my $network = shift;
    $event = shift;
    my $detail = shift;
}

lives_ok(sub {
        $callback = $conn->network_event_register_any(undef,
            Sys::Virt::Network::EVENT_ID_LIFECYCLE,
            \&lifecycle_cb);
    }, "registered network lifecycle event");

diag "Defining inactive network config";
$net = $conn->define_network($xml);
check_event(Sys::Virt::Network::EVENT_DEFINED, "defined");

diag "Starting inactive network config";
$net->create;
check_event(Sys::Virt::Network::EVENT_STARTED, "started");

diag "Destroying the running network";
$net->destroy;
check_event(Sys::Virt::Network::EVENT_STOPPED, "stopped");

diag "Undefining the inactive network config";
$net->undefine;
check_event(Sys::Virt::Network::EVENT_UNDEFINED, "undefined");

lives_ok(sub { $conn->network_event_deregister_any($callback); }, 
    "deregistered network lifecycle event");
