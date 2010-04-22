# -*- perl -*-
#
# Copyright (C) 2010 Red Hat, Inc.
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

domain/130-cpu-hotplug.t - whether CPU count can be changed

=head1 DESCRIPTION

The test case validates the it is possible to change the CPU
on a running guest.

XXX: Need libguestfs integration to check that it has truely
worked.

=cut

use strict;
use warnings;

use Test::More tests => 9;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_domain("tck")->as_xml;


diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

my $max;
lives_ok(sub { $max = $dom->get_max_vcpus() }, "queried max vcpus");

SKIP: {
    skip "SMP guests not supported", 4 unless $max > 1;

    diag "Increasing CPU count to max";
    lives_ok(sub { $dom->set_vcpus($max); }, "set vcpus to $max");

    my $info = $dom->get_info();

    is($info->{nrVirtCpu}, $max, "cpu count $info->{nrVirtCpu} is $max");

    diag "Decreasing CPU count to min";
    lives_ok(sub { $dom->set_vcpus(1); }, "set vcpus to 1");

    $info = $dom->get_info();
    is($info->{nrVirtCpu}, 1, "cpu count $info->{nrVirtCpu} is 1");


    diag "Try some illegal values";
    ok_error(sub { $dom->set_vcpus(0) }, "not allowed to set cpus negative");
    ok_error(sub { $dom->set_vcpus($max + 1) }, "not allowed to set cpus beyond maximum");
}

diag "Destroying the transient domain";
$dom->destroy;

diag "Checking that transient domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

# end
