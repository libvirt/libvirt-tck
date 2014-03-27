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

network/100-ping-still-working.t - verify machines can be pinged from host

=head1 DESCRIPTION

The test case validates that it is possible to ping a guest machine from
the host.

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

# create first domain and start it
diag "Trying domain lookup by name";
my $dom1;
my $dom_name ="tcknwtest";

$dom1 = prepare_test_disk_and_vm($tck, $conn, $dom_name);
$dom1->create();

my $xml = $dom1->get_xml_description;
diag $xml;
ok($dom1->get_id() > 0, "running domain has an ID > 0");
#my $mac1 = get_macaddress($xml);
#diag $mac1;
#my $result = xpath($dom1, "/domain/devices/interface/mac/\@address");
#my @macaddrs = map { $_->getNodeValue} $result->get_nodelist;
# we want the first mac
#my $mac1 =  $macaddrs[0];
my $mac1 =  get_first_macaddress($dom1);
diag "mac is $mac1";

sleep(30);
my $guestip1 = get_ip_from_leases($mac1);
diag "ip is $guestip1";

# check ebtables entry
my $ebtable1 = `/sbin/ebtables -L;/sbin/ebtables -t nat -L`;
diag $ebtable1;
# fixme to include mac adress
ok($ebtable1 =~ "vnet0", "check ebtables entry");

# ping guest1
my $ping1 = `ping -c 10 $guestip1`;
diag $ping1;
ok($ping1 =~ "10 received", "ping $guestip1 test");

shutdown_vm_gracefully($dom1);

exit 0;
