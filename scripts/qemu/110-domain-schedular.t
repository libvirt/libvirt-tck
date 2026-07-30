#!/usr/bin/env perl
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

qemu/110-domain-schedular.t

=head1 DESCRIPTION

The test case validates that the domain scheduler parameters
can be successfully set and retrieved.

$dom->get_scheduler_type()
$dom->get_scheduler_parameters
Sys::Virt::Domain::AFFECT_CURRENT
Sys::Virt::Domain::AFFECT_CONFIG
Sys::Virt::Domain::AFFECT_LIVE
Sys::Virt::Domain::SCHEDULER_CPU_SHARES
Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA
Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD

=cut

use strict;
use warnings;

use Test::More tests => 24;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

SKIP: {
    skip "Only relevant to QEMU driver", 24 unless $conn->get_type() eq "QEMU";

# Define different params value
my $cpu_shares_live = 500;
my $vcpu_period_live = 1000000;
my $vcpu_quota_live = 17592186044415;
my $cpu_shares_config = 1;
my $vcpu_period_config = 1000;
my $vcpu_quota_config = 1000;
my $cpu_shares_current = 3;
my $vcpu_period_current = 999999;
my $vcpu_quota_current = 999999;


# Create a new persistent domain and check status
my $dom_name = "domschedinfo";
my $xml = $tck->generic_domain(name => "$dom_name")->as_xml;

diag "Defining an inactive domain config";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain config");

diag "Starting inactive domain config";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");

diag "Get domain scheduler type";
my $sched_type;
ok( $sched_type = $dom->get_scheduler_type(), "Get domain scheduler type is $sched_type" );


diag "Get current domain scheduler parameters";
my $sched_info;
lives_ok ( sub{ $sched_info = $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT) },
	"Get domain scheduler info");
while ( my ($k, $v) = each %{$sched_info} ) {
        print "$k => $v\n";
}


diag "Set/Get live domain scheduler parameters";
my %sched_param = (Sys::Virt::Domain::SCHEDULER_CPU_SHARES=>$cpu_shares_live,
	Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD=>$vcpu_period_live,
	Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA=>$vcpu_quota_live);
lives_ok( sub { $dom->set_scheduler_parameters(\%sched_param, Sys::Virt::Domain::AFFECT_LIVE) },
	"Set live domain scheduler info" );
diag "Get live domain scheduler parameters";
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_LIVE)->{Sys::Virt::Domain::SCHEDULER_CPU_SHARES},
	$cpu_shares_live, "Get domain cpu shares is $cpu_shares_live");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_LIVE)->{Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA},
	$vcpu_quota_live, "Get domain vcpu quota is $vcpu_quota_live");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_LIVE)->{Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD},
	$vcpu_period_live, "Get domain vcpu period is $vcpu_period_live");


diag "Get inactive domain scheduler parameters";
lives_ok ( sub{ $sched_info = $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CONFIG) },
	"Get domain scheduler info");
while ( my ($k, $v) = each %{$sched_info} ) {
        print "$k => $v\n";
}


diag "Set/Get persistent domain scheduler parameters";
%sched_param = (Sys::Virt::Domain::SCHEDULER_CPU_SHARES=>$cpu_shares_config,
	Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD=>$vcpu_period_config,
	Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA=>$vcpu_quota_config);
lives_ok( sub { $dom->set_scheduler_parameters(\%sched_param, Sys::Virt::Domain::AFFECT_CONFIG) },
	"Set persistent domain scheduler info" );
diag "Get persistent domain scheduler parameters";
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CONFIG)->{Sys::Virt::Domain::SCHEDULER_CPU_SHARES},
	$cpu_shares_config, "Get domain cpu shares is $cpu_shares_config");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CONFIG)->{Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA},
	$vcpu_quota_config, "Get domain vcpu quota is $vcpu_quota_config");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CONFIG)->{Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD},
	$vcpu_period_config, "Get domain vcpu period is $vcpu_period_config");


# Destroy domain
diag "Destroying the persistent domain";
$dom->destroy;


diag "Get current domain scheduler parameters";
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT)->{Sys::Virt::Domain::SCHEDULER_CPU_SHARES},
	$cpu_shares_config, "Get domain cpu shares is $cpu_shares_config");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT)->{Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA},
	$vcpu_quota_config, "Get domain vcpu quota is $vcpu_quota_config");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT)->{Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD},
	$vcpu_period_config, "Get domain vcpu period is $vcpu_period_config");


diag "Set current domain scheduler parameters";
%sched_param = (Sys::Virt::Domain::SCHEDULER_CPU_SHARES=>$cpu_shares_current,
	Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD=>$vcpu_period_current,
	Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA=>$vcpu_quota_current);
lives_ok( sub { $dom->set_scheduler_parameters(\%sched_param, Sys::Virt::Domain::AFFECT_CURRENT) },
	"Set current domain scheduler info" );

#Start domain
diag "Starting inactive domain config";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");

diag "Get current domain scheduler parameters";
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT)->{Sys::Virt::Domain::SCHEDULER_CPU_SHARES},
        $cpu_shares_current, "Get domain cpu shares is $cpu_shares_current");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT)->{Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA},
        $vcpu_quota_current, "Get domain vcpu quota is $vcpu_quota_current");
is ( $dom->get_scheduler_parameters(Sys::Virt::Domain::AFFECT_CURRENT)->{Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD},
        $vcpu_period_current, "Get domain vcpu period is $vcpu_period_current");


# Destroy domain
diag "Destroying the transient domain";
$dom->destroy;

diag "Checking there is still an inactive domain config";
ok_domain(sub { $dom = $conn->get_domain_by_name("$dom_name") }, "The inactive domain object exists");
is($dom->get_id(), -1 , "inactive domain has an ID == -1");

diag "Undefining the inactive domain config";
$dom->undefine;

ok_error(sub { $conn->get_domain_by_name("$dom_name") }, "NO_DOMAIN error raised from missing domain",
         Sys::Virt::Error::ERR_NO_DOMAIN);
}
# end
