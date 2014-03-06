# -*- perl -*-
#
# Copyright (C) 203 Red Hat, Inc.
# Copyright (C) 203 Osier Yang <jyang@redhat.com>
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

domain/051-start-daemon.t - hooks testing for daemon

=head1 DESCRIPTION

The test case validates that the hook script is invoked while
start, stop, or reload daemon.

=cut

use strict;
use warnings;

use Slurp;

use Sys::Virt::TCK;
use Sys::Virt::TCK::Hooks;

use Test::More tests => 12;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

SKIP: {
    my $uri = $conn->get_uri();

    skip 12, "NOT using QEMU/LXC driver" unless
        $uri eq "qemu:///system" or $uri eq "lxc:///";

    my $hook = Sys::Virt::TCK::Hooks->new(type => 'daemon',
                                          conf_dir => '/etc/libvirt/hooks',
                                          log_name => '/tmp/daemon.log');

    $hook->libvirtd_status();
    BAIL_OUT "libvirtd is not running, Exit..."
        if ($hook->{libvirtd_status} eq 'stopped');

    eval { $hook->prepare(); };
    BAIL_OUT "failed to setup hooks testing ENV: $@" if $@;

    diag "reload libvirtd for hooks scripts taking effect";
    $hook->action('reload');
    $hook->service_libvirtd();
    unlink $hook->{log_name} unless -f $hook->{log_name};

    # stop libvirtd
    $hook->action('stop');
    $hook->expect_log();

    diag "$hook->{action} libvirtd";
    $hook->service_libvirtd();

    my $hook_data = slurp($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    sleep 3;
    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    my $actual_log_data = slurp($hook->{log_name});
    diag "actual log: $hook->{log_name} '$actual_log_data'";

    diag "expected log:\n$hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log(), "$hook->{name} is invoked correctly while $hook->{action} libvirtd");

    diag "check if libvirtd is stopped";
    ok(`service libvirtd status` =~ /stopped|unused|inactive/, "libvirtd is stopped");

    # start libvirtd
    $hook->action('start');
    $hook->expect_log();

    diag "$hook->{action} libvirtd";
    $hook->service_libvirtd();

    $hook_data = slurp($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    sleep 3;
    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    $actual_log_data = slurp($hook->{log_name});
    diag "actual log: $hook->{log_name} '$actual_log_data'";

    diag "expected log: \n$hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log(), "$hook->{name} is invoked correctly while $hook->{action} libvirtd");

    diag "check if libvirtd is still running";
    ok(`service libvirtd status` =~ /running/, "libvirtd is running");

    # restart libvirtd
    $hook->action('restart');
    $hook->expect_log();

    diag "$hook->{action} libvirtd";
    $hook->service_libvirtd();

    $hook_data = slurp($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    sleep 3;
    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    $actual_log_data = slurp($hook->{log_name});
    diag "actual log: $hook->{log_name} '$actual_log_data'";

    diag "expected log: \n$hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log(), "$hook->{name} is invoked correctly while $hook->{action} libvirtd");

    diag "check if libvirtd is still running";
    ok(`service libvirtd status` =~ /running/, "libvirtd is running");

    # reload libvirtd
    $hook->action('reload');
    $hook->expect_log();

    diag "$hook->{action} libvirtd";
    $hook->service_libvirtd();

    $hook_data = slurp($hook->{name});
    diag "hook script: $hook->{name} '$hook_data'";

    sleep 3;
    diag "check if $hook->{name} is invoked";
    ok(-f "$hook->{name}", "$hook->{name} is invoked");

    $actual_log_data = slurp($hook->{log_name});
    diag "actual log: $hook->{log_name} '$actual_log_data'";

    diag "expected log: \n$hook->{expect_log}";

    diag "check if the actual log is same with expected log";
    ok($hook->compare_log(), "$hook->{name} is invoked correctly while $hook->{action} libvirtd");

    diag "check if libvirtd is still running";
    ok(`service libvirtd status` =~ /running/, "libvirtd is running");

    $hook->cleanup();
};

