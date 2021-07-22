#!/usr/bin/perl
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

use Test::More tests => 4;

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
                               filterref => "clean-traffic",
                               filterparams => {
                                   CTRL_IP_LEARNING => "dhcp",
                                   DHCPSERVER => $networkipaddr
                               })->as_xml();

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

my $guestip = get_ip_from_leases($conn, "default", $mac);
diag "guest ip is $guestip";

my $spoofip = $networkip + 1;
if ($spoofip->addr() eq $guestip) {
    $spoofip++;
}
my $spoofipaddr = $spoofip->addr();
diag "spoof ip is $spoofipaddr";

# check ebtables entry
my $ebtables = (-e '/sbin/ebtables') ? '/sbin/ebtables' : '/usr/sbin/ebtables';
my $ebtable = `$ebtables -L;$ebtables -t nat -L`;
diag $ebtable;
# check if IP address is listed
ok($ebtable =~ "$guestip", "check ebtables entry");

# log into guest
diag "ssh'ing into $guestip";
my $ssh = Net::OpenSSH->new($guestip,
                            user => "root",
                            key_path => $tck->ssh_key_path($tck->scratch_dir()),
                            master_opts => [-o => "UserKnownHostsFile=/dev/null",
                                            -o => "StrictHostKeyChecking=no"]);

# now bring eth0 down, change IP and bring it up again
diag "preparing ip spoof";
my $cmdfile = <<EOF;
echo "DEV=\\\$(ip link | head -3 | tail -1 | awk '{print \\\$2}' | sed -e 's/://')
MASK=\\\$(ip addr show \\\$DEV | grep 'inet ' | awk '{print \\\$2}' | sed -e 's/.*\\///;q')
ip addr show \\\$DEV
kill \\\$(pidof dhclient)
ip addr flush dev \\\$DEV
ip addr add ${spoofipaddr}/\\\$MASK dev \\\$DEV
ip addr show \\\$DEV
sleep 1
ping -c 1 ${networkipaddr}
ip link set \\\$DEV down
ip addr flush dev \\\$DEV
ip addr add ${guestip}/\\\$MASK dev \\\$DEV
ip link set \\\$DEV up
ip addr show \\\$DEV" > /test.sh
EOF
diag $cmdfile;
my ($stdout, $stderr) = $ssh->capture2($cmdfile);
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr) = $ssh->capture2("chmod +x /test.sh");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr) = $ssh->capture2("cat /test.sh");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
diag "running ip spoof";
($stdout, $stderr) = $ssh->capture2("/test.sh");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
diag "checking result";
ok($stdout =~ "100% packet loss", "packet loss expected");

shutdown_vm_gracefully($dom);

$dom->undefine;

exit 0;
