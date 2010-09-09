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

use Test::More tests => 3;

use Sys::Virt::TCK;
use Sys::Virt::TCK::NetworkHelpers;
use Test::Exception;
use Net::SSH::Perl;
use File::Spec::Functions qw(catfile catdir rootdir);

my $spoofid = "192.168.122.183";

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

# creating domain
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
# check if mac address is listed
ok($ebtable1 =~ "$guestip1", "check ebtables entry");

# prepare tcpdump
diag "prepare tcpdump";
system("/usr/sbin/tcpdump -v -i virbr0 not ip  > /tmp/tcpdump.log &");

# log into guest
my $ssh = Net::SSH::Perl->new($guestip1);
$ssh->login("root", "foobar");

# now generate a arp spoofing packets 
diag "generate arpspoof";
my $cmdfile = "echo '" . 
    "/usr/bin/yum -y install dsniff\n".
    "/usr/sbin/arpspoof ${spoofid} &\n".
    "/bin/sleep 10\n".
    "kill -15 `/sbin/pidof arpspoof`\n".
    "' > /test.sh";
diag "content of cmdfile:";
diag $cmdfile;
diag "creating cmdfile";
my ($stdout, $stderr, $exit)  = $ssh->cmd($cmdfile);
diag $stdout;
diag $stderr;
diag $exit;
($stdout, $stderr, $exit)  = $ssh->cmd("chmod +x /test.sh");
diag $stdout;
diag $stderr;
diag $exit;
diag "excuting cmdfile";
($stdout, $stderr, $exit)  = $ssh->cmd("/test.sh > /test.log");
diag $stdout;
diag $stderr;
diag $exit;
($stdout, $stderr, $exit)  = $ssh->cmd("echo test.log\ncat /test.log");
diag $stdout;
diag $stderr;
diag $exit;

# now stop tcpdump and verify result
diag "stopping tcpdump";
system("kill -15 `/sbin/pidof tcpdump`");
diag "tcpdump.log:";
my $tcpdumplog = `cat /tmp/tcpdump.log`;
diag($tcpdumplog);
ok($tcpdumplog !~ "${spoofid} is-at", "tcpdump expected to capture no arp reply packets");

shutdown_vm_gracefully($dom1);

exit 0;
