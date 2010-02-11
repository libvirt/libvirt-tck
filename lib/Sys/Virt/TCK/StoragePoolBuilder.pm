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
    };

    bless $self, $class;

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


sub as_xml {
    my $self = shift;

    my $data;
    my $fh = IO::String->new(\$data);
    my $w = XML::Writer->new(OUTPUT => $fh,
			     DATA_MODE => 1,
			     DATA_INDENT => 2);
    $w->startTag("pool", type => $self->{type});
    $w->dataElement("name" => $self->{name});

    $w->startTag("source");
    if ($self->{source}->{host}) {
	$w->emptyTag("host", name => $self->{source}->{host});
    }
    if ($self->{source}->{dir}) {
	$w->emptyTag("dir", path => $self->{source}->{dir});
    }
    if ($self->{source}->{device}) {
	foreach my $dev (@{$self->{source}->{device}}) {
	    $w->emptyTag("dev", path => $dev);
	}
    }
    if ($self->{source}->{adapter}) {
	$w->emptyTag("adapter", name => $self->{source}->{adapter});
    }
    if ($self->{source}->{name}) {
	$w->dataElement("name", $self->{source}->{name});
    }
    $w->endTag("source");

    $w->startTag("target");
    $w->dataElement("path", $self->{target});
    $w->endTag("target");

    $w->endTag("pool");

    return $data;
}

1;
