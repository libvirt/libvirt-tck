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

use Test::More tests => 4;

use Sys::Virt::TCK;
use Test::Exception;

use File::Spec::Functions qw(catfile catdir rootdir);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

# create first domain and start it
my $xml = $tck->generic_domain(name => "tck", fullos => 1,
                               netmode => "network",
                               filterref => "clean-traffic")->as_xml();

my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

diag "Start domain";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");

diag "Waiting for guest to finish booting";
my $iface = get_first_interface_target_dev($dom);
my $stats;
my $tries = 0;
do {
    sleep(10);
    $stats  = $dom->interface_stats($iface);
    $tries++;
} while ($stats->{"tx_packets"} < 10 && $tries < 10);

# Wait a little bit more to make sure dhcp is started in the guest
sleep(10);

my $mac = get_first_macaddress($dom);
diag "mac is $mac";

my $guestip = get_ip_from_leases($conn, "default", $mac);
diag "ip is $guestip";

# check ebtables entry
my $ebtables = (-e '/sbin/ebtables') ? '/sbin/ebtables' : '/usr/sbin/ebtables';
my $ebtable = `$ebtables -L;$ebtables -t nat -L`;
diag $ebtable;
# ebtables *might* shorten :00: to :0: so we need to allow for both when searching
$_ = $mac;
s/0([0-9])/0{0,1}$1/g;
ok($ebtable =~ $_, "check ebtables entry");

# ping guest1
my $ping = `ping -c 10 $guestip`;
diag $ping;
ok($ping =~ "10 received", "ping $guestip test");

shutdown_vm_gracefully($dom);

$dom->undefine();

exit 0;
