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

domain/080-unique-id-define.t - Unique identifier checking at define

=head1 DESCRIPTION

The test case validates the unique identifiers are being
validated for uniqueness, and appropriate errors raised
upon error.


 - If existing VM has same UUID
      - If name also matches => allow
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
ok_domain { $dom = $conn->define_domain($xml) } "defined persistent domain", $name1;
#$dom->DESTROY;

diag "Trying to define a inactive guest with same name, same UUID";
ok_domain { $dom = $conn->define_domain($xml) } "defined persistent domain again", $name1;

diag "Trying to define a inactive guest with same UUID, different name";
ok_error { $conn->define_domain($xml_diffname) } "error raised from duplicate domain";

diag "Trying to define a inactive guest with different UUID, same name";
ok_error { $conn->define_domain($xml_diffuuid) } "error raised from duplicate domain";

diag "Trying to define a inactive guest with different UUID, different name";
ok_domain { $dom1 = $conn->define_domain($xml_diffboth) } "defined persistent domain", $name2;

diag "Undefining persistent guest config";
$dom1->undefine;
#$dom->DESTROY;


diag "Checking that domain has now gone";
ok_error { $conn->get_domain_by_name($name2) } "NO_DOMAIN error raised from undefined domain", 42;


diag "Starting persistent domain config";
$dom->create();
#$dom->DESTROY;

diag "Trying to define a inactive guest with same name, same UUID";
ok_domain { $dom = $conn->define_domain($xml) } "defined persistent domain again", $name1;

diag "Trying to define a inactive guest with same UUID, different name";
ok_error { $dom = $conn->define_domain($xml_diffname) } "error raised from duplicate domain";

diag "Trying to define a inactive guest with different UUID, same name";
ok_error { $dom = $conn->define_domain($xml_diffuuid) } "error raised from duplicate domain";

diag "Trying to define a inactive guest with different UUID, different name";
ok_domain { $dom1 = $conn->define_domain($xml_diffboth) } "defined persistent domain", $name2;

diag "Undefining persistent guest config";
$dom1->undefine;
#$dom->DESTROY;


diag "Checking that domain has now gone";
ok_error { $conn->get_domain_by_name($name2) } "NO_DOMAIN error raised from undefined domain", 42;

diag "Stopping & undefining persistent guest config";
$dom->destroy;
$dom->undefine;
diag "Checking that domain has now gone";
ok_error { $conn->get_domain_by_name($name1) } "NO_DOMAIN error raised from undefined domain", 42;

