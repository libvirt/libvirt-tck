# -*- perl -*-
#
# Copyright (C) 2012-2013 Red Hat, Inc.
# Copyright (C) 2012 Kyla Zhang <weizhan@redhat.com>
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

domain/180-interface-parameters.t - test interface set/get

=head1 DESCRIPTION

The test case validates that all following APIs work well include
dom->get_interface_parameters
dom->set_interface_parameters
con->is_alive

=cut

use strict;
use warnings;

use Test::More tests => 10;

use Sys::Virt::TCK;
use Test::Exception;
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

# test is_alive
my $live = $conn->is_alive();
ok($live > 0, "Connection is alive");

my $xml = $tck->generic_domain(name => "tck")
              ->interface(type => "network", source => "default", model => "virtio", mac => "52:54:00:22:22:22")
              ->as_xml;

my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "Create domain");
$xml = $dom->get_xml_description();

diag "Set/Get interface parameters";
my %params = (Sys::Virt::Domain::BANDWIDTH_IN_AVERAGE=>1000, Sys::Virt::Domain::BANDWIDTH_IN_PEAK=>1001,
              Sys::Virt::Domain::BANDWIDTH_IN_BURST=>1002, Sys::Virt::Domain::BANDWIDTH_OUT_AVERAGE=>1003,
              Sys::Virt::Domain::BANDWIDTH_OUT_PEAK=>1004, Sys::Virt::Domain::BANDWIDTH_OUT_BURST=>1005);
lives_ok(sub {$dom->set_interface_parameters("vnet0", \%params)}, "Set vnet0 parameters");
for my $key (sort keys %params) {
     diag "Set $key => $params{$key} ";
}

my $param = $dom->get_interface_parameters("vnet0", 0);
my $in_average = $param->{Sys::Virt::Domain::BANDWIDTH_IN_AVERAGE};
my $in_burst = $param->{Sys::Virt::Domain::BANDWIDTH_IN_BURST};
my $in_peak = $param->{Sys::Virt::Domain::BANDWIDTH_IN_PEAK};
my $out_average = $param->{Sys::Virt::Domain::BANDWIDTH_OUT_AVERAGE};
my $out_burst = $param->{Sys::Virt::Domain::BANDWIDTH_OUT_BURST};
my $out_peak = $param->{Sys::Virt::Domain::BANDWIDTH_OUT_PEAK};
is($in_average, 1000, "Get inbound average 1000");
is($in_burst, 1002, "Get inbound burst 1002");
is($in_peak, 1001, "Get inbound peak 1001");
is($out_average, 1003, "Get outbound average 1003");
is($out_burst, 1005, "Get outbound burst 1005");
is($out_peak, 1004, "Get outbound peak 1004");

diag "Destroy domain";
$dom->destroy;

ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);
