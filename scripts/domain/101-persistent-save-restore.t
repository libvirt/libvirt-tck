# -*- perl -*-
#
# Copyright (C) 2009 Red Hat
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

domain/101-persistent-save-restore.t - Persistent domain save/restore

=head1 DESCRIPTION

The test case validates that it is possible to save and restore
persistent domains to/from a file.

=cut

use strict;
use warnings;

use Test::More tests => 11;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink "tck.img" if -f "tck.img";
}


my $xml = $tck->generic_domain("tck")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

unlink "tck.img" if -f "tck.img";
ok_error(sub { $dom->save("tck.img") }, "canot save a inactive domain");

diag "Starting inactive domain";
$dom->create;

ok($dom->get_id > 0, "running domain with ID > 0");

eval { $dom->save("tck.img"); };
SKIP: {
    skip "save/restore not implemented", 7 if $@ && err_not_implemented($@);
    ok(!$@, "domain saved");

    diag "Checking that persistent domain is stopped";
    ok_domain(sub { $conn->get_domain_by_name("tck") }, "persistent domain is still there", "tck");
    is($dom->get_id, -1, "running domain with ID == -1");

    diag "Restoring domain from file";
    lives_ok(sub { $conn->restore_domain("tck.img") }, "domain has been restored");

    ok_domain(sub { $dom = $conn->get_domain_by_name("tck") }, "restored domain is still there", "tck");
    ok($dom->get_id > 0, "running domain with ID > 0");

    diag "Trying another restore while running";
    ok_error(sub { $conn->restore_domain("tck.img") }, "cannot restore to a running domain");
}

diag "Destroying the persistent domain";
$dom->destroy;
$dom->undefine;

diag "Checking that transient domain has gone away";
ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

# end
