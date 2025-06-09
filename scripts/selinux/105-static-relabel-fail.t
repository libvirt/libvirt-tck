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

domain/101-static-relabel-fail.t - Static label generation failed startup

=head1 DESCRIPTION

The test case validates that static labels are honoured
and that if the image label is wrong, the VM fails to
start

=cut

use strict;
use warnings;

use Test::More tests => 2;

use Sys::Virt::TCK;
use Sys::Virt::TCK::SELinux;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $info;
eval {
    $info = $conn->get_node_security_model();
};

SKIP: {
    skip "Only relevant to SELinux hosts", 2 unless $info && $info->{model} eq "selinux";

    my $disk = $tck->create_sparse_disk("selinux", "tck", 50);

    my $origmcs = ":c1,c2";
    my $origdomainlabel = $SELINUX_DOMAIN_CONTEXT . $origmcs;
    my $origimagelabel = selinux_restore_file_context($disk);

    my $xml = $tck->generic_domain(name => "tck")
	->seclabel(model => "selinux", type => "static", relabel => "no", label => $origdomainlabel)
	->disk(src => $disk, dst => "vdb", type => "file")
	->as_xml;

    diag "Creating a new transient domain";
    my $dom;
    eval { $dom = $conn->create_domain($xml) };
    if ($dom) {
	my $info = $dom->get_security_label();
	is($info->{enforcing}, 0, "domain started due to permissive mode");

	diag "Destroying the transient domain";
	$dom->destroy;
    } else {
	ok(!$dom, "domain is not started");
    }

    is(selinux_get_file_context($disk), $origimagelabel, "$disk label is $origimagelabel");
}

# end
