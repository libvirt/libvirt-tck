#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat, Inc.
# Copyright (C) 2009-2010 Daniel P. Berrange
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

domain/103-blockdev-save-restore.t: Save/restore with a block device

=head1 DESCRIPTION

The test case validates that it is possible to save and restore
transient domains to/from a block device, instead of a plain file

=cut

use strict;
use warnings;

use Test::More tests => 9;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink "tck.img" if -f "tck.img";
}


my $xml = $tck->generic_domain(name => "tck")->as_xml;

my $dev = $tck->get_host_block_device();

my $dom;
diag "Creating a new transient domain";
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

SKIP: {
    skip "no block device available", 7 unless $dev;

    ok(-b $dev, "$dev is a block device");

    diag "Clearing any existing data in block device";
    open DEV, ">$dev" or die "cannot open $dev: $1";
    my $zeros = "\0"x1024;
    for (my $i = 0; $i < 1024 * 10 ; $i++) {
	print DEV $zeros;
    }
    close DEV or die "cannot save $dev: $!";

    diag "Saving the guest";
    eval { $dom->save($dev); };
    skip "save/restore not implemented", 6 if $@ && err_not_implemented($@);

    ok(!$@, "domain saved");
    die $@ if $@;

    diag "Verifying it is still a block device, not a file";
    ok(-b $dev, "$dev is a block device");

    diag "Checking that transient domain has gone away";
    ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

    diag "Attempting to restore the guest";
    lives_ok { $conn->restore_domain($dev) } "domain has been restored";

    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "restored domain is still there", "tck");

    ok(-b $dev, "$dev is a block device");
}
diag "Destroying the transient domain";
$dom->destroy;

diag "Checking that transient domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

# end
