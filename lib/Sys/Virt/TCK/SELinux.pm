#
# Copyright (C) 2011 Red Hat, Inc.
#
# This program is free software; You can redistribute it and/or modify
# it under the GNU General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any
# later version
#
# The file "LICENSE" distributed along with this file provides full
# details of the terms and conditions
#

package Sys::Virt::TCK::SELinux;

use strict;
use warnings;

use base qw(Exporter);

use vars qw($SELINUX_GENERIC_CONTEXT $SELINUX_DOMAIN_CONTEXT
 $SELINUX_IMAGE_CONTEXT $SELINUX_OTHER_CONTEXT
 $SELINUX_GENERIC_TYPE $SELINUX_DOMAIN_TYPE
 $SELINUX_IMAGE_TYPE $SELINUX_OTHER_TYPE);

our @EXPORT = qw(selinux_get_file_context
 selinux_set_file_context
 selinux_restore_file_context
 selinux_get_type
 selinux_get_mcs
 $SELINUX_GENERIC_CONTEXT $SELINUX_DOMAIN_CONTEXT
 $SELINUX_IMAGE_CONTEXT $SELINUX_OTHER_CONTEXT
 $SELINUX_GENERIC_TYPE $SELINUX_DOMAIN_TYPE
 $SELINUX_IMAGE_TYPE $SELINUX_OTHER_TYPE);

$SELINUX_OTHER_TYPE = "svirt_tcg_t";
$SELINUX_GENERIC_TYPE = "virt_image_t";
$SELINUX_DOMAIN_TYPE = "svirt_t";
$SELINUX_IMAGE_TYPE = "svirt_image_t";

$SELINUX_OTHER_CONTEXT = "system_u:system_r:svirt_tcg_t:s0";
$SELINUX_GENERIC_CONTEXT = "system_u:object_r:virt_image_t:s0";
$SELINUX_DOMAIN_CONTEXT = "system_u:system_r:svirt_t:s0";
$SELINUX_IMAGE_CONTEXT = "system_u:object_r:svirt_image_t:s0";

sub selinux_get_type {
    my $context = shift;

    my @bits = split /:/, $context;
    return $bits[2];
}

sub selinux_get_mcs {
    my $context = shift;

    my @bits = split /:/, $context;
    return $bits[4];
}

sub selinux_get_file_context {
    my $path = shift;

    my @attr = split /\n/, `getfattr -n security.selinux $path 2>/dev/null`;
    foreach (@attr) {
	if (/security.selinux=\"(.*)\"/) {
	    return $1;
	}
    }
    return undef;
}


sub selinux_set_file_context {
    my $path = shift;
    my $ctx = shift;

    system "chcon $ctx $path";
}


sub selinux_restore_file_context {
    my $path = shift;

    system "restorecon -F $path";

    return selinux_get_file_context($path);
}
