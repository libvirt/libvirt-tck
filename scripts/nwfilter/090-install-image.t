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

network/000-install-image.t - install network test image

=head1 DESCRIPTION

The test case creates and install a 2GB fedora virtual 
disk via kickstart file from the network.

=cut

use strict;
use warnings;

use Test::More tests => 1;

use Sys::Virt::TCK;
use Sys::Virt::TCK::NetworkHelpers;


my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

use File::Spec::Functions qw(catfile catdir rootdir);

# variables which may need to be adapted
my $dom_name ="tckf12nwtest";

my $testdom = prepare_test_disk_and_vm($tck, $conn, $dom_name);
$testdom->create();
ok($testdom->get_id() > 0, "running domain has an ID > 0");
sleep(20);

shutdown_vm_gracefully($testdom);

exit 0;


