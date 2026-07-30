#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2014 Red Hat, Inc.
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

event/156-metadata-event.t

=head1 DESCRIPTION

The test case validates that libvirt can throw out guest metadata change event when changes

$conn->domain_event_register_any()
Sys::Virt::Domain::EVENT_ID_METADATA_CHANGE


=cut

use strict;
use warnings;

use Test::More tests => 7;

use Sys::Virt::TCK;
use Test::Exception;

Sys::Virt::Event::register_default();

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}


my $metadata;
my $callback;

sub check_metadata_change {
    my $expect_metadata = shift;
    $metadata = '';
    while ($metadata eq '') {
        Sys::Virt::Event::run_default();
    }
    is($expect_metadata, $metadata, "Get the expected metadata field");
}

sub metadata_change_cb {
    my $con = shift;
    my $dom = shift;
    $metadata = shift;
    diag "Domain metadata change event happens with metadata is $metadata"
}

lives_ok(sub {
        $callback = $conn->domain_event_register_any(undef,
            Sys::Virt::Domain::EVENT_ID_METADATA_CHANGE,
            \&metadata_change_cb);
    }, "Registered domain metadata change event");


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

my $title = "libvirt tck testing title";
my $des = "perl-Sys-Virt description";
lives_ok(sub {$dom->set_metadata(Sys::Virt::Domain::METADATA_TITLE, $title, undef, undef, 0)}, "Set title to $title" );
check_metadata_change(Sys::Virt::Domain::METADATA_TITLE);

lives_ok(sub {$dom->set_metadata(Sys::Virt::Domain::METADATA_DESCRIPTION, $des, undef, undef, 0)}, "Set description to $des" );
check_metadata_change(Sys::Virt::Domain::METADATA_DESCRIPTION);

diag "Destroy domain";
$dom->destroy;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

