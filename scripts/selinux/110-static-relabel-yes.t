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

domain/110-static-relabel-yes.t - Static label generation with relabelling

=head1 DESCRIPTION

The test case validates that static labels are honoured
and files can be relabelled

=cut

use strict;
use warnings;

use Test::More tests => 6;

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
    skip "Only relevant to SELinux hosts", 6 unless $info && $info->{model} eq "selinux";

    my $disk = $tck->create_sparse_disk("selinux", "tck", 50);

    my $origmcs = "c1,c2";
    my $origdomainlabel = $SELINUX_DOMAIN_CONTEXT . ":" . $origmcs;
    my $origimagelabel = selinux_restore_file_context($disk);

    my $xml = $tck->generic_domain(name => "tck")
	->seclabel(model => "selinux", type => "static", relabel => "yes", label => $origdomainlabel)
	->disk(src => $disk, dst => "vdb", type => "file")
	->as_xml;

    diag "Creating a new transient domain";
    my $dom;
    ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

    diag $dom->get_xml_description();
    my $domainlabel = xpath($dom, "string(/domain/seclabel[\@model='selinux']/label)");
    diag "domainlabel $domainlabel";
    my $imagelabel = xpath($dom, "string(/domain/seclabel[\@model='selinux']/imagelabel)");
    diag "imagelabel $imagelabel";
    my $imagetype = selinux_get_type($imagelabel);
    my $imagemcs = selinux_get_mcs($imagelabel);

    is($origdomainlabel, $domainlabel, "static label is $domainlabel");
    is($imagetype, $SELINUX_IMAGE_TYPE, "image label type is $SELINUX_DOMAIN_TYPE");
    is($imagemcs, $origmcs, "image label mcs is $origmcs");

    is(selinux_get_file_context($disk), $imagelabel, "$disk label is $imagelabel");

    diag "Destroying the transient domain";
    $dom->destroy;

    is(selinux_get_file_context($disk), $origimagelabel, "$disk label is $origimagelabel");
}

# end
