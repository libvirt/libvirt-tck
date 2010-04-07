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

domain/060-persistent-lifecycle.t - Persistent domain lifecycle

=head1 DESCRIPTION

The test case validates the core lifecycle operations on
persistent domains. A persistent domain is one with a
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


my $xml = $tck->generic_domain("tck")->as_xml;

diag "Defining an inactive domain config";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain config");

my $auto = $dom->get_autostart();
ok (!$auto, "autostart is disabled for a newly defined domain");

diag "Trying to enable autostart on the domain";
lives_ok(sub { $dom->set_autostart(1); }, "set autostart on domain");

$auto = $dom->get_autostart();
ok ($auto, "autostart is now enabled for the new domain");


diag "Trying to disable autostart on the domain";
lives_ok(sub { $dom->set_autostart(0); }, "unset autostart on domain");

$auto = $dom->get_autostart();
ok (!$auto, "autostart is now disabled for the new domain");



diag "Starting inactive domain config";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");


$auto = $dom->get_autostart();
ok (!$auto, "autostart is disabled for a newly running domain");

diag "Trying to enable autostart on the running domain";
lives_ok(sub { $dom->set_autostart(1); }, "set autostart on domain");

$auto = $dom->get_autostart();
ok ($auto, "autostart is now enabled for the new domain");


diag "Trying to disable autostart on the running domain";
lives_ok(sub { $dom->set_autostart(0); }, "unset autostart on domain");

$auto = $dom->get_autostart();
ok (!$auto, "autostart is now disabled for the new domain");


diag "Trying to enable autostart on the running domain yet again";
lives_ok(sub { $dom->set_autostart(1); }, "set autostart on domain");

$auto = $dom->get_autostart();
ok ($auto, "autostart is now enabled for the new domain");


diag "Destroying the running domain";
$dom->destroy();

$auto = $dom->get_autostart();
ok ($auto, "autostart is still enabled for the shutoff domain");


diag "Undefining the inactive domain config";
$dom->undefine;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);
