#
# Copyright (C) 2025 The FreeBSD Foundation
#
# This program is free software; You can redistribute it and/or modify
# it under the GNU General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any
# later version
#
# The file "LICENSE" distributed along with this file provides full
# details of the terms and conditions
#

package Sys::Virt::TCK::HostUtils;

use strict;
use warnings;
use POSIX qw(uname);

sub new {
    my $class = shift;
    my $self = bless {
        os => (uname())[0]
    }, $class;

    return $self;
}

sub create_bridge {
    my $self = shift;
    my $name = shift;

    if ($self->{os} eq 'FreeBSD') {
        return system("ifconfig bridge create name $name");
    } else {
        return system("ip link add name $name type bridge");
    }
}

sub destroy_bridge {
    my $self = shift;
    my $name = shift;

    if ($self->{os} eq 'FreeBSD') {
        return system("ifconfig $name destroy");
    } else {
        return system("ip link del $name");
    }
}

1;
