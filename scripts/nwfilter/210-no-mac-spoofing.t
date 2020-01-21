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
use Test::Exception;
use Net::OpenSSH;

use File::Spec::Functions qw(catfile catdir rootdir);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

my $networkip = get_network_ip($conn, "default");
my $networkipaddr = $networkip->addr();
diag "network ip is $networkip, individual ip is $networkipaddr";

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

# ping guest first nic
my $mac =  get_first_macaddress($dom);
diag "mac is $mac";

my $guestip = get_ip_from_leases($conn, "default", $mac);
diag "guest ip is $guestip";

# check ebtables entry
my $ebtables = (-e '/sbin/ebtables') ? '/sbin/ebtables' : '/usr/sbin/ebtables';
my $ebtable = `$ebtables -L;$ebtables -t nat -L`;
diag $ebtable;
# ebtables *might* shorten :00: to :0: so we need to allow for both when searching
$_ = $mac;
s/0([0-9])/0{0,1}$1/g;
ok($ebtable =~ $_, "check ebtables entry");

my $macfalse = "52:54:00:f9:21:22";
my $ping = `ping -c 10 $guestip`;
diag $ping;
ok($ping =~ "10 received", "ping $guestip test");

# log into guest
diag "ssh'ing into $guestip";
my $ssh = Net::OpenSSH->new($guestip,
                            user => "root",
                            key_path => $tck->ssh_key_path($tck->scratch_dir()),
                            master_opts => [-o => "UserKnownHostsFile=/dev/null",
                                            -o => "StrictHostKeyChecking=no"]);

# now bring eth0 down, change MAC and bring it up again
diag "fiddling with mac";
my $cmdfile = <<EOF;
echo "DEV=`ip link | head -3 | tail -1 | awk '{print \\\$2}' | sed -e 's/://'`
ip addr show dev \\\$DEV
ip link set \\\$DEV down
ip link set \\\$DEV address ${macfalse}
ip link set \\\$DEV up
ip addr show dev \\\$DEV
ping -c 10 ${networkipaddr} 2>&1
ip link set \\\$DEV down
ip link set \\\$DEV address ${mac}
ip link set \\\$DEV up
ip addr show dev \\\$DEV" > /test.sh
EOF
diag $cmdfile;
my ($stdout, $stderr)  = $ssh->capture2($cmdfile);
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr)  = $ssh->capture2("chmod +x /test.sh");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr)  = $ssh->capture2("/test.sh > /test.log");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr)  = $ssh->capture2("cat /test.sh");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr)  = $ssh->capture2("cat /test.log");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
ok($stdout =~ /100% packet loss|Network is unreachable/, "packet loss expected");

shutdown_vm_gracefully($dom);

$dom->undefine();

exit 0;
