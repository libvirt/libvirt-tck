#!/usr/bin/perl
# -*- perl -*-
#
# Copyright (C) 2011 Red Hat, Inc.
# Copyright (C) 2011 Daniel P. Berrange
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

domain/300-migration.t - test migration workflows

=head1 DESCRIPTION

The test case validates all the different ways to
invoke migration. There are alot of variables involved
in testing migration

 - Three different control/communication methods

     1. Normal
     2. Peer2peer
     3. Peer2peer + tunnelled

 - 8 Different scenarios of persistent vs transient
   guests

     1. Transient running source, no dest
     2. Transient running source, persistent inactive dest
     3. Persistent running source, no dest
     4. Persistent running source, persistent inactive dest
     5. Transient paused source, no dest
     6. Transient paused source, persistent inactive dest
     7. Persistent paused source, no dest
     8. Persistent paused source, persistent inactive dest

 - With each scenario there are upto 4 flag combinations
   affecting persistent/transient state

     1. No flags
     2. UNDEFINE_SOURCE
     3. PERSIST
     4. UNDEFINE_SOURCE|PERSIST

This gives 96 major functional test cases.

On each test case we validate 10 conditions, giving a
total of 960 tests results

Ideally this test script should be run once for each different
combination of libvirt client & libvirtd source/target, giving
another factor of 8

    1. client < 0.9.2, source < 0.9.2, target < 0.9.2
    2. client >= 0.9.2, source < 0.9.2, target < 0.9.2
    3. client < 0.9.2, source >= 0.9.2, target < 0.9.2
    4. client < 0.9.2, source < 0.9.2, target >= 0.9.2
    5. client >= 0.9.2, source >= 0.9.2, target < 0.9.2
    6. client >= 0.9.2, source < 0.9.2, target >= 0.9.2
    7. client < 0.9.2, source >= 0.9.2, target >= 0.9.2
    8. client >= 0.9.2, source >= 0.9.2, target >= 0.9.2

Finally, this is only testing successful migration cases.

We ought to have another test which validates recovery from
a variety of common migration failure scenarios. This would
add another few 1000 tests :-)

=cut

use strict;
use warnings;

use Test::Exception;

#
# 8 scenarios in @tests
# Each scenario has 4 cases in @tests
#
# Repeated scenarios in 3 ways (normal, p2p, tunnelled)
#
# Each iteration has 10 tests
#
# 8 * 4 * 3 * 10 == 960

use Test::More tests => 960;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
my ($conn, $otherconn) = eval { $tck->setup(dualhost => 1); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END { $tck->cleanup if $tck; }

my $xml = $tck->generic_domain(name => "tck")->uuid("050072e8-7bce-3515-992a-8431d74f371f")->as_xml;

use Sys::Virt::Domain;
use IO::File;


my @tests = (
    # 1. Transient running guest, no dst
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_RUNNING,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

    # 2. Transient running guest, with dst
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_RUNNING,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

    # 3. Persistent running guest, no dst
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_RUNNING,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 0,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 1,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

    # 4. Persistent running guest, with dst
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_RUNNING,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_RUNNING,
	presrcconfig => 1,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_RUNNING,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },



    # 5. Transient paused guest, no dst
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

    # 6. Transient paused guest, with dst
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 0,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

    # 7. Persistent paused guest, no dst
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 0,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 0,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 0,
	postdstconfig => 0,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

    # 8. Persistent paused guest, with dst
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_LIVE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PERSIST_DEST,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 0,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE,
    },
    {
	prestate => Sys::Virt::Domain::STATE_PAUSED,
	runstate => Sys::Virt::Domain::STATE_PAUSED,
	poststate => Sys::Virt::Domain::STATE_PAUSED,
	presrcconfig => 1,
	postsrcconfig => 1,
	predstconfig => 1,
	postdstconfig => 1,
	flags => Sys::Virt::Domain::MIGRATE_PAUSED,
    },

);

#@tests = ($tests[4]);

my @flags = (0,
	     Sys::Virt::Domain::MIGRATE_PEER2PEER,
	     Sys::Virt::Domain::MIGRATE_PEER2PEER | Sys::Virt::Domain::MIGRATE_TUNNELLED);

#@flags = ($flags[0]);

SKIP: {
    skip "No other URI available", 960 unless $otherconn;

    foreach my $flags (@flags) {
	diag "Protocol flags $flags\n\n";
	foreach my $test (@tests) {
	    my $srcvm;
	    my $dstvm;

	    my $migflags = $flags | $test->{flags};

	    my $s = sprintf "PreState %d PostState %d PreSrcConf %d PostSrcConf %d PreDstConf %d PostDstConf %d Flags %2d (%2d)",
	      $test->{prestate},$test->{poststate},$test->{presrcconfig},
	      $test->{postsrcconfig},$test->{predstconfig},$test->{postdstconfig},
	      $test->{flags}, $flags;
	    diag $s;

	    if ($test->{presrcconfig}) {
		ok_domain(sub { $srcvm = $conn->define_domain($xml) }, "defined initial domain");

		if ($test->{prestate} == Sys::Virt::Domain::STATE_PAUSED) {
		    lives_ok(sub { $srcvm->create(Sys::Virt::Domain::START_PAUSED) }, "started initial domain");
		} else {
		    lives_ok(sub { $srcvm->create() } , "started initial domain");
		}
	    } else {
		ok(1, "no need to define initial domain");
		if ($test->{prestate} == Sys::Virt::Domain::STATE_PAUSED) {
		    ok_domain(sub { $srcvm = $conn->create_domain($xml, Sys::Virt::Domain::START_PAUSED) },
			      "created initial domain");
		} else {
		    ok_domain(sub { $srcvm = $conn->create_domain($xml) }, "created initial domain");
		}
	    }

	    if ($test->{predstconfig}) {
		ok_domain(sub { $dstvm = $otherconn->define_domain($xml)}, "defined target domain");
		$dstvm = undef;
	    } else {
		ok(1, "no need to define target domain");
	    }

	    my $failed = 1;
	    lives_ok(sub {
		if ($migflags & Sys::Virt::Domain::MIGRATE_PEER2PEER) {
		    $srcvm->migrate_to_uri($otherconn->get_uri, $migflags);
		} else {
		    $dstvm = $srcvm->migrate($otherconn, $migflags);
		}

		$srcvm = undef;
		$dstvm = undef;
		$failed = 0;
		     }, "migrated domain");

	  SKIP: {
	      skip "source VM failed migration", 5 if $failed;

	      if ($test->{postsrcconfig}) {
		  $srcvm = $conn->get_domain_by_name("tck");
		  ok(!$srcvm->is_active, "source VM is not still active");
		  ok($srcvm->is_persistent, "source VM config still exists");
	      } else {
		  eval { $srcvm = $conn->get_domain_by_name("tck"); };
		  ok(!$srcvm, "source VM is not still active");
		  ok(1, "source VM config does not still exist");
	      }

	      lives_ok(sub { $dstvm = $otherconn->get_domain_by_name("tck")}, "target VM exists");
	      ok($dstvm->is_active, "target VM is running");

	      ok(!$test->{postdstconfig} || $dstvm->is_persistent, "target VM is persistent");

	      my $state = $dstvm->get_info()->{state};

	      is($state, $test->{poststate}, "target VM state");
	    };

	    $tck->reset_domains($conn);
	    $tck->reset_domains($otherconn);
	}
	print "\n\n";
    }

};
