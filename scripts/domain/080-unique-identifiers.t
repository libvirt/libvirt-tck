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

domain/080-unique-identifiers.t - Unique identifier checking

=head1 DESCRIPTION

The test case validates the unique identifiers are being
validated for uniqueness, and appropriate errors raised
upon error.

Two sets of preconditions

 - An inactive domain exists with UUID 'u' and name 'n'

     => If a new transient domain creation is requested
        with duplicate UUID or name, error must be raised

        XXX Is this right ? Or should we just follow
            next two rules instead...


     => If a new persistent domain definition is requested
        with duplicate UUID, then..
           * If name matches, then allow it
           * If name does not match, then allow it, and
             rename current config

     => If a new persistent domain definition is requested
        with duplicate name, then..
           * If UUID matches, then allow it
           * If UUID does not match, then raise error


 - A running domain exists with UUID 'u' and name 'n'

     => If a new transient domain creation is requested
        with duplicate UUID or name, error must be raised

     => If a new persistent domain definition is requested
        with duplicate UUID, then..
           * If name matches, then allow it
           * If name does not match, then allow it, and
             rename current config

     => If a new persistent domain definition is requested
        with duplicate name, then..
           * If UUID matches, then allow it
           * If UUID does not match, then raise error


=cut

use strict;
use warnings;

use Test::More tests => 40;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $name1 = "test1";
my $name2 = "test2";
my $uuid1 = "11111111-1111-1111-1111-111111111111";
my $uuid2 = "22222222-1111-1111-1111-111111111111";

# The initial config
my $xml = $tck->generic_domain($name1)->uuid($uuid1)->as_xml;
# One with a different UUID, matching name
my $xml_diffuuid = $tck->generic_domain($name1)->uuid($uuid2)->as_xml;
# One with a matching UUID, different name
my $xml_diffname = $tck->generic_domain($name2)->uuid($uuid1)->as_xml;


# First check all the rules for a inactive guest
diag "Starting phase 1";

diag "Defining persistent domain config";
my $dom = $conn->define_domain($xml);
isa_ok($dom, "Sys::Virt::Domain", "defined persistent domain");
is($dom->get_name, $name1, "name is $name1");
#$dom->DESTROY;

diag "Trying to create a running guest with same name, different UUID";
eval { $conn->create_domain($xml_diffuuid); };
isa_ok($@, "Sys::Virt::Error", "error raised from clashing name");
is($@->code, 9, "error code is OPERATION_FAILED");


diag "Trying to create a running guest with same UUID, different name";
eval { $conn->create_domain($xml_diffname); };
isa_ok($@, "Sys::Virt::Error", "error raised from clashing name");
is($@->code, 9, "error code is OPERATION_FAILED");


diag "Trying to define a inactive guest with same name, different UUID";
eval { $conn->define_domain($xml_diffuuid); };
isa_ok($@, "Sys::Virt::Error", "error raised from clashing name");
is($@->code, 9, "error code is OPERATION_FAILED");


diag "Trying to define a inactive guest with same UUID, different name";
$dom = $conn->define_domain($xml_diffname);
isa_ok($dom, "Sys::Virt::Domain", "defined persistent domain");
is($dom->get_name, $name2, "name is $name2");
#$dom->DESTROY;

diag "Checking that domain test1 has really gone after rename";
eval { $conn->get_domain_by_name($name1); };
isa_ok($@, "Sys::Virt::Error", "error raised from missing (renamed) domain");
is($@->code, 42, "error code is NO_DOMAIN");



diag "Checking the guest really has got new name";
$dom = $conn->get_domain_by_name($name2);
isa_ok($dom, "Sys::Virt::Domain", "fetched persistent domain");
is($dom->get_name, $name2, "name is $name2");

diag "Undefining persistent guest config";
$dom->undefine;
#$dom->DESTROY;


diag "Checking that domain has now gone";
eval { $conn->get_domain_by_name($name2); };
isa_ok($@, "Sys::Virt::Error", "error raised from undefined domain");
is($@->code, 42, "error code is NO_DOMAIN");

diag "Checking that original domain is still gone";
eval { $conn->get_domain_by_name($name1); };
isa_ok($@, "Sys::Virt::Error", "error raised from undefined domain");
is($@->code, 42, "error code is NO_DOMAIN");




# Now the same again, but starting with a running guest
diag "Starting phase 2";


diag "Creating transient active domain";
$dom = $conn->create_domain($xml);
isa_ok($dom, "Sys::Virt::Domain", "created transient domain");
is($dom->get_name, $name1, "name is $name1");
#$dom->DESTROY;

diag "Trying to create a running guest with same name, different UUID";
eval { $conn->create_domain($xml_diffuuid); };
isa_ok($@, "Sys::Virt::Error", "error raised from clashing name");
is($@->code, 9, "error code is OPERATION_FAILED");


diag "Trying to create a running guest with same UUID, different name";
eval { $conn->create_domain($xml_diffname); };
isa_ok($@, "Sys::Virt::Error", "error raised from clashing name");
is($@->code, 9, "error code is OPERATION_FAILED");


diag "Trying to define a inactive guest with same name, different UUID";
eval { $conn->define_domain($xml_diffuuid); };
isa_ok($@, "Sys::Virt::Error", "error raised from clashing name");
is($@->code, 9, "error code is OPERATION_FAILED");


diag "Trying to define a inactive guest with same UUID, different name";
$dom = $conn->define_domain($xml_diffname);
isa_ok($dom, "Sys::Virt::Domain", "defined persistent domain");
is($dom->get_name, $name2, "name is $name2");
#$dom->DESTROY;

diag "Checking that domain test1 has really gone after rename";
eval { $conn->get_domain_by_name($name1); };
isa_ok($@, "Sys::Virt::Error", "error raised from missing (renamed) domain");
is($@->code, 42, "error code is NO_DOMAIN");



diag "Checking the guest really has got new name";
$dom = $conn->get_domain_by_name($name2);
isa_ok($dom, "Sys::Virt::Domain", "fetched persistent domain");
is($dom->get_name, $name2, "name is $name2");

diag "Stopping active guest";
$dom->destroy;

diag "Checking the guest has still got new name";
$dom = $conn->get_domain_by_name($name2);
isa_ok($dom, "Sys::Virt::Domain", "fetched persistent domain");
is($dom->get_name, $name2, "name is $name2");

diag "Checking that original domain is still gone";
eval { $conn->get_domain_by_name($name1); };
isa_ok($@, "Sys::Virt::Error", "error raised from undefined domain");
is($@->code, 42, "error code is NO_DOMAIN");


diag "Undefining persistent guest config";
$dom->undefine;
#$dom->DESTROY;


diag "Checking that domain has now gone";
eval { $conn->get_domain_by_name($name2); };
isa_ok($@, "Sys::Virt::Error", "error raised from undefined domain");
is($@->code, 42, "error code is NO_DOMAIN");

diag "Checking that original domain is still gone";
eval { $conn->get_domain_by_name($name1); };
isa_ok($@, "Sys::Virt::Error", "error raised from undefined domain");
is($@->code, 42, "error code is NO_DOMAIN");


