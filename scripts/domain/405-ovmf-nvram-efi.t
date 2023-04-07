#!/usr/bin/perl
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

use Test::More tests => 16;
use Test::Exception;

use Sys::Virt::TCK;
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

sub setup_nvram {

    my $loader_path = shift;
    my $nvram_template = shift;

    # Check that below two files exist:
    #  - /usr/share/OVMF/OVMF_CODE.secboot.fd
    #  - /usr/share/OVMF/OVMF_VARS.secboot.fd
    if (!stat($loader_path) or !stat($nvram_template)) {
        return undef;
    }

    # Use 'q35' machine type and 'efi' firmware
    # Add loader element with attribute secure set to yes
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
my $loader_file_path = '/usr/share/OVMF/OVMF_CODE.secboot.fd';
my $nvram_file_template = '/usr/share/OVMF/OVMF_VARS.secboot.fd';
my $nvram_file_path = '/var/lib/libvirt/qemu/nvram/tck_VARS.fd';

my $xml = setup_nvram($loader_file_path, $nvram_file_template);

SKIP: {
    diag "Require files ($loader_file_path, $nvram_file_template) for testing";
    skip "Please install OVMF and ensure necessary files exist", 5 if !defined($xml);

    # ------------------------------------------------------------------------------
    my $dom;
    diag "Test Sys::Virt::Domain::UNDEFINE_KEEP_NVRAM";
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined domain with nvram configure");

    diag "Checking nvram file doesn't already exist";
    my $st = stat($nvram_file_path);
    ok(!$st, "File '$nvram_file_path' doesn't already exist as expected");

    diag "Creating a new persistent domain";
    lives_ok(sub { $dom->create() }, "created domain");

    diag "Destroying the persistent domain";
    lives_ok(sub { $dom->destroy() }, "destroyed domain");

    diag "Checking there is still an inactive domain config";
    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "the inactive domain object");
    is($dom->get_id(), -1 , "inactive domain has an ID == -1");

    diag "Undefining the domain";
    $dom->undefine(Sys::Virt::Domain::UNDEFINE_KEEP_NVRAM);

    diag "Checking that nvram file still exists";
    $st = stat($nvram_file_path);
    ok($st, "File '$nvram_file_path' still exists as expected");

    diag "Cleaning nvram file for further test(s)";
    unlink($nvram_file_path) or die "Failed to remove $nvram_file_path: $!";

    # ------------------------------------------------------------------------------
    diag "Test Sys::Virt::Domain::UNDEFINE_NVRAM";
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined domain with nvram configure");

    diag "Checking nvram file doesn't already exist";
    $st = stat($nvram_file_path);
    ok(!$st, "File '$nvram_file_path' doesn't already exist as expected");

    diag "Creating a new persistent domain";
    lives_ok(sub { $dom->create() }, "created domain");

    diag "Destroying the persistent domain";
    lives_ok(sub { $dom->destroy() }, "destroyed domain");

    diag "Checking there is still an inactive domain config";
    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "the inactive domain object");
    is($dom->get_id(), -1 , "inactive domain has an ID == -1");

    diag "Checking that nvram file still exists";
    $st = stat($nvram_file_path);
    ok($st, "File '$nvram_file_path' still exists as expected");

    diag "Undefining the domain";
    $dom->undefine(Sys::Virt::Domain::UNDEFINE_NVRAM);

    diag "Checking that nvram file is removed";
    $st = stat($nvram_file_path);
    ok(!$st, "File '$nvram_file_path' is removed");
}
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", Sys::Virt::Error::ERR_NO_DOMAIN);
