# -*- perl -*-
#
# Copyright (C) 2010 IBM Corp.
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

nwfilter/300-vsitype.t - verify VSI informatio

=head1 DESCRIPTION

The test case validates that the corrrect VSI is set in the adjacent switch

=cut

use strict;
use warnings;

use Test::More tests => 3;

use Sys::Virt::TCK;
use Sys::Virt::TCK::NetworkHelpers;
use Test::Exception;
use Net::SSH::Perl;
use File::Spec::Functions qw(catfile catdir rootdir);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

SKIP: {
     skip "lldptool not present", 3  unless -e "/usr/sbin/lldptool";

# creating domain
     my $dom1;
     my $dom_name ="tck8021Qbgtest";

# speficy mode="vepa" for a direct interface
     $dom1 = prepare_test_disk_and_vm($tck, $conn, $dom_name, "vepa");
     $dom1->create();

     ok($dom1->get_id() > 0, "running domain has an ID > 0");
     my $xml = $dom1->get_xml_description;
     diag $xml;
     my $mac1 =  get_first_macaddress($dom1);
     diag "mac is $mac1";

     sleep(30);

# check vsi information
     diag "Verifying VSI information using lldptool";
     my $lldptool = `/usr/sbin/lldptool -t -i eth2 -V vdp mode`;
     diag $lldptool;
# check if instance is listed
     ok($lldptool =~ "instance", "check instance");
     ok($lldptool =~ $mac1, "check mac as well");

     shutdown_vm_gracefully($dom1);
     exit 0;

};
