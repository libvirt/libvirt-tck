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

network/060-persistent-lifecycle.t - Persistent network lifecycle

=head1 DESCRIPTION

The test case validates the core lifecycle operations on
persistent networks. A persistent network is one with a
configuration enabling it to be tracked when inactive.

=cut

use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;
use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_network("tck")->as_xml;

diag "Defining an inactive network config";
my $net;
ok_network(sub { $net = $conn->define_network($xml) }, "defined persistent network config");

my $auto = $net->get_autostart();
ok (!$auto, "autostart is disabled for a newly defined network");

diag "Trying to enable autostart on the network";
lives_ok(sub { $net->set_autostart(1); }, "set autostart on network");

$auto = $net->get_autostart();
ok ($auto, "autostart is now enabled for the new network");


diag "Trying to disable autostart on the network";
lives_ok(sub { $net->set_autostart(0); }, "unset autostart on network");

$auto = $net->get_autostart();
ok (!$auto, "autostart is now disabled for the new network");



diag "Starting inactive network config";
$net->create;
ok($net->is_active, "network is active");


$auto = $net->get_autostart();
ok (!$auto, "autostart is disabled for a newly running network");

diag "Trying to enable autostart on the running network";
lives_ok(sub { $net->set_autostart(1); }, "set autostart on network");

$auto = $net->get_autostart();
ok ($auto, "autostart is now enabled for the new network");


diag "Trying to disable autostart on the running network";
lives_ok(sub { $net->set_autostart(0); }, "unset autostart on network");

$auto = $net->get_autostart();
ok (!$auto, "autostart is now disabled for the new network");


diag "Trying to enable autostart on the running network yet again";
lives_ok(sub { $net->set_autostart(1); }, "set autostart on network");

$auto = $net->get_autostart();
ok ($auto, "autostart is now enabled for the new network");


diag "Destroying the running network";
$net->destroy();

$auto = $net->get_autostart();
ok ($auto, "autostart is still enabled for the shutoff network");


diag "Undefining the inactive network config";
$net->undefine;

ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	 Sys::Virt::Error::ERR_NO_NETWORK);
