#
# Copyright (C) 2009, 2010 Red Hat, Inc.
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

package Sys::Virt::TCK::StorageVolBuilder;

use strict;
use warnings;
use Sys::Virt;

use IO::String;
use XML::Writer;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $self = {
        name => $params{name} ? $params{name} : "tck" ,
    };

    bless $self, $class;

    return $self;
}

sub capacity {
    my $self = shift;

    $self->{capacity} = shift;

    return $self;
}


sub allocation {
    my $self = shift;

    $self->{allocation} = shift;

    return $self;
}


sub format {
    my $self = shift;

    $self->{format} = shift;

    return $self;
}

sub encryption_format {
    my $self = shift;

    $self->{encformat} = shift;

    return $self;
}

sub secret {
    my $self = shift;

    $self->{secret} = shift;

    return $self;
}

sub backing_format {
    my $self = shift;
    $self->{backingFormat} = shift;
    return $self;
}

sub backing_file {
    my $self = shift;
    $self->{backingFile} = shift;
    return $self;
}


sub as_xml {
    my $self = shift;

    my $data;
    my $fh = IO::String->new(\$data);
    my $w = XML::Writer->new(OUTPUT => $fh,
                             DATA_MODE => 1,
                             DATA_INDENT => 2);
    $w->startTag("volume");
    $w->dataElement("name" => $self->{name});

    $w->dataElement("capacity", $self->{capacity});
    $w->dataElement("allocation", $self->{allocation});

    if ($self->{format} || $self->{encformat}) {
        $w->startTag("target");
        if ($self->{format}) {
            $w->emptyTag("format", type => $self->{format});
        }
        if ($self->{encformat}) {
            $w->startTag("encryption", format => $self->{encformat});
            $w->emptyTag("secret", type => "passphrase", uuid => $self->{secret});
            $w->endTag("encryption");
        }
        $w->endTag("target");
    }

    if ($self->{backingFile}) {
        $w->startTag("backingStore");
        $w->dataElement("path", $self->{backingFile});
        if ($self->{backingFormat}) {
            $w->emptyTag("format", type => $self->{backingFormat});
        }
        if ($self->{encformat}) {
            $w->startTag("encryption", format => $self->{encformat});
            $w->emptyTag("secret", type => "passphrase", uuid => $self->{secret});
            $w->endTag("encryption");
        }
        $w->endTag("backingStore");
    }

    $w->endTag("volume");

    return $data;
}

1;
