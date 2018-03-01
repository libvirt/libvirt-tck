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

network/230-no-mac-broadcast.t - verify MAC broadcasts are prevented

=head1 DESCRIPTION

The test case validates that MAC broadcasts are prevented

=cut

use strict;
use warnings;

use Test::More tests => 4;

use Sys::Virt::TCK;
use Sys::Virt::TCK::NetworkHelpers;
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
my $networkipbroadcast = $networkip->broadcast()->addr();
diag "network ip is $networkip, broadcast address is $networkipbroadcast";

# create first domain and start it
my $xml = $tck->generic_domain(name => "tck", fullos => 1,
                               netmode => "network",
                               filterref => "no-mac-broadcast")->as_xml();

my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

diag "Start domain";
$dom->create;
ok($dom->get_id() > 0, "running domain has an ID > 0");

diag "Waiting for guest to finish booting";
my $stats;
my $tries = 0;
do {
    sleep(10);
    $stats  = $dom->interface_stats("vnet0");
    $tries++;
} while ($stats->{"tx_packets"} < 10 && $tries < 10);

# Wait a little bit more to make sure dhcp is started in the guest
sleep(10);

# ping guest first nic
my $mac =  get_first_macaddress($dom);
diag "mac is $mac";

my $guestip = get_ip_from_leases($conn, "default", $mac);
diag "ip is $guestip";

# check ebtables entry
my $ebtables = (-e '/sbin/ebtables') ? '/sbin/ebtables' : '/usr/sbin/ebtables';
my $ebtable = `$ebtables -t nat -L`;
diag $ebtable;
ok($ebtable =~ "-d Broadcast -j DROP", "check ebtables entry for \"-d Broadcast -j DROP\"");

# prepare tcpdump
diag "prepare tcpdump";
system("/usr/sbin/tcpdump -v -i virbr0 -n host $networkipbroadcast and ether host ff:ff:ff:ff:ff:ff 2> /tmp/tcpdump.log &");

# log into guest
diag "ssh'ing into $guestip";
my $ssh = Net::OpenSSH->new($guestip,
                            user => "root",
                            password => $tck->root_password(),
                            master_opts =>  [-o => "StrictHostKeyChecking=no"]);

# now generate a mac broadcast paket 
diag "generate mac broadcast";
my $cmdfile = <<EOF;
echo 'ping -c 1 $networkipbroadcast -b' > /test.sh
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
($stdout, $stderr) = $ssh->capture2("/test.sh > /test.log");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";
($stdout, $stderr) = $ssh->capture2("cat /test.log");
diag $stdout;
diag $stderr;
diag "Exit Code: $?";

# now stop tcpdump and verify result
diag "stopping tcpdump";
system("kill -15 `/sbin/pidof tcpdump`");
my $tcpdumplog = `cat /tmp/tcpdump.log`;
diag($tcpdumplog);
ok($tcpdumplog =~ "0 packets captured", "tcpdump expected to capture no packets");

shutdown_vm_gracefully($dom);

$dom->undefine;

exit 0;
