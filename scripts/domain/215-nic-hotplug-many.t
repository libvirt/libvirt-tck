# -*- perl -*-
#
# Copyright (C) 2009 Red Hat, Inc.
# Copyright (C) 2009 Daniel P. Berrange
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

domain/200-disk-hotplug.t - verify hot plug & unplug of a disk

=head1 DESCRIPTION

The test case validates that it is possible to hotplug a disk
to a running domain, and then unplug it again.

=cut

use strict;
use warnings;

use Test::More tests => 21;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

my $mac1 = "02:11:22:33:44:55";
my $mac2 = "02:12:22:33:44:55";
my $mac3 = "02:13:22:33:44:55";
my $model = "virtio";

my $netxml1 = <<EOF;
<interface type='user'>
  <mac address='$mac1'/>
  <model type='$model'/>
</interface>
EOF
my $netxml2 = <<EOF;
<interface type='user'>
  <mac address='$mac2'/>
  <model type='$model'/>
</interface>
EOF
my $netxml3 = <<EOF;
<interface type='user'>
  <mac address='$mac3'/>
  <model type='$model'/>
</interface>
EOF

my $initialxml = $dom->get_xml_description;

diag "Attaching the new interface $mac1";
lives_ok(sub { $dom->attach_device($netxml1); }, "interface has been attached");
diag "Attaching the new interface $mac2";
lives_ok(sub { $dom->attach_device($netxml2); }, "interface has been attached");
diag "Attaching the new interface $mac3";
lives_ok(sub { $dom->attach_device($netxml3); }, "interface has been attached");

my $newxml = $dom->get_xml_description;

ok($newxml =~ m|$mac1|, "new XML has 1st NIC present");
ok($newxml =~ m|$mac2|, "new XML has 2nd NIC present");
ok($newxml =~ m|$mac3|, "new XML has 3rd NIC present");

diag "Detaching the 2nd interface $mac2";
lives_ok { $dom->detach_device($netxml2); } "interface has been detached";

$newxml = $dom->get_xml_description;

ok($newxml =~ m|$mac1|, "new XML has 1st NIC present");
ok($newxml !~ m|$mac2|, "new XML has NOT got 2nd NIC present");
ok($newxml =~ m|$mac3|, "new XML has 3rd NIC present");

ok_error(sub { $dom->detach_device($netxml2); }, "cannot detach same interface twice");

diag "Detaching the 1st interface $mac1";
lives_ok(sub { $dom->detach_device($netxml1); }, "interface has been detached");

$newxml = $dom->get_xml_description;

ok($newxml !~ m|$mac1|, "new XML has NOT got 1st NIC present");
ok($newxml !~ m|$mac2|, "new XML has NOT got 2nd NIC present");
ok($newxml =~ m|$mac3|, "new XML has 3rd NIC present");

diag "Detaching the 3rd interface $mac3";
lives_ok(sub { $dom->detach_device($netxml3); }, "interface has been detached");

$newxml = $dom->get_xml_description;

ok($newxml !~ m|$mac1|, "new XML has NOT got 1st NIC present");
ok($newxml !~ m|$mac2|, "new XML has NOT got 2nd NIC present");
ok($newxml !~ m|$mac3|, "new XML has NOT got 3rd NIC present");


my $finalxml = $dom->get_xml_description;

is($initialxml, $finalxml, "final XML has removed the interfaces")
