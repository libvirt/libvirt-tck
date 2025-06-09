#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2012 Red Hat, Inc.
# Copyright (C) 2012 Xiaoqiang Hu <xhu@redhat.com>
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

networks/110-interface-lifecycle.t: test transaction for changing the
configuration of one or more network interfaces

=head1 DESCRIPTION

The test case validates the transaction for changing the configuration
of one or more network interfaces

=cut

use strict;
use warnings;

use Test::More tests => 2;

use Sys::Virt::TCK;
use Test::Exception;

my $network_script_dir = "/etc/sysconfig/network-scripts";
my $test_interface_name = "ifcfg-interface-tck-test";
my $test_interface_cfg = $network_script_dir."/".$test_interface_name;
my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink $test_interface_cfg if -f $test_interface_cfg;
}

my $ret;

unlink $test_interface_cfg if -f $test_interface_cfg;

eval { $conn->interface_change_begin(); };
SKIP: {
    skip "$network_script_dir not available on this platform", 2 unless -d $network_script_dir;
    skip "interface_change_begin/commit/rollback not implemented", 2 if $@ && err_not_implemented($@);

    $ret = system("cat <<EOF > $test_interface_cfg
DEVICE=\"interface-tck-test\"
BOOTPROTO=\"none\"
ONBOOT=\"no\"
EOF
");

    $conn->interface_change_rollback();
    ok(! -e $test_interface_cfg, "interface rollback");

    unlink $test_interface_cfg if -f $test_interface_cfg;

    $conn->interface_change_begin();

    $ret = system("cat <<EOF > $test_interface_cfg
DEVICE=\"interface-tck-test\"
BOOTPROTO=\"none\"
ONBOOT=\"no\"
EOF
");

    $conn->interface_change_commit();
    ok(-e $test_interface_cfg, "interface commit");
}

# end
