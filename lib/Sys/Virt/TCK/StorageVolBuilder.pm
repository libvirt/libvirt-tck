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
	name => $params{name} ? $params{name} : "test" ,
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

    if ($self->{format}) {
	$w->startTag("target");
	$w->emptyTag("format", type => $self->{format});
	$w->endTag("target");
    }

    $w->endTag("volume");

    return $data;
}

1;
