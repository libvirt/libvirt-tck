# -*- perl -*-
#
# Copyright (C) 2012 Red Hat, Inc.
# Copyright (C) 2012 Xiaoqiang Hu <xhu@redhat.com>
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

qemu/400-save-image-xml.t: test get and define xml from save image

=head1 DESCRIPTION

The test case validates that it is possible to define and get domain xml
from save image. There are three types of save image file covered in the
test: persistent, transient and invalid domain save image
=cut

use strict;
use warnings;

use Test::More tests => 10;

use Sys::Virt::TCK;
use Test::Exception;
use File::Basename;

my $tck = Sys::Virt::TCK->new();
my $savefile = $tck->bucket_dir("400-save-image-xml")."/"."tck.img";
my $conn = eval { $tck->setup(); };
BAIL_OUT "failed to setup test harness: $@" if $@;
END {
    $tck->cleanup if $tck;
    unlink $savefile if -f $savefile;
}

SKIP:{
    skip "Only relevant to QEMU driver", 10 unless $conn->get_type() eq "QEMU";

    # scenario 1 - get/define xml from transient domain save image
    my $xml = $tck->generic_domain(name => "tck")->as_xml;
    diag "Creating a new transient domain";
    my $dom;
    ok_domain(sub { $dom = $conn->create_domain($xml) }, "created transient domain object");

    unlink $savefile if -f $savefile;
    eval { $dom->save($savefile); };
    SKIP: {
        skip "save/restore not implemented", 9 if $@ && err_not_implemented($@);
        ok(!$@, "domain saved");
        die $@ if $@;

        my $savedxmldesc;
        diag "Checking that transient domain has gone away";
        ok_error(sub { $conn->get_domain_by_name("tck") }, "NO_DOMAIN error raised from missing domain",
                 Sys::Virt::Error::ERR_NO_DOMAIN);
        eval { $savedxmldesc = $conn->get_save_image_xml_description($savefile, 0); };
        SKIP: {
            skip "get/define save img xml not implemented", 7 if $@ && err_not_implemented($@);
            $savedxmldesc = $conn->get_save_image_xml_description($savefile, 0);
            $savedxmldesc =~ s/destroy/restart/g;
            $conn->define_save_image_xml($savefile, $savedxmldesc, 0);

            $savedxmldesc = $conn->get_save_image_xml_description($savefile, 0);
            ok(!($savedxmldesc =~ m/destroy/), "the transient domain save image xml has been updated");

            # scenario 2 - get/define xml from persistent domain save image
            my $xml = $tck->generic_domain("tck")->as_xml;
            diag "Creating a new persistent domain";
            ok_domain(sub { $dom = $conn->define_domain($xml) }, "created persistent domain object");

            unlink $savefile if -f $savefile;
            diag "Starting inactive domain";
            $dom->create;

            $dom->save($savefile);
            diag "Checking that persistent domain is stopped";
            ok_domain(sub { $conn->get_domain_by_name("tck") }, "persistent domain is still there", "tck");
            is($dom->get_id, -1, "running domain with ID == -1");

            $savedxmldesc = $conn->get_save_image_xml_description($savefile, 0);
            $savedxmldesc =~ s/destroy/restart/g;
            $conn->define_save_image_xml($savefile, $savedxmldesc, 0);

            $savedxmldesc = $conn->get_save_image_xml_description($savefile, 0);
            ok(!($savedxmldesc =~ m/destroy/), "the persistent save image xml has been updated");

            # scenario 3 - get/define xml from invalid domain save image
            unlink $savefile if -f $savefile;
            diag "Creating an invalid save img file";
            `dd if=/dev/null of=$savefile bs=1M count=100 >& /dev/null 2>&1`;
            ok($? == 0, "created 100M raw img file: $savefile");
            diag "Getting xml from invalid save image";
            ok_error(sub { $conn->get_save_image_xml_description($savefile, 0) }, "failed to get invalid domain save image xml" );
        }
    }
}
# end
