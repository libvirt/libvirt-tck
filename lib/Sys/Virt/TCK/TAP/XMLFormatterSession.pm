package Sys::Virt::TCK::TAP::XMLFormatterSession;

use strict;
use warnings;

use base qw(TAP::Base);

use accessors qw(xml parser);

sub _initialize {
    my $self = shift;
    my $args = shift;

    $args ||= {};

    $self->SUPER::_initialize($args);

    $self->xml($args->{xml});
    $self->parser($args->{parser});

    $self->xml->startTag("test",
			 name => $args->{test});

    return $self;
}


sub result {
    my $self = shift;
    my $result = shift;

    my $meth = "result_" . $result->type;

    if ($self->can($meth)) {
	$self->$meth($result);
    }
}

sub result_plan {
    my $self = shift;
    my $result = shift;

    if ($result->has_skip) {
	$self->xml->startTag("plan",
			     count => $result->tests_planned);
	$self->xml->dataElement("skip", $result->explanation);
	$self->xml->endTag("plan");
    } else {
	$self->xml->emptyTag("plan",
			     count => $result->tests_planned);
    }
}

sub result_pragma {
    my $self = shift;
    my $result = shift;

    foreach ($result->pragmas) {
	$self->dataElement("pragma", $_);
    }
}

sub result_test {
    my $self = shift;
    my $result = shift;

    $self->xml->startTag("test",
			 id => $result->number);

    if ($result->is_ok) {
	$self->xml->emptyTag("pass");
    } else {
	$self->xml->emptyTag("fail");
    }
    $self->xml->emptyTag("unplanned") if $result->is_unplanned;

    $self->xml->cdataElement("desc", $result->description);

    if ($result->has_todo) {
	$self->xml->cdataElement("todo", $result->explanation,
				 pass => $result->todo_passed ? "yes" : "no");
    }
    if ($result->has_skip) {
	$self->xml->cdataElement("skip", $result->explanation);
    }

    $self->xml->endTag("test");
}

sub result_bailout {
    my $self = shift;
    my $result = shift;

    $self->xml->cdataElement("bailout",
			     $result->explanation);
}

sub result_version {
    my $self = shift;
    my $result = shift;

    $self->xml->dataElement("version", $result->version);
}

sub result_comment {
    my $self = shift;
    my $result = shift;

    return if $result->comment eq "";

    $self->xml->cdataElement("comment", $result->comment);
}

sub result_unknown {
    my $self = shift;
    my $result = shift;

    return if $result->raw eq "";

    $self->xml->cdataElement("unknown", $result->raw);
}

sub result_yaml {
    my $self = shift;
    my $result = shift;

    $self->xml->cdataElement("yaml", $result->data);
}

sub close_test {
    my $self = shift;

    $self->xml->startTag("summary",
			 passed => int($self->parser->passed),
			 failed => int($self->parser->failed),
			 todo => int($self->parser->todo),
			 unexpected => int($self->parser->todo_passed),
			 skipped => int($self->parser->skipped));

    if ($self->parser->skip_all) {
	$self->xml->startTag("plan",
			     expected => int($self->parser->tests_planned),
			     actual => int($self->parser->tests_run));
	$self->xml->cdataElement("skip", $self->parser->skip_all);
	$self->xml->endTag("plan");
    } else {
	$self->xml->emptyTag("plan",
			     expected => int($self->parser->tests_planned),
			     actual => int($self->parser->tests_run));
    }

    $self->xml->emptyTag("status",
			 wait => $self->parser->wait,
			 exit => $self->parser->exit);

    $self->xml->emptyTag("timing",
			 start => $self->parser->start_time,
			 end => $self->parser->end_time);

    $self->xml->endTag("summary");

    $self->xml->endTag("test");
}


1;
