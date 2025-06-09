#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2023 Oracle and/or its affiliates
# Copyright (C) 2023 Shaleen Bathla (shaleen.bathla@oracle.com)
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

domain/405-ovmf-nvram-efi.t - Test OVMF related functions and flags for efi firmware

=head1 DESCRIPTION

The test cases validates OVMF related APIs and flags works as intended,
when we use the auto-generation logic by setting only the firmware attribute as efi.

Sys::Virt::Domain::UNDEFINE_KEEP_NVRAM
Sys::Virt::Domain::UNDEFINE_NVRAM

This issue was fixed a few years back in libvirt, where 'virsh undefine --nvram'
did NOT work as expected and did not clean up the nvram fd file.
It was fixed by below upstream commit :
https://gitlab.com/libvirt/libvirt/-/commit/b5308a12054255c80232f0c79c0b439994be2da0

=cut

use strict;
use warnings;

use Test::More tests => 14;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

sub setup_nvram {

    #  <os firmware='efi'>
    #     <loader secure='yes' />

    my $xml = $tck->generic_domain(name => "tck")->as_xml;
    my $xp = XML::XPath->new($xml);

    # <type arch='x86_64' machine='q35'>hvm</type>
    if ($xp->getNodeText("/domain/os/type/\@machine") ne 'q35') {
        diag "Changing guest machine type to q35";
        $xp->setNodeText("/domain/os/type/\@machine", "q35");
    }

    # <loader secure='yes' />
    my $loader_node = XML::XPath::Node::Element->new('loader');
    my $attr_secure = XML::XPath::Node::Attribute->new('secure');
    $attr_secure -> setNodeValue('yes');
    $loader_node->appendAttribute($attr_secure);

    # <smm state='on'>
    my $smm_node   = XML::XPath::Node::Element->new('smm');
    my $attr_state = XML::XPath::Node::Attribute->new('state');
    $attr_state -> setNodeValue("on");
    $smm_node -> appendAttribute($attr_state);

    #  <os firmware='efi'>
    my $attr_firmware = XML::XPath::Node::Attribute->new('firmware');
    $attr_firmware   -> setNodeValue('efi');

    # Make the changes in XML
    my ($root) = $xp->findnodes('/domain/os');
    $root->appendAttribute($attr_firmware);
    $root->appendChild($loader_node);
    ($root) = $xp->findnodes('/domain/features');
    $root->appendChild($smm_node);

    $xml = $xp->findnodes_as_string('/');
    diag $xml;
    return $xml;
}

diag "Defining an inactive domain config with nvram";
my $xml = setup_nvram();

SKIP: {
    skip "Please install OVMF and ensure necessary files exist", 5 if !defined($xml);

    # ------------------------------------------------------------------------------
    my $dom;
    diag "Test Sys::Virt::Domain::UNDEFINE_KEEP_NVRAM";
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined domain with nvram configure");

    diag "Creating a new persistent domain";
    lives_ok(sub { $dom->create() }, "created domain");

    my $livexml = $dom->get_xml_description();
    my $xp = XML::XPath->new($livexml);
    my $nvram_path = $xp->getNodeText("/domain/os/nvram");
    diag "nvram_path=($nvram_path)";

    diag "Destroying the persistent domain";
    lives_ok(sub { $dom->destroy() }, "destroyed domain");

    diag "Checking there is still an inactive domain config";
    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "the inactive domain object");
    is($dom->get_id(), -1 , "inactive domain has an ID == -1");

    diag "Undefining the domain";
    $dom->undefine(Sys::Virt::Domain::UNDEFINE_KEEP_NVRAM);

    diag "Checking that nvram file still exists";
    my $st = stat($nvram_path);
    ok($st, "File '$nvram_path' still exists as expected");

    diag "Cleaning nvram file for further test(s)";
    unlink($nvram_path) or die "Failed to remove $nvram_path: $!";

    # ------------------------------------------------------------------------------
    diag "Test Sys::Virt::Domain::UNDEFINE_NVRAM";
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined domain with nvram configure");

    diag "Creating a new persistent domain";
    lives_ok(sub { $dom->create() }, "created domain");

    $livexml = $dom->get_xml_description();
    $xp = XML::XPath->new($livexml);
    $nvram_path = $xp->getNodeText("/domain/os/nvram");
    diag "nvram_path=($nvram_path)";

    diag "Destroying the persistent domain";
    lives_ok(sub { $dom->destroy() }, "destroyed domain");

    diag "Checking there is still an inactive domain config";
    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "the inactive domain object");
    is($dom->get_id(), -1 , "inactive domain has an ID == -1");

    diag "Checking that nvram file still exists";
    $st = stat($nvram_path);
    ok($st, "File '$nvram_path' still exists as expected");

    diag "Undefining the domain";
    $dom->undefine(Sys::Virt::Domain::UNDEFINE_NVRAM);

    diag "Checking that nvram file is removed";
    $st = stat($nvram_path);
    ok(!$st, "File '$nvram_path' is removed");
}
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", Sys::Virt::Error::ERR_NO_DOMAIN);
