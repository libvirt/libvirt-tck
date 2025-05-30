#
# Copyright (C) 2009 Red Hat, Inc.
# Copyright (C) 2009 Daniel P. Berrange
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

package Sys::Virt::TCK::DomainCapabilities;

use strict;
use warnings;

use XML::Twig;


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $self = {};

    my $xml = $params{xml};
    die "xml parameter is required" unless defined $xml;

    bless $self, $class;

    $self->parse($xml);

    return $self;
}

sub parse {
    my $self = shift;
    my $xml = shift;

    my $twig = XML::Twig->new();
    $twig->parse($xml);

    $self->{console_types} = [];

    $self->_parse_capabilities($twig->root);
}

sub _parse_capabilities {
    my $self = shift;
    my $node = shift;

    my $console = $node->first_descendant('console');
    $self->_parse_console($console) if $console;
}

sub _parse_console {
    my $self = shift;
    my $node = shift;

    $self->{console_types} = [ map { $_->text } $node->descendants('value') ];
}

1;
