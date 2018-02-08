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

nwfilter/300-vsitype.t - verify VSI informatio

=head1 DESCRIPTION

The test case validates that the corrrect VSI is set in the adjacent switch

=cut

use strict;
use warnings;

use Test::More;

use Sys::Virt::TCK;
use Sys::Virt::TCK::NetworkHelpers;
use Test::Exception;
use File::Spec::Functions qw(catfile catdir rootdir);

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

if ( ! -e '/usr/sbin/lldptool' ) {
    $tck->cleanup if $tck;
    eval "use Test::More skip_all => \"lldptool is not available\";";
} elsif (!$tck->get_host_network_device()) {
    $tck->cleanup if $tck;
    eval "use Test::More skip_all => \"no host net device configured\";";
} else {
    eval "use Test::More tests => 4";
}

# create first domain and start it
my $xml = $tck->generic_domain(name => "tck", fullos => 1,
                               netmode => "vepa")->as_xml();

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

# check vsi information
diag "Verifying VSI information using lldptool";
my $lldptool = `/usr/sbin/lldptool -t -i eth2 -V vdp mode`;
diag $lldptool;
# check if instance is listed
ok($lldptool =~ "instance", "check instance");
ok($lldptool =~ $mac, "check mac as well");

shutdown_vm_gracefully($dom);

$dom->undefine();

exit 0;
