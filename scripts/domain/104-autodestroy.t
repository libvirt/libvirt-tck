#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2026 The FreeBSD Foundation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# The file "LICENSE" distributed with this file provides full details
# of the terms and conditions.
#

=pod

=head1 NAME

domain/104-autodestroy.t - Domain startup with autodestroy

=head1 DESCRIPTION

The test case validates autodestroy for both transient domain creation
and persistent domain startup. Domains must remain running while the
owning connection is open, and stop when that connection is closed.

=cut

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $xml = $tck->generic_domain(name => "tck")->as_xml;

my $owner = Sys::Virt->new(uri => $conn->get_uri());
my $owned;

ok_domain(sub {
    $owned = $owner->create_domain($xml, Sys::Virt::Domain::START_AUTODESTROY);
}, "created transient domain with autodestroy");
ok($owned->is_active(), "transient domain is active while owner is connected");

undef $owned;
undef $owner;

lives_ok(sub {
    eval {
        local $SIG{ALRM} = sub {
            die "timeout waiting for transient domain autodestroy\n";
        };
        alarm(30);

        while (1) {
            sleep(1);
            eval { $conn->get_domain_by_name("tck") };
            my $err = $@;
            next unless $err;
            die $err unless ref($err) && $err->isa("Sys::Virt::Error") &&
                $err->code() == Sys::Virt::Error::ERR_NO_DOMAIN;
            last;
        }
        alarm(0);
    };
    my $err = $@;
    alarm(0);
    die $err if $err;
}, "transient domain disappears when owner closes");

my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain");

$owner = Sys::Virt->new(uri => $conn->get_uri());
$owned = $owner->get_domain_by_name("tck");
lives_ok(sub {
    $owned->create(Sys::Virt::Domain::START_AUTODESTROY);
}, "started persistent domain with autodestroy");
ok($owned->is_active(), "persistent domain is active while owner is connected");

undef $owned;
undef $owner;

lives_ok(sub {
    eval {
        local $SIG{ALRM} = sub {
            die "timeout waiting for persistent domain autodestroy\n";
        };
        alarm(30);

        while ($dom->is_active()) {
            sleep(1);
        }
        alarm(0);
    };
    my $err = $@;
    alarm(0);
    die $err if $err;
}, "persistent domain stops when owner closes");
ok($dom->is_persistent(), "persistent definition survives autodestroy");

$dom->undefine();

# end
