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

network/090-invalid-ops-when-inactive.t - Operations that are invalid when inactive

=head1 DESCRIPTION

The test case validates the certain invalid operations are
rejected on inactive networks. It makes no sense to be able
to invoke things like 'suspend', 'resume', 'save', 'migrate'
etc on an inactive network.

=cut

use strict;
use warnings;

use Test::More tests => 2;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_network("tck")->as_xml;

diag "Creating a new persistent network";
my $dom;
ok_network(sub { $dom = $conn->define_network($xml); }, "defined persistent network object");

ok_error(sub { $dom->destroy }, "destroy of inactive network not allowed");


# end
