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

network/240-no-arp-spoofing.t - verify ARP spoofing is prevented

=head1 DESCRIPTION

The test case validates that ARP spoofing is prevented

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

# prepare tcpdump
diag "prepare tcpdump";
system("/usr/sbin/tcpdump -v -i virbr0 not ip  > /tmp/tcpdump.log &");

# log into guest
diag "ssh'ing into $guestip";
my $ssh = Net::OpenSSH->new($guestip,
                            user => "root",
                            key_path => $tck->ssh_key_path($tck->scratch_dir()),
                            master_opts => [-o => "UserKnownHostsFile=/dev/null",
                                            -o => "StrictHostKeyChecking=no"]);

# now generate a arp spoofing packets 
diag "generate arpspoof script";
my $cmdfile = <<EOF;
echo "arpspoof ${spoofipaddr} &
sleep 10
kill -15 \\\$(pidof arpspoof)" > /test.sh
EOF

diag "content of cmdfile:";
diag $cmdfile;
diag "creating cmdfile";
my ($stdout, $stderr) = $ssh->capture2($cmdfile);
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr) = $ssh->capture2("chmod +x /test.sh");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
diag "excuting cmdfile";
($stdout, $stderr) = $ssh->capture2("/test.sh > /test.log");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr) = $ssh->capture2("echo test.log\ncat /test.log");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";

# now stop tcpdump and verify result
diag "stopping tcpdump";
system("kill -15 `pidof tcpdump`");
diag "tcpdump.log:";
my $tcpdumplog = `cat /tmp/tcpdump.log`;
diag($tcpdumplog);
ok($tcpdumplog !~ "${spoofipaddr} is-at", "tcpdump expected to capture no arp reply packets");

shutdown_vm_gracefully($dom);

$dom->undefine;

exit 0;
