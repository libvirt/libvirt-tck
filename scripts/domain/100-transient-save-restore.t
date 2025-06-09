#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2009-2010 Red Hat, Inc.
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

domain/100-transient-save-restore.t - Transient domain save/restore

=head1 DESCRIPTION

The test case validates that it is possible to save and restore
transient domains to/from a file.

=cut

use strict;
use warnings;

use Test::More tests => 6;

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

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

unlink "tck.img" if -f "tck.img";
eval { $dom->save("tck.img"); };
SKIP: {
    skip "save/restore not implemented", 4 if $@ && err_not_implemented($@);
    ok(!$@, "domain saved");
    die $@ if $@;

    diag "Checking that transient domain has gone away";
    ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	     Sys::Virt::Error::ERR_NO_DOMAIN);

    diag "Attempting to restore the guest";
    lives_ok { $conn->restore_domain("tck.img") } "domain has been restored";

    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "restored domain is still there", "tck");
}

diag "Destroying the transient domain";
$dom->destroy;

diag "Checking that transient domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
	 Sys::Virt::Error::ERR_NO_DOMAIN);

# end
