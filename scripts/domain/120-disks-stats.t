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

domain/120-disk-stats.t - check disk I/O stats work

=head1 DESCRIPTION

The test case validates the it is possible to query disk stats
from a running guest.

=cut

use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Defining an inactive domain config";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain config");

my $devset = xpath($dom, "/domain/devices/disk/target/\@dev");
my @disks = map { $_->getNodeValue } $devset->get_nodelist();

my $nkernel = xpath($dom, "count(/domain/os/kernel)");

my $stats;
SKIP: {
    skip "no disks present", 4 unless int(@disks) > 0;

    diag "disk stats should be rejected for inactive guest";
    ok_error(sub { $stats = $dom->block_stats($disks[0]) }, "INVALID_OPERATION for stats on inactive guest", Sys::Virt::Error::ERR_OPERATION_INVALID);

    diag "Starting inactive domain config";
    $dom->create;
    ok($dom->get_id() > 0, "running domain has an ID > 0");


    lives_ok(sub { $stats = $dom->block_stats($disks[0]) });

    skip "no disk stats likely when booting off kernel", 1 if $nkernel > 0;

    ok($stats->{rd_req} > 0 ||
       $stats->{rd_bytes} > 0 ||
       $stats->{wr_req} > 0 ||
       $stats->{wr_bytes} > 0 ||
       $stats->{errs} > 0, "at least one block statistic was non-zero");
}


diag "Destroying the transient domain";
$dom->destroy;

diag "Undefining the inactive domain config";
$dom->undefine;

diag "Checking that transient domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);

# end
