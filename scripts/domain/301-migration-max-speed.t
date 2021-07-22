# -*- perl -*-
#
# Copyright (C) 2013 Red Hat, Inc.
# Copyright (C) 2013 Zhe Peng <zpeng@redhat.com>
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

domain/301-migrate-max-speed.t - test migrate max speed set/get

=head1 DESCRIPTION

The test case validates that all following APIs work well include
dom->migrate_get_max_speed
dom->migrate_set_max_speed

=cut

use strict;
use warnings;

use Test::More tests => 5;

use Sys::Virt::TCK;
use Test::Exception;
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

my $xml = $tck->generic_domain(name => "tck")->as_xml;

my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "Create domain");

diag "Get migrate max speed";
my $speed = $dom->migrate_get_max_speed();
ok($speed, "Get migrate max speed $speed");

diag "Set migrate max speed";
$speed = 10000;
lives_ok(sub {$dom->migrate_set_max_speed($speed)}, "Set max speed to $speed");
my $get_speed = $dom->migrate_get_max_speed();
is ($speed, $get_speed, "Get speed same as set");

diag "Destroy domain";
$dom->destroy;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);
