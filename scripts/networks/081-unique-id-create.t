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

network/081-unique-id-create.t - Unique identifier checking at create

=head1 DESCRIPTION

The test case validates the unique identifiers are being
validated for uniqueness, and appropriate errors raised
upon error.

 - If existing VM has same UUID
      - If name also matches
           - If existing VM is running => raise error
           - Else => allow
      - Else => raise error

 - Else
      - If name matches => raise error
      - Else => allow

=cut

use strict;
use warnings;

use Test::More tests => 12;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name1 = "tck1";
my $name2 = "tck2";
my $uuid1 = "11111111-1111-1111-1111-111111111111";
my $uuid2 = "22222222-1111-1111-1111-111111111111";

# The initial config
my $xml = $tck->generic_network($name1)->uuid($uuid1)->as_xml;
# One with a different UUID, matching name
my $xml_diffuuid = $tck->generic_network($name1)->uuid($uuid2)->as_xml;
# One with a matching UUID, different name
my $xml_diffname = $tck->generic_network($name2)->uuid($uuid1)->as_xml;
# One with a different UUID, different name
my $xml_diffboth = $tck->generic_network($name2)->uuid($uuid2)->as_xml;

diag "Defining persistent network config";
my ($dom, $dom1);
ok_network(sub { $dom = $conn->define_network($xml) }, "defined persistent network", $name1);
#$dom->DESTROY;

diag "Trying to create a active network with same name, same UUID";
ok_network(sub { $dom = $conn->create_network($xml) }, "created persistent network again", $name1);
$dom->destroy;

diag "Trying to create a active network with same UUID, different name";
ok_error(sub { $conn->create_network($xml_diffname) }, "error raised from duplicate network");

diag "Trying to create a active network with different UUID, same name";
ok_error(sub { $conn->create_network($xml_diffuuid) }, "error raised from duplicate network");

diag "Trying to create a active network with different UUID, different name";
ok_network(sub { $dom1 = $conn->create_network($xml_diffboth) }, "created transient network", $name2);

diag "Destroying active transient network";
$dom1->destroy;
#$dom->DESTROY;


diag "Checking that network has now gone";
ok_error(sub { $conn->get_network_by_name($name2) }, "NO_network error raised from undefined network",
	 Sys::Virt::Error::ERR_NO_NETWORK);


diag "Starting persistent network config";
$dom->create();
#$dom->DESTROY;

diag "Trying to create a active network with same name, same UUID";
ok_error(sub { $dom = $conn->create_network($xml) }, "cannot create already running network");

diag "Trying to create a active network with same UUID, different name";
ok_error(sub { $dom = $conn->create_network($xml_diffname) }, "error raised from duplicate network");

diag "Trying to create a active network with different UUID, same name";
ok_error(sub { $dom = $conn->create_network($xml_diffuuid) }, "error raised from duplicate network");

diag "Trying to create a active network with different UUID, different name";
ok_network(sub { $dom1 = $conn->create_network($xml_diffboth) }, "created persistent network", $name2);

diag "Destroying transient network config";
$dom1->destroy;
#$dom->DESTROY;


diag "Checking that network has now gone";
ok_error(sub { $conn->get_network_by_name($name2) }, "NO_network error raised from undefined network",
	 Sys::Virt::Error::ERR_NO_NETWORK);

diag "Stopping & undefining persistent network config";
$dom->destroy;
$dom->undefine;
diag "Checking that network has now gone";
ok_error(sub { $conn->get_network_by_name($name1) }, "NO_network error raised from undefined network",
	 Sys::Virt::Error::ERR_NO_NETWORK);

