#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2015 Red Hat, Inc.
# Copyright (C) 2015 Zhe Peng <zpeng@redhat.com>
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

host/080-baseline-cpu.t

=head1 DESCRIPTION

The test case validates test APIs including

$conn->baseline_cpu()
Sys::Virt::BASELINE_CPU_MIGRATABLE


=cut

use strict;
use warnings;

use Test::More tests => 1;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my @cpuxml = <<EOF;
<cpu>
<arch>x86_64</arch>
<model>Westmere</model>
<vendor>Intel</vendor>
<topology sockets='1' cores='6' threads='2'/>
<feature name='invtsc'/>
<feature name='rdtscp'/>
<feature name='pdpe1gb'/>
<feature name='dca'/>
<feature name='pcid'/>
<feature name='pdcm'/>
<feature name='pbe'/>
<feature name='tm'/>
<feature name='ht'/>
<feature name='ss'/>
<feature name='acpi'/>
<feature name='ds'/>
<feature name='vme'/>
<pages unit='KiB' size='4'/>
<pages unit='KiB' size='2048'/>
<pages unit='KiB' size='1048576'/>
</cpu>
EOF

my $xml = $conn->baseline_cpu(\@cpuxml, Sys::Virt::BASELINE_CPU_MIGRATABLE);

#check baseline not include feature 'invtsc'
isnt($xml, "invtsc" , "Baseline migratable without invtsc feature");


