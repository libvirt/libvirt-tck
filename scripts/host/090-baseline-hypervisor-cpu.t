#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2015 Red Hat, Inc.
# Copyright (C) 2018 Dan Zheng <dzheng@redhat.com>
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

host/090-baseline-hypervisor-cpu.t

=head1 DESCRIPTION

The test case validates test APIs including

$conn->baseline_hypervisor_cpu()
$conn->compare_hypervisor_cpu()
Sys::Virt::CPU_COMPARE_INCOMPATIBLE
Sys::Virt::CPU_COMPARE_SUPERSET
Sys::Virt::CPU_COMPARE_IDENTICAL

=cut

use strict;
use warnings;

use Test::More tests => 3;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

sub get_specific_xml {
  my $dom_xml = shift;
  my $elem_path = shift;
  my $xp = XML::XPath->new($dom_xml);
  my $nodeset = $xp->find($elem_path);
  my $node = $nodeset->get_node(1);
  my $node_xml = XML::XPath::XMLParser::as_string($node);
  return $node_xml;
}

my $arch = 'x86_64';
my $virttype = 'kvm';
my $xml = $conn->get_domain_capabilities(undef, $arch, undef, $virttype);
ok ($xml, "Get domain capabilities\n $xml");

my $cpuxml1 = <<EOF;
<cpu mode='custom' match='exact' check='full'>
  <model fallback='forbid'>Skylake-Client-IBRS</model>
  <vendor>Intel</vendor>
  <feature policy='require' name='ss'/>
  <feature policy='require' name='tsc_adjust'/>
  <feature policy='require' name='clflushopt'/>
  <feature policy='require' name='pdpe1gb'/>
  <feature policy='require' name='invtsc'/>
  <feature policy='require' name='hypervisor'/>
</cpu>
EOF

my $cpuxml2 = <<EOF;
<cpu mode='custom' match='exact'>
  <model fallback='forbid'>SandyBridge-IBRS</model>
  <vendor>Intel</vendor>
  <feature policy='require' name='vme'/>
  <feature policy='require' name='ss'/>
  <feature policy='require' name='pcid'/>
  <feature policy='require' name='arat'/>
  <feature policy='require' name='xsaveopt'/>
  <feature policy='require' name='invtsc'/>
  <feature policy='require' name='hypervisor'/>
</cpu>
EOF

my @cpuxml = ($cpuxml1, $cpuxml2);
my $base_cpu_model_xml = $conn->baseline_hypervisor_cpu(undef, $arch, undef, undef, \@cpuxml, 0);
ok ($base_cpu_model_xml =~ 'SandyBridge-IBRS', "Get domain baseline cpu model\n $base_cpu_model_xml");


my $cpu_xml = get_specific_xml($xml, '/domainCapabilities/cpu');
my $result = $conn->compare_hypervisor_cpu(undef, $arch, undef, undef, $cpu_xml, 0);
my %map_compare = (Sys::Virt::CPU_COMPARE_INCOMPATIBLE=>'This host is missing CPU features in the CPU xml',
                   Sys::Virt::CPU_COMPARE_SUPERSET=>'The host offers a superset of the CPU xml',
	           Sys::Virt::CPU_COMPARE_IDENTICAL=>'The host has an identical CPU xml');
ok($result > 0, "$map_compare{$result}" );

