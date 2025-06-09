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

domain/090-invalid-ops-when-inactive.t - Operations that are invalid when inactive

=head1 DESCRIPTION

The test case validates the certain invalid operations are
rejected on inactive domains. It makes no sense to be able
to invoke things like 'suspend', 'resume', 'save', 'migrate'
etc on an inactive domain.

=cut

use strict;
use warnings;

use Test::More tests => 11;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Creating a new persistent domain";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml); }, "defined persistent domain object");

ok_error(sub { $dom->block_stats("hda") }, "block_stats of inactive domain not allowed");
ok_error(sub { $dom->core_dump("core.img", 0) }, "core_dump of inactive domain not allowed");
ok_error(sub { $dom->destroy }, "destroy of inactive domain not allowed");
ok_error(sub { $dom->interface_stats("eth0") }, "interface_stats of inactive domain not allowed");
ok_error(sub { $dom->memory_peek(0, 100, 0) }, "memory_peek of inactive domain not allowed");
#ok_error(sub { $dom->migrate($conn, undef, undef, undef, 0) }, "migrate of inactive domain not allowed");
ok_error(sub { $dom->pin_vcpu(1, 1) }, "pin_vcpu of inactive domain not allowed");
ok_error(sub { $dom->reboot(0) }, "reboot of inactive domain not allowed");
ok_error(sub { $dom->save("save.img") }, "save of inactive domain not allowed");
ok_error(sub { $dom->shutdown }, "shutdown of inactive domain not allowed");
ok_error(sub { $dom->suspend }, "suspend of inactive domain not allowed");


# end
