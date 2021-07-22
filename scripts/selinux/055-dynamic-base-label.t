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

domain/055-dynamic-base-label.t - Hybrid label generation with relabelling

=head1 DESCRIPTION

The test case validates that hybrid label generation works,
together with flat relabelling of resources.

=cut

use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;

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
    skip "Only relevant to SELinux hosts", 10 unless $info && $info->{model} eq "selinux";

    my $disk = $tck->create_sparse_disk("selinux", "tck", 50);

    my $origlabel = selinux_restore_file_context($disk);

    my $xml = $tck->generic_domain(name => "tck")
	->seclabel(model => "selinux", type => "dynamic", relabel => "yes", baselabel => $SELINUX_OTHER_CONTEXT)
	->disk(src => $disk, dst => "vdb", type => "file")
	->as_xml;

    diag "Creating a new transient domain";
    my $dom = $conn->define_domain($xml);
    lives_ok(sub { $dom->create() }, "started persistent domain object");

    my $domainlabel = xpath($dom, "string(/domain/seclabel/label)");
    diag "domainlabel $domainlabel";
    my $imagelabel = xpath($dom, "string(/domain/seclabel/imagelabel)");
    diag "imagelabel $imagelabel";
    my $domaintype = selinux_get_type($domainlabel);
    my $imagetype = selinux_get_type($imagelabel);

    is($domaintype, $SELINUX_OTHER_TYPE, "dynamic domain label type is $SELINUX_OTHER_TYPE");
    is($imagetype, $SELINUX_IMAGE_TYPE, "dynamic image label type is $SELINUX_IMAGE_TYPE");

    my $domainmcs = selinux_get_mcs($domainlabel);
    my $imagemcs = selinux_get_mcs($imagelabel);

    is($domainmcs, $imagemcs, "Domain MCS $domainmcs == Image MCS $imagemcs");

    is(selinux_get_file_context($disk), $imagelabel, "$disk label is $imagelabel");
    diag "Destroying the transient domain";
    $dom->destroy;

    my $model = xpath($dom, 'string(/domain/seclabel/@model)');
    is ($model, "selinux", "model is still defined");

    $domainlabel = xpath($dom, "string(/domain/seclabel/label)");
    diag "domainlabel $domainlabel";
    $imagelabel = xpath($dom, "string(/domain/seclabel/imagelabel)");
    diag "imagelabel $imagelabel";
    my $baselabel = xpath($dom, "string(/domain/seclabel/baselabel)");
    diag "baselabel $baselabel";
    is ($domainlabel, "", "domainlabel is cleared");
    is ($imagelabel, "", "imagelabel is cleared");
    is ($baselabel, $SELINUX_OTHER_CONTEXT, "baselabel is $SELINUX_OTHER_CONTEXT");

    is(selinux_get_file_context($disk), $origlabel, "$disk label is $origlabel");
}

# end
