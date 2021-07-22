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

domain/065-persistent-redefine.t - Persistent domain config update

=head1 DESCRIPTION

The test case validates that an existing persistent domain
config can be updated without needing it to be first undefined.

=cut

use strict;
use warnings;

use Test::More tests => 9;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $cfg = $tck->generic_domain(name => "tck")->uuid("11111111-1111-1111-1111-111111111111");
$cfg->on_reboot("restart");
my $xml1 = $cfg->as_xml;
$cfg->on_reboot("destroy");
my $xml2 = $cfg->as_xml;


diag "Defining an inactive domain config";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml1) }, "defined persistent domain config");

diag "Updating inactive domain config";
ok_domain(sub { $dom = $conn->define_domain($xml2) }, "re-defined persistent domain config");

diag "Undefining inactive domain config";
$dom->undefine;
$dom->DESTROY;
$dom = undef;

diag "Checking that persistent domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);


diag "Defining inactive domain config again";
ok_domain(sub { $dom = $conn->define_domain($xml1) }, "defined persistent domain config");


diag "Starting inactive domain config";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");


diag "Updating inactive domain config";
ok_domain(sub { $dom = $conn->define_domain($xml2) }, "re-defined persistent domain config");

diag "Destroying the running domain";
$dom->destroy();


my $dom1;
diag "Checking there is still an inactive domain config";
ok_domain(sub { $dom1 = $conn->get_domain_by_name("tck") }, "the inactive domain object");
is($dom1->get_id(), -1 , "inactive domain has an ID == -1");

diag "Undefining the inactive domain config";
$dom->undefine;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);
