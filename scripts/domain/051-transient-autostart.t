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

domain/051-transient-autostart.t - Transient domain autostart

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


my $xml = $tck->generic_domain("tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain { $dom = $conn->create_domain($xml) } "created transient domain object";

my $auto = $dom->get_autostart();

ok(!$auto, "autostart is disabled for transient VMs");

ok_error { $dom->set_autostart(1) } "Set autostart not supported on transient VMs", Sys::Virt::Error::ERR_INTERNAL_ERROR;

diag "Destroying the transient domain";
$dom->destroy;

diag "Checking that transient domain has gone away";
ok_error { $conn->get_domain_by_name("tck") } "NO_DOMAIN error raised from missing domain", 42;

# end
