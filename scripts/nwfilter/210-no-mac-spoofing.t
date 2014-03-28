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

use Test::More tests => 5;

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

# ping guest first nic
my $mac =  get_first_macaddress($dom);
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

my $gateway = "192.168.122.1";
my $macfalse = "52:54:00:f9:21:22";
my $ping = `ping -c 10 $guestip`;
diag $ping;
ok($ping =~ "10 received", "ping $guestip test");

# log into guest
my $ssh = Net::SSH::Perl->new($guestip);
diag "ssh'ing into $guestip";
$ssh->login("root", $tck->root_password());

# now bring eth0 down, change MAC and bring it up again
diag "fiddling with mac";
my $cmdfile = <<EOF;
echo "DEV=`ip link | head -3 | tail -1 | awk '{print \\\$2}' | sed -e 's/://'`
/sbin/ip addr show dev \\\$DEV
/sbin/ip link set \\\$DEV down
/sbin/ip link set \\\$DEV address ${macfalse}
/sbin/ip link set \\\$DEV up
/sbin/ip addr show dev \\\$DEV
/bin/ping -c 10 ${gateway}
/sbin/ip link set \\\$DEV down
/sbin/ip link set \\\$DEV address ${mac}
/sbin/ip link set \\\$DEV up
/sbin/ip addr show dev \\\$DEV" > /test.sh
EOF
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
($stdout, $stderr, $exit)  = $ssh->cmd("cat /test.sh");
diag $stdout;
diag $stderr;
diag $exit;
($stdout, $stderr, $exit)  = $ssh->cmd("cat /test.log");
diag $stdout;
diag $stderr;
diag $exit;
ok($stdout =~ "100% packet loss", "packet loss expected");

shutdown_vm_gracefully($dom);

$dom->undefine();

exit 0;
