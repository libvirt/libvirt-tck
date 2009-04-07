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

domain/070-transient-to-persistent.t - Converting transient to persistent

=head1 DESCRIPTION

The test case validates that a transient domain can be converted
to a persistent one. This is achieved by defining a configuration
file while the transient domain is running.

=cut

use strict;
use warnings;

use Test::More tests => 5;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_domain("test")->as_xml;

diag "Creating a new transient domain";
my $dom = $conn->create_domain($xml);

isa_ok($dom, "Sys::Virt::Domain", "created transient domain");

my $livexml = $dom->get_xml_description();

diag "Defining config for transient guest";
my $dom1 = $conn->define_domain($livexml);
isa_ok($dom1, "Sys::Virt::Domain", "defined transient domain");

diag "Destroying active domain";
$dom->destroy;

diag "Checking that an inactive domain config still exists";
$dom1 = $conn->get_domain_by_name("test");
isa_ok($dom1, "Sys::Virt::Domain", "transient domain config");

diag "Removing inactive domain config";
$dom->undefine;

eval { $conn->get_domain_by_name("test") };
isa_ok($@, "Sys::Virt::Error", "error raised from missing domain");
is($@->code, 42, "error code is NO_DOMAIN");
