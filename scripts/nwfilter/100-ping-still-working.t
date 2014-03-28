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
my $xml = $tck->generic_domain(name => "tck", fullos => 1,
			       netmode => "network")->as_xml();

my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

diag "Start domain";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");

diag "Waiting 30 seconds for guest to finish booting";
sleep(30);

my $mac = get_first_macaddress($dom);
diag "mac is $mac";

my $guestip = get_ip_from_leases($mac);
diag "ip is $guestip";

# check ebtables entry
my $ebtables = (-e '/sbin/ebtables') ? '/sbin/ebtables' : '/usr/sbin/ebtables';
my $ebtable = `$ebtables -L;$ebtables -t nat -L`;
diag $ebtable;
# ebtables shortens :00: to :0: so we need to do that too
$_ = $mac;
s/00/0/g;
ok($ebtable =~ $_, "check ebtables entry");

# ping guest1
my $ping = `ping -c 10 $guestip`;
diag $ping;
ok($ping =~ "10 received", "ping $guestip test");

shutdown_vm_gracefully($dom);

$dom->undefine();

exit 0;
