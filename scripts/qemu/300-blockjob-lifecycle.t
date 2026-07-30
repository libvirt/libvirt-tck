#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2011-2012 Red Hat, Inc.
# Copyright (C) 2011 Xiaoqiang Hu <xhu redhat com>
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

qemu/300-blockjob-lifecycle.t

=head1 DESCRIPTION

The test case validates that it is possible to block pull, set block job
speed, get block job info and abort block job for domain using qcow2 img
with qcow2 backing img

$dom->block_pull()
$dom->set_block_job_speed()
$dom->abort_block_job()
$dom->get_block_job_info()
Sys::Virt::Domain::BLOCK_JOB_INFO_BANDWIDTH_BYTES


=cut

use strict;
use warnings;

use Test::More tests => 20;

use Sys::Virt::TCK;
use Test::Exception;
use File::Spec::Functions qw(catfile);
use File::stat;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
}

SKIP:{
    skip "Only relevant to QEMU driver", 16 unless $conn->get_type() eq "QEMU";
    my $xml = $tck->generic_pool("dir")
        ->mode("0755")->as_xml;

    diag "Defining transient storage pool $xml";
    my $pool;

    ok_pool(sub { $pool = $conn->define_storage_pool($xml) }, "define transient storage pool");
    lives_ok(sub { $pool->build(0) }, "built storage pool");
    lives_ok(sub { $pool->create }, "started storage pool");

    my $volbackxml = $tck->generic_volume("tck-back", "qcow2", 1024*1024*50)->allocation(0)->as_xml;

    my ($volback, $pathback);
    diag "back $volbackxml";
    ok_volume(sub { $volback = $pool->create_volume($volbackxml) }, "create qcow2 backing file volume");

    my $st;
    $pathback = xpath($volback, "string(/volume/target/path)");
    $st = stat($pathback);

    ok($st, "path $pathback exists");

    ok($st->size < 1024*1024, "size is < 1M");

    diag "change $pathback to a filled qcow2 image";
    system("dd if=/dev/urandom of=/tmp/tck-tmp bs=52428800 count=1");
    system("qemu-img convert /tmp/tck-tmp -O qcow2 $pathback");
    system("rm -f /tmp/tck-tmp");

    my $volmainxml = $tck->generic_volume("tck-main", "qcow2", 1024*1024*50)
        ->backing_file($pathback)
        ->backing_format("qcow2")
        ->allocation(0)->as_xml;

    my ($volmain, $pathmain);
    diag "main $volmainxml";
    ok_volume(sub { $volmain = $pool->create_volume($volmainxml) }, "create qcow2 backing file volume");

    $pathmain = xpath($volmain, "string(/volume/target/path)");
    $st = stat($pathmain);

    ok($st, "path $pathmain exists");

    ok($st->size < 1024*1024, "size is < 1M");

    # define the guest with a qcow2 image including
    # a backing store.
    $xml = $tck->generic_domain(name => "tck")
        ->disk(format => { name => "qemu", type => "qcow2" },
               type => "file",
               src => $pathmain,
               dst => "vdb")
        ->as_xml;

    diag "Defining an inactive domain config $xml";
    my $dom;
    ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain config");

    diag "Starting inactive domain config";
    $dom->create;
    ok($dom->get_id() > 0, "running domain has an ID > 0");

    # start to block pull and bandwidth is 1MB/S
    my ($bandwidth, $flags, $jobinfo, $timeout);
    # 1MB/S
    $bandwidth = 1;
    $flags=0;
    eval { $dom->block_pull($pathmain, $bandwidth, $flags); };
    SKIP: {
        skip "block_stream not implemented", 5 if $@ && $@->code() ==
	    Sys::Virt::Error::ERR_OPERATION_INVALID;

        # $jobinfo is a hash reference summarising the execution state of the block job
        # and it has four keys:cur, end, bandwidth, type
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{bandwidth} == $bandwidth, "start to block pull and block job bandwidth is $bandwidth"."MB/S");

        $dom->abort_block_job($pathmain, $flags);
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{type} == 0, "abort block job");

        $dom->block_pull($pathmain, $bandwidth, $flags);
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{bandwidth} == $bandwidth, "continue to block pull and block job bandwidth is $bandwidth"."MB/S");

        # set block job bandwidth to 2097152B/S and with flag BLOCK_PULL_BANDWIDTH_BYTES
        $dom->abort_block_job($pathmain, $flags);
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{type} == 0, "abort block job");

        $flags = Sys::Virt::Domain::BLOCK_PULL_BANDWIDTH_BYTES;
        $bandwidth = 2 * 1024 * 1024;
        $dom->block_pull($pathmain,$bandwidth,$flags);
        $flags = 0;
        $jobinfo = $dom->get_block_job_info($pathmain,$flags);
        ok($jobinfo->{bandwidth} == $bandwidth/(1024*1024), "start to block pull with flag BLOCK_PULL_BANDWIDTH_BYTES and blcok job bandwidth is $bandwidth"."B/S");

        # set block job bandwidth to 2MB/S
        $bandwidth = 2;
        $dom->set_block_job_speed($pathmain, $bandwidth, $flags);
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{bandwidth} == $bandwidth, "block job bandwidth is set to $bandwidth"."MB/S");

        # set block job bandwidth to 2097152B/S and with flag BLOCK_JOB_SPEED_BANDWIDTH_BYTES
        $bandwidth = 2 * 1024 * 1024;
        $flags = Sys::Virt::Domain::BLOCK_JOB_SPEED_BANDWIDTH_BYTES;
        $dom->set_block_job_speed($pathmain, $bandwidth, $flags);
        $flags = 0;
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{bandwidth} == $bandwidth/(1024*1024), "block job bandwidth with flag BLOCK_JOB_SPEED_BANDWIDTH_BYTES is set to $bandwidth"."B/S");

        # set block job bandwidth to 2MB/S and with BLOCK_JOB_INFO_BANDWIDTH_BYTES flag
        $bandwidth = 2;
        $flags = 0;
        my $bandwidthInBytes = $bandwidth * 1024 * 1024;
        $dom->set_block_job_speed($pathmain, $bandwidth, $flags);
        $flags = Sys::Virt::Domain::BLOCK_JOB_INFO_BANDWIDTH_BYTES;
        $jobinfo = $dom->get_block_job_info($pathmain, $flags);
        ok($jobinfo->{bandwidth} == $bandwidth * 1024 * 1024, "block job bandwidth with flag BLOCK_JOB_INFO_BANDWIDTH_BYTES is set to $bandwidthInBytes"."B/S");

        # wait for the end of block pull and timeout is 120s
        $timeout = 120;
        while($jobinfo->{cur} < $jobinfo->{end} && $jobinfo->{type} == 1 && $timeout > 0) {
            sleep(1);
            $jobinfo = $dom->get_block_job_info($pathmain, $flags);
            $timeout--;
        }

        diag "block pull is not finished in 120S" if $jobinfo->{type} == 1 && $timeout == 0;
        ok($jobinfo->{type} == 0, "block pull is finished");

    }
}
# end
