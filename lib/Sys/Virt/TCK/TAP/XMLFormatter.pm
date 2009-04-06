package Sys::Virt::TCK::TAP::XMLFormatter;

use strict;
use warnings;

use base qw(TAP::Base);

use accessors qw(verbosity xml);

use Sys::Virt::TCK::TAP::XMLFormatterSession;
use XML::Writer;


sub _initialize {
    my $self = shift;
    my $args = shift;

    $args ||= {};

    $self->SUPER::_initialize($args);

    $self->verbosity(0);

    my $w = XML::Writer->new(OUTPUT => \*STDOUT,
			     DATA_MODE => 1,
			     DATA_INDENT => 2);
    $self->xml($w);

    return $self;
}

use Data::Dumper;

sub prepare {
    my $self = shift;
    my @tests = @_;

    $self->xml->startTag("results");
}

sub open_test {
    my $self = shift;
    my $test = shift;
    my $parser = shift;

    return Sys::Virt::TCK::TAP::XMLFormatterSession->new({ test => $test, parser => $parser, xml => $self->xml });
}

sub summary {
    my $self = shift;
    my $agg = shift;

    $self->xml->startTag("summary",
			 total => int($agg->total),
			 passed => int($agg->passed),
			 failed => int($agg->failed),
			 todo => int($agg->todo),
			 unexpected => int($agg->todo_passed),
			 skipped => int($agg->skipped),
			 errors => int($agg->parse_errors));


    $self->xml->endTag("summary");
    $self->xml->endTag("results");
    $self->xml->end;
}


1;
