#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat, Inc.
# Copyright (C) 2009-2010 Daniel P. Berrange
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

domain/207-disk-media-change.t - verify disk media change works

=head1 DESCRIPTION

The test case validates that it is possible to change media
on a CDROM disk in a running domain.

=cut

use strict;
use warnings;

use Test::More tests => 7;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

my $path1 = $tck->create_sparse_disk("200-disk-media-change", "extra1.img", 100);
my $path2 = $tck->create_sparse_disk("207-disk-media-change", "extra2.img", 100);

my $xml;

eval {
    $xml = $tck->generic_domain(name => "tck", ostype => "hvm")
	->disk(src => $path1, dst => "hdc", type => "file", device => "cdrom")
	->as_xml;
};
SKIP: {
    skip "media change only supported with HVM guests", 7 if $@;

    diag "Creating a new transient domain";
    my $dom;
    ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");


    my $diskxml1 = <<EOF;
<disk type='file' device='cdrom'>
  <source file='$path1'/>
  <target dev='hdc'/>
</disk>
EOF
    my $diskxml2 = <<EOF;
<disk type='file' device='cdrom'>
  <source file='$path2'/>
  <target dev='hdc'/>
</disk>
EOF
    my $diskxml3 = <<EOF;
<disk type='file' device='cdrom'>
  <target dev='hdc'/>
</disk>
EOF


    my $initialxml = $dom->get_xml_description;

    diag "Changing CDROM to $path2";
    lives_ok(sub { $dom->attach_device($diskxml2); }, "disk media has been changed");

    my $newxml = $dom->get_xml_description;

    ok($newxml =~ m|$path2|, "new XML has updated media");

    diag "Ejecting CDROM media";
    lives_ok(sub { $dom->attach_device($diskxml3); }, "disk media has been ejected");

    $newxml = $dom->get_xml_description;

    ok($newxml !~ m|$path2|, "new XML has no media");

    diag "Inserting CDROM media";
    lives_ok(sub { $dom->attach_device($diskxml1); }, "disk media has been inserted");

    my $finalxml = $dom->get_xml_description;

    ok($finalxml =~ m|$path1|, "final XML has properly updated media");
}
