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

package Sys::Virt::TCK::StoragePoolBuilder;

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
	type => $params{type} ? $params{type} : "dir",
	source => {},
	perms => {},
    };

    bless $self, $class;

    return $self;
}

sub uuid {
    my $self = shift;

    $self->{uuid} = shift;

    return $self;
}

sub source_host {
    my $self = shift;

    $self->{source}->{host} = shift;

    return $self;
}


sub source_dir {
    my $self = shift;

    $self->{source}->{dir} = shift;

    return $self;
}


sub source_device {
    my $self = shift;
    my @devs = @_;

    $self->{source}->{device} = \@devs;

    return $self;
}


sub source_adapter {
    my $self = shift;

    $self->{source}->{adapter} = shift;

    return $self;
}


sub source_name {
    my $self = shift;

    $self->{source}->{name} = shift;

    return $self;
}


sub target {
    my $self = shift;

    $self->{target} = shift;

    return $self;
}

sub format {
    my $self = shift;

    $self->{format} = shift;

    return $self;
}


sub user {
    my $self = shift;

    $self->{perms}->{user} = shift;

    return $self;
}

sub group {
    my $self = shift;

    $self->{perms}->{group} = shift;

    return $self;
}

sub mode {
    my $self = shift;

    $self->{perms}->{mode} = shift;

    return $self;
}

sub as_xml {
    my $self = shift;

    my $data;
    my $fh = IO::String->new(\$data);
    my $w = XML::Writer->new(OUTPUT => $fh,
			     DATA_MODE => 1,
			     DATA_INDENT => 2);
    $w->startTag("pool", type => $self->{type});
    foreach (qw(name uuid)) {
	$w->dataElement("$_" => $self->{$_}) if $self->{$_};
    }

    $w->startTag("source");
    if ($self->{source}->{host}) {
	$w->emptyTag("host", name => $self->{source}->{host});
    }
    if ($self->{source}->{dir}) {
	$w->emptyTag("dir", path => $self->{source}->{dir});
    }
    if ($self->{source}->{device}) {
	foreach my $dev (@{$self->{source}->{device}}) {
	    $w->emptyTag("device", path => $dev);
	}
    }
    if ($self->{source}->{adapter}) {
	$w->emptyTag("adapter", name => $self->{source}->{adapter});
    }
    if ($self->{source}->{name}) {
	$w->dataElement("name", $self->{source}->{name});
    }
    if ($self->{format}) {
	$w->emptyTag("format", type => $self->{format});
    }
    $w->endTag("source");

    $w->startTag("target");
    $w->dataElement("path", $self->{target});
    if (int(keys %{$self->{perms}})) {
	$w->startTag("permissions");
	foreach (qw(mode user group)) {
	    $w->dataElement("$_" => $self->{perms}->{$_}) if $self->{perms}->{$_};
	}
	$w->endTag("permissions");
    }
    $w->endTag("target");

    $w->endTag("pool");

    return $data;
}

1;
