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

use Test::More tests => 10;

use Sys::Virt::TCK;
use Test::Exception;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink "test.img" if -f "test.img";
}


my $xml = $tck->generic_domain("test")->as_xml;

diag "Creating a new transient domain";
my $dom;
ok_domain { $dom = $conn->define_domain($xml) } "created persistent domain object";

unlink "test.img" if -f "test.img";
ok_error { $dom->save("test.img") } "canot save a inactive domain";

diag "Starting inactive domain";
$dom->create;

ok($dom->get_id > 0, "running domain with ID > 0");

$dom->save("test.img");

diag "Checking that persistent domain is stopped";
ok_domain { $conn->get_domain_by_name("test") } "persistent domain is still there", "test";
is($dom->get_id, -1, "running domain with ID == -1");

diag "Restoring domain from file";
lives_ok { $conn->restore_domain("test.img") } "domain has been restored";

ok_domain { $dom = $conn->get_domain_by_name("test") } "restored domain is still there", "test";
ok($dom->get_id > 0, "running domain with ID > 0");

diag "Trying another restore while running";
ok_error { $conn->restore_domain("test.img") } "cannot restore to a running domain";

diag "Destroying the persistent domain";
$dom->destroy;
$dom->undefine;

diag "Checking that transient domain has gone away";
ok_error { $conn->get_domain_by_name("test") } "NO_DOMAIN error raised from missing domain", 42;

# end
