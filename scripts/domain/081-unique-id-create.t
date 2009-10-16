# -*- perl -*-
#
# Copyright (C) 2009 Red Hat
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

domain/081-unique-id-create.t - Unique identifier checking at create

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
my $xml = $tck->generic_domain($name1)->uuid($uuid1)->as_xml;
# One with a different UUID, matching name
my $xml_diffuuid = $tck->generic_domain($name1)->uuid($uuid2)->as_xml;
# One with a matching UUID, different name
my $xml_diffname = $tck->generic_domain($name2)->uuid($uuid1)->as_xml;
# One with a different UUID, different name
my $xml_diffboth = $tck->generic_domain($name2)->uuid($uuid2)->as_xml;

diag "Defining persistent domain config";
my ($dom, $dom1);
ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain", $name1);
#$dom->DESTROY;

diag "Trying to create a active guest with same name, same UUID";
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created persistent domain again", $name1);
$dom->destroy;

diag "Trying to create a active guest with same UUID, different name";
ok_error(sub { $conn->create_domain($xml_diffname) }, "error raised from duplicate domain");

diag "Trying to create a active guest with different UUID, same name";
ok_error(sub { $conn->create_domain($xml_diffuuid) }, "error raised from duplicate domain");

diag "Trying to create a active guest with different UUID, different name";
ok_domain(sub { $dom1 = $conn->create_domain($xml_diffboth) }, "created transient domain", $name2);

diag "Destroying active transient guest";
$dom1->destroy;
#$dom->DESTROY;


diag "Checking that domain has now gone";
ok_error(sub { $conn->get_domain_by_name($name2) }, "NO_DOMAIN error raised from undefined domain", 42);


diag "Starting persistent domain config";
$dom->create();
#$dom->DESTROY;

diag "Trying to create a active guest with same name, same UUID";
ok_error(sub { $dom = $conn->create_domain($xml) }, "cannot create already running guest");

diag "Trying to create a active guest with same UUID, different name";
ok_error(sub { $dom = $conn->create_domain($xml_diffname) }, "error raised from duplicate domain");

diag "Trying to create a active guest with different UUID, same name";
ok_error(sub { $dom = $conn->create_domain($xml_diffuuid) }, "error raised from duplicate domain");

diag "Trying to create a active guest with different UUID, different name";
ok_domain(sub { $dom1 = $conn->create_domain($xml_diffboth) }, "created persistent domain", $name2);

diag "Destroying transient guest config";
$dom1->destroy;
#$dom->DESTROY;


diag "Checking that domain has now gone";
ok_error(sub { $conn->get_domain_by_name($name2) }, "NO_DOMAIN error raised from undefined domain", 42);

diag "Stopping & undefining persistent guest config";
$dom->destroy;
$dom->undefine;
diag "Checking that domain has now gone";
ok_error(sub { $conn->get_domain_by_name($name1) }, "NO_DOMAIN error raised from undefined domain", 42);

