#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2015 Red Hat, Inc.
# Copyright (C) 2015 Zhe Peng <zpeng@redhat.com>
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

event/060-device-added.t

=head1 DESCRIPTION

The testcase validate the register/unregister a domain blockjob event and
check callback to be invoked when a block job is called.

Sys::Virt::Domain::EVENT_ID_DEVICE_ADDED

=cut

use strict;
use warnings;

use Test::More tests => 5;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();

Sys::Virt::Event::register_default();

my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $event;
my $callback;
my $device;

sub check_device_add {
    my $expected_device = shift;
    my $device_name = shift;
    $device = '';
    while ($device eq '') {
        Sys::Virt::Event::run_default();
    }
    is($device, $expected_device, "Get device action: $device_name");
}

sub deviceadd_cb {
    my $con = shift;
    my $dom = shift;
    $device = shift;
}

lives_ok(sub {
        $callback = $conn->domain_event_register_any(undef,
            Sys::Virt::Domain::EVENT_ID_DEVICE_ADDED,
            \&deviceadd_cb);
    }, "Registered domain device add event");

my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created domain object");

my $path = $tck->create_sparse_disk("deviceadded", "extra.img", 100);

my $dev = "vdb";
my $bus = "virtio";

my $diskxml = <<EOF;
<disk type='file' device='disk'>
  <source file='$path'/>
  <target dev='$dev' bus='$bus'/>
</disk>
EOF

lives_ok(sub { $dom->create() }, "started persistent domain object");

my $initialxml = $dom->get_xml_description;

diag "Attaching the new disk $path";
lives_ok(sub { $dom->attach_device($diskxml); }, "disk has been attached");

check_device_add("virtio-disk1","added");

