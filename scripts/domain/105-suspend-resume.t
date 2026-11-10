#!/usr/bin/env perl
# -*- perl -*-
#
# Copyright (C) 2026 The FreeBSD Foundation
#
# This program is free software; you can redistribute it and/or modify
# it under the GNU General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any
# later version
#
# The file "LICENSE" distributed with this file provides full
# details of the terms and conditions
#

=pod

=head1 NAME

domain/105-suspend-resume.t - Domain suspend and resume lifecycle

=head1 DESCRIPTION

The test case validates that an active domain can be suspended and
resumed, and that its state reflects each lifecycle transition.

=cut

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }


my $xml = $tck->generic_domain(name => "tck")->as_xml;

diag "Defining a persistent domain";
my $dom;
ok_domain(sub { $dom = $conn->define_domain($xml) }, "defined persistent domain object");

diag "Starting the domain";
lives_ok(sub { $dom->create }, "started domain");
my ($state) = $dom->get_state();
is($state, Sys::Virt::Domain::STATE_RUNNING, "domain is running");

diag "Suspending the domain";
eval { $dom->suspend };
my $err = $@;
SKIP: {
    skip "suspend not supported/implemented", 4
        if $err && (err_not_implemented($err) || err_unsupported($err));
    ok(!$err, "suspended domain");
    die $err if $err;

    ($state) = $dom->get_state();
    is($state, Sys::Virt::Domain::STATE_PAUSED, "domain is paused");

    diag "Resuming the domain";
    lives_ok(sub { $dom->resume }, "resumed domain");
    ($state) = $dom->get_state();
    is($state, Sys::Virt::Domain::STATE_RUNNING, "domain is running again");
}

diag "Destroying and undefining the domain";
$dom->destroy;
$dom->undefine;

# end
