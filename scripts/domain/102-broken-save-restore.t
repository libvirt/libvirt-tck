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

domain/100-transient-save-restore.t - Transient domain save/restore

=head1 DESCRIPTION

The test case validates that it is possible to save and restore
transient domains to/from a file.

=cut

use strict;
use warnings;

use Test::More skip_all => "Until RHBZ 518032 is fixed";
#use Test::More tests => 5;

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
ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

unlink "tck.img" if -f "tck.img";
eval { $dom->save("tck.img"); };
SKIP: {
    skip "save/restore not implemented", 4 if $@ && err_not_implemented($@);
    ok(!$@, "domain saved");
    die $@ if $@;

    diag "Checking that transient domain has gone away";
    ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);

    diag "Delibrately corrupting saved state";
    open SRC, "+<tck.img" or die "cannot update tck.img: $!";
    my @bits = stat SRC;
    # Killing 512k from the end of the file ought to annoy VMs sufficiently ;-)
    truncate SRC, ($bits[7]-(1024*512));
    close SRC or die "cannot save truncated tck.img: $!";

    diag "Attempting to restore the guest from corrupt image";
    ok_error(sub { $conn->restore_domain("tck.img") }, "domain failed during restore");

    ok_error(sub { $dom = $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain", 42);
}

diag "Destroying the transient domain just in case its still there";
eval { $dom->destroy; };

# end
