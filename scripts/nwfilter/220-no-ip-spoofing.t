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

network/220-no-ip-spoofing.t - verify IP spoofing is prevented

=head1 DESCRIPTION

The test case validates that IP spoofing is prevented

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

# looking up domain
my $dom1;
my $disk_name ="f12nwtest";

$dom1 = prepare_test_disk_and_vm($tck, $conn, "${disk_name}");
$dom1->create();

ok($dom1->get_id() > 0, "running domain has an ID > 0");
my $xml = $dom1->get_xml_description;
diag $xml;
my $mac1 =  get_first_macaddress($dom1);
diag "mac is $mac1";

sleep(30);
my $guestip1 = get_ip_from_leases($mac1);
diag "ip is $guestip1";

# check ebtables entry
my $ebtable1 = `/sbin/ebtables -L;/sbin/ebtables -t nat -L`;
diag $ebtable1;
# check if IP address is listed
ok($ebtable1 =~ "$guestip1", "check ebtables entry");

# log into guest
my $ssh = Net::SSH::Perl->new($guestip1);
$ssh->login("root", "foobar");

# now bring eth0 down, change IP and bring it up again
diag "preparing ip spoof";
my $cmdfile = "echo '" . 
    "/bin/sleep 1\n".
    "/sbin/ifconfig eth0\n".
    "/sbin/ifconfig eth0 down\n".
    "/sbin/ifconfig eth0 192.168.122.183 netmask 255.255.255.0 up\n".
    "/sbin/ifconfig eth0\n".
    "/bin/sleep 1\n".
    "/bin/ping -c 1 192.168.122.1\n".
    "/sbin/ifconfig eth0 down\n".
    "/sbin/ifconfig eth0 ${guestip1} netmask 255.255.255.0 up\n".
    "/sbin/ifconfig eth0 \n".
    "/bin/sleep 1\n".
    "' > /test.sh";
diag $cmdfile;
my ($stdout, $stderr, $exit)  = $ssh->cmd($cmdfile);
diag $stdout;
diag $stderr;
diag $exit;
($stdout, $stderr, $exit)  = $ssh->cmd("chmod +x /test.sh");
diag $stdout;
diag $stderr;
diag $exit;
diag "running ip spoof";
($stdout, $stderr, $exit)  = $ssh->cmd("/test.sh");
diag $stdout;
diag $stderr;
diag $exit;
diag "checking result";
ok($stdout =~ "100% packet loss", "packet loss expected");

shutdown_vm_gracefully($dom1);

exit 0;
