#!/usr/bin/env perl
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

domain/070-transient-to-persistent.t - Converting transient to persistent

=head1 DESCRIPTION

The test case validates that a transient domain can be converted
to a persistent one. This is achieved by defining a configuration
file while the transient domain is running.

=cut

use strict;
use warnings;

use Test::More tests => 9;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $cfg = $tck->generic_domain(name => "tck");
$cfg->on_reboot("restart");

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($cfg->as_xml) }, "created transient domain");
ok(!$dom->is_persistent(), "active domain is transient");

$cfg->uuid($dom->get_uuid_string);
$cfg->on_reboot("destroy");

diag "Defining config for transient guest";
my $dom1;
ok_domain(sub { $dom1 = $conn->define_domain($cfg->as_xml) }, "defined persistent domain config");
ok($dom->is_persistent(), "active domain is now persistent");

is(xpath($dom, "string(/domain/on_reboot)"), "restart",
	"live domain keeps the transient lifecycle action");
is(xpath($dom, "string(/domain/on_reboot)",
	 Sys::Virt::Domain::XML_INACTIVE), "destroy",
	"persistent domain contains the newly defined lifecycle action");

diag "Destroying active domain";
$dom->destroy;

diag "Checking that an inactive domain config still exists";
ok_domain(sub { $dom1 = $conn->get_domain_by_name("tck") }, "persistent domain config");
is(xpath($dom1, "string(/domain/on_reboot)"), "destroy",
	"persistent lifecycle action survives domain destroy");

diag "Removing inactive domain config";
$dom->undefine;

diag "Checking that inactive domain has really gone";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);
