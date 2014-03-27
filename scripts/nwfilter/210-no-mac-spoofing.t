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

network/210-no-mac-spoofing.t - verify MAC spoofing is prevented

=head1 DESCRIPTION

The test case validates that MAC spoofing is prevented

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

my $dom_name ="tcknwtest";

my $dom1;
$dom1 = prepare_test_disk_and_vm($tck, $conn, $dom_name);
$dom1->create();
ok($dom1->get_id() > 0, "running domain has an ID > 0");
my $xml = $dom1->get_xml_description;
diag $xml;


# ping guest1 first nic
my $mac1 =  get_first_macaddress($dom1);
diag "mac is $mac1";

sleep(30);
my $guestip1 = get_ip_from_leases($mac1);
diag "ip is $guestip1";

# check ebtables entry
my $ebtable1 = `/sbin/ebtables -L;/sbin/ebtables -t nat -L`;
diag $ebtable1;
# ebtables shortens :00: to :0: so we need to do that too
$_ = $mac1;
s/00/0/g; 
ok($ebtable1 =~ $_, "check ebtables entry");

my $gateway = "192.168.122.1";
my $macfalse = "52:54:00:f9:21:22";
my $ping1 = `ping -c 10 $guestip1`;
diag $ping1;
ok($ping1 =~ "10 received", "ping $guestip1 test");

# log into guest
my $ssh = Net::SSH::Perl->new($guestip1);
$ssh->login("root", "foobar");

# now bring eth0 down, change MAC and bring it up again
diag "fiddling with mac";
my $cmdfile = "echo '" . 
    "/sbin/ifconfig eth0\n".
    "/sbin/ifconfig eth0 down\n".
    "/sbin/ifconfig eth0 hw ether ${macfalse}\n".
    "/sbin/ifconfig eth0 up\n".
    "/sbin/ifconfig eth0\n".
    "ping -c 10 ${gateway}\n".
    "/sbin/ifconfig eth0 down\n".
    "/sbin/ifconfig eth0 hw ether ${mac1}\n".
    "/sbin/ifconfig eth0 up\n".
    "/sbin/ifconfig eth0\n".
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
($stdout, $stderr, $exit)  = $ssh->cmd("/test.sh > /test.log");
diag $stdout;
diag $stderr;
diag $exit;
($stdout, $stderr, $exit)  = $ssh->cmd("cat /test.log");
diag $stdout;
diag $stderr;
diag $exit;
ok($stdout =~ "100% packet loss", "packet loss expected");

shutdown_vm_gracefully($dom1);

exit 0;
