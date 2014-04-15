# -*- perl -*-
#
# Copyright (C) 2009-2012 Red Hat, Inc.
# Copyright (C) 2012 Osier Yang
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

domain/212-set-numa-parameters.t - Set NUMA parameters

=head1 DESCRIPTION

The test case validates the internal data structure is consistent
after the API call to set NUMA parameters for a domain.

=cut

use strict;
use warnings;

use Test::More tests => 13;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink "tck.img" if -f "tck.img";
}


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Creating a new persistent domain";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

diag "Starting inactive domain";
$dom->create;
ok($dom->get_id > 0, "running domain with ID > 0");

# NUMA mode can't be changed for a live domain
my %params = (
    Sys::Virt::Domain::NUMA_NODESET => '0',
);

diag "Set numa parameters, affects live and config";
lives_ok(sub {$dom->set_numa_parameters(\%params, Sys::Virt::Domain::AFFECT_LIVE | Sys::Virt::Domain::AFFECT_CONFIG)}, "set_numa_parameters");

diag "Get numa parameters";
my $params = $dom->get_numa_parameters(Sys::Virt::Domain::AFFECT_LIVE);
ok($params->{Sys::Virt::Domain::NUMA_NODESET} eq '0', 'Check nodeset');

diag "Destroy the domain";
$dom->destroy;

diag "Make sure the domain can be started after setting numa parameters";
$dom->create;
ok($dom->get_id > 0, "running domain with ID > 0");

diag "Get numa parameters";
$params = $dom->get_numa_parameters(Sys::Virt::Domain::AFFECT_LIVE);
ok($params->{Sys::Virt::Domain::NUMA_NODESET} eq '0', 'Check nodeset');

diag "Destroy the domain";
$dom->destroy;

$params{Sys::Virt::Domain::NUMA_MODE} = Sys::Virt::Domain::NUMATUNE_MEM_STRICT;

diag "Set numa parameters, affects next boot";
lives_ok(sub {$dom->set_numa_parameters(\%params, Sys::Virt::Domain::AFFECT_CONFIG)}, "set_numa_parameters");

diag "Get numa parameters";
$params = $dom->get_numa_parameters(Sys::Virt::Domain::AFFECT_CONFIG);
ok($params->{Sys::Virt::Domain::NUMA_MODE} == Sys::Virt::Domain::NUMATUNE_MEM_STRICT, 'Check mode');
ok($params->{Sys::Virt::Domain::NUMA_NODESET} eq '0', 'Check nodeset');

diag "Make sure the domain can be started after setting numa parameters";
$dom->create;
ok($dom->get_id > 0, "running domain with ID > 0");

diag "Get numa parameters";
$params = $dom->get_numa_parameters(Sys::Virt::Domain::AFFECT_LIVE);
ok($params->{Sys::Virt::Domain::NUMA_MODE} == Sys::Virt::Domain::NUMATUNE_MEM_STRICT, 'Check mode');
ok($params->{Sys::Virt::Domain::NUMA_NODESET} eq '0', 'Check nodeset');

diag "Destroying the persistent domain";
$dom->destroy;
$dom->undefine;

diag "Checking that transient domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);

# end
