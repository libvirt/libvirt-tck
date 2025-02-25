#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2012 Red Hat, Inc.
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

domain/110-memory-balloon.t: test setting and getting memory/max memory

=head1 DESCRIPTION

The testcase validates the basic function of domain memory balloon via setting
its value of current memory, max memory.

=cut

use strict;
use warnings;

use Test::More tests => 16;

use Sys::Virt::TCK;
use Test::Exception;
use File::Spec::Functions qw(catfile catdir rootdir);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

diag "Define a new real domain, default memory is 1048576";
my $default_mem = 1048576;
my $max_mem1 = 1572864;
my $max_mem2 = 1148576;
my $config_mem = 924288;
my $live_mem = 824288;
my $current_mem = 724288;

# Install a guest with default memory size
my $xml = $tck->generic_domain(name => "tck", fullos => 1, netmode => "network")->as_xml;
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");


diag "Set max memory for inactive domain";
lives_ok(sub { $dom->set_max_memory("$max_mem1") }, "Set max memory $max_mem1");
diag "Get max memory from inactive domain";
is($dom->get_max_memory(), $max_mem1, "Get max memory $max_mem1");


diag "Start domain";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");

$tck->wait_for_vm_to_boot($dom);

diag "Get max memory for domain when domain is active";
is($dom->get_max_memory(), $max_mem1, "Get max memory is $max_mem1");


diag "Set memory with flag MEM_CONFIG";
lives_ok(sub { $dom->set_memory("$config_mem", Sys::Virt::Domain::MEM_CONFIG) },
	"Set persistent memory value $config_mem");
diag "Get current memory";
is($dom->get_info()->{memory}, $default_mem, "Get current memory is $default_mem");


diag "Set memory with flag MEM_CURRENT";
lives_ok(sub { $dom->set_memory("$current_mem", Sys::Virt::Domain::MEM_CURRENT) },
	"Set current memory value $current_mem");
sleep(3);
diag "Get current memory";
is($dom->get_info()->{memory}, $current_mem, "Get current memory is $current_mem");


diag "Set memory with flag MEM_LIVE";
lives_ok(sub { $dom->set_memory("$live_mem", Sys::Virt::Domain::MEM_LIVE) },
	"Set live memory value $live_mem");
sleep(3);
diag "Get current memory";
is($dom->get_info()->{memory}, $live_mem, "Get current memory is $live_mem");


diag "Set max memory for running domain";
ok_error(sub { $dom->set_max_memory("$default_mem") }, "Not allowed to set max memory for running domain");

diag "Destroy domain";
$dom->destroy;

diag "Get current memory";
is($dom->get_info()->{memory}, $config_mem, "Get current memory is $config_mem");


diag "Set max memory with set_memory";
lives_ok(sub { $dom->set_memory("$max_mem2", Sys::Virt::Domain::MEM_MAXIMUM) },
	"Set max memory $max_mem2");
diag "Get max memory";
is($dom->get_info()->{maxMem}, $max_mem2, "Get max memory is $max_mem2");


diag "Setting memory with flag MEM_LIVE for inactive domain";
ok_error(sub { $dom->set_memory("$live_mem", Sys::Virt::Domain::MEM_LIVE) },
	"Not allowed to set memory with flag MEM_LIVE for inactive domain");
