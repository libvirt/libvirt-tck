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

network/065-persistent-redefine.t - Persistent network config update

=head1 DESCRIPTION

The test case validates that an existing persistent network
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


my $cfg = $tck->generic_network("tck")->uuid("11111111-1111-1111-1111-111111111111");
$cfg->bridge("tck1");
my $xml1 = $cfg->as_xml;
$cfg->bridge("tck2");
my $xml2 = $cfg->as_xml;


diag "Defining an inactive network config";
my $net;
ok_network(sub { $net = $conn->define_network($xml1) }, "defined persistent network config");

diag "Updating inactive network config";
ok_network(sub { $net = $conn->define_network($xml2) }, "re-defined persistent network config");

diag "Undefining inactive network config";
$net->undefine;
$net->DESTROY;
$net = undef;

diag "Checking that persistent network has gone away";
ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	 Sys::Virt::Error::ERR_NO_NETWORK);


diag "Defining inactive network config again";
ok_network(sub { $net = $conn->define_network($xml1) }, "defined persistent network config");


diag "Starting inactive network config";
$net->create;
ok($net->is_active, "network is active");


diag "Updating inactive network config";
ok_network(sub { $net = $conn->define_network($xml2) }, "re-defined persistent network config");

diag "Destroying the running network";
$net->destroy();


my $net1;
diag "Checking there is still an inactive network config";
ok_network(sub { $net1 = $conn->get_network_by_name("tck") }, "the inactive network object");
ok(!$net1->is_active, "network is inactive");

diag "Undefining the inactive network config";
$net->undefine;

ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	 Sys::Virt::Error::ERR_NO_NETWORK);
