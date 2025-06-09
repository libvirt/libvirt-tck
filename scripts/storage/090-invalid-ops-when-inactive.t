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

storage/090-invalid-ops-when-inactive.t - Operations that are invalid when inactive

=head1 DESCRIPTION

The test case validates the certain invalid operations are
rejected on inactive storage pools. It makes no sense to be
able to invoke things like 'destroy', 'refresh', etc on an
inactive pool

=cut

use strict;
use warnings;

use Test::More tests => 6;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_pool("dir")->as_xml;

diag "Creating a new persistent pool";
my $dom;
ok_pool(sub { $dom = $conn->define_storage_pool($xml); }, "defined persistent pool object");

ok_error(sub { $dom->destroy }, "destroy of inactive pool not allowed");
ok_error(sub { $dom->refresh }, "refresh of inactive pool not allowed");
ok_error(sub { $dom->list_volumes() }, "list_volumes of inactive pool not allowed");
ok_error(sub { $dom->create_volume("<xml>") }, "create_volume of inactive pool not allowed");
ok_error(sub { $dom->clone_volume("<xml>", undef) }, "clone_volume of inactive pool not allowed");


# end
