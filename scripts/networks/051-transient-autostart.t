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

network/051-transient-autostart.t - Transient network autostart

=head1 DESCRIPTION

The test case validates that the autostart command returns a
suitable error message when used on a transient VM.

=cut

use strict;
use warnings;

use Test::More tests => 4;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_network("tck")->as_xml;

diag "Creating a new transient network";
my $net;
ok_network(sub { $net = $conn->create_network($xml) }, "created transient network object");

my $auto = $net->get_autostart();

ok(!$auto, "autostart is disabled for transient VMs");

ok_error(sub { $net->set_autostart(1) }, "Set autostart not supported on transient VMs", Sys::Virt::Error::ERR_OPERATION_INVALID);

diag "Destroying the transient network";
$net->destroy;

diag "Checking that transient network has gone away";
ok_error(sub { $conn->get_network_by_name("tck") }, "NO_network error raised from missing network",
	 Sys::Virt::Error::ERR_NO_NETWORK);

# end
