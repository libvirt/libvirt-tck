
package Sys::Virt::TCK;

use strict;
use warnings;

use Sys::Virt;
use Sys::Virt::TCK::DomainBuilder;
use Config::Record;

use Test::Builder;
use Sub::Uplevel qw(uplevel);
use base qw(Exporter);

our @EXPORT = qw(ok_error ok_domain);

our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{config} = $params{config} ? $params{config} :
	Config::Record->new(file => ($ENV{LIBVIRT_TCK_CONFIG} || "/etc/tck.conf"));

    bless $self, $class;

    return $self;
}


sub setup {
    my $self = shift;

    my $uri = $self->config("uri", undef);
    $self->{conn} = Sys::Virt->new(address => $uri);
    my $type = $self->{conn}->get_type();
    $self->{type} = lc $type;

    $self->reset;

    return $self->{conn};
}

sub reset {
    my $self = shift;

    my @doms = $self->{conn}->list_domains;
    foreach my $dom (@doms) {
	if ($dom->get_id != 0) {
	    $dom->destroy;
	}
    }

    @doms = $self->{conn}->list_defined_domains();
    foreach my $dom (@doms) {
	$dom->undefine;
    }
}

sub cleanup {
    my $self = shift;
    delete $self->{conn};
}

sub config {
    my $self = shift;
    my $key = shift;
    if (@_) {
	my $default = shift;
	return $self->{config}->get($key, $default);
    } else {
	return $self->{config}->get($key);
    }
}


sub conn {
    my $self = shift;
    return $self->{conn};
}


sub generic_domain {
    my $self = shift;

    my $b = $self->bare_domain(@_);

    my $disk = $self->config("disk");
    $b->disk(src =>$disk, dst => "hda", type => "file");

    return $b;
}


sub bare_domain {
    my $self = shift;
    my $name = @_ ? shift : "test";

    my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $self->{conn},
					       name => $name);
    $b->memory(64 * 1024);

    my $kernel = $self->config("kernel");
    my $initrd = $self->config("initrd");
    $b->boot_kernel($kernel, $initrd);

    return $b;
}

# Borrowed from Test::Exception

sub _quiet_caller (;$) { ## no critic Prototypes
    my $height = $_[0];
    $height++;
    if( wantarray and !@_ ) {
        return (CORE::caller($height))[0..2];
    }
    else {
        return CORE::caller($height);
    }
		   }

sub _try_as_caller {
    my $coderef = shift;

    # local works here because Sub::Uplevel has already overridden caller
    local *CORE::GLOBAL::caller;
    { no warnings 'redefine'; *CORE::GLOBAL::caller = \&_quiet_caller; }

    my $ret = eval { uplevel 3, $coderef };
    return ($ret, $@);
};


my $Tester = Test::Builder->new;

sub ok_domain(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    die "must pass coderef, description and (optional) expected name"
	unless defined $description;

    my ($ret, $exception) = _try_as_caller($coderef);

    my $ok = "$exception" eq "" &&
	$ret && ref($ret) && $ret->isa("Sys::Virt::Domain") &&
	(!defined $name || ($ret->get_name() eq $name));

    $Tester->ok($ok, $description);
    unless ($ok) {
	$Tester->diag("expected Sys::Virt::Domain object" . ($name ? " with name $name" : ""));
	if ($exception) {
	    $Tester->diag("found '$exception'");
	} else {
	    if ($ret && ref($ret) && $ret->isa("Sys::Virt::Domain")) {
		$Tester->diag("found Sys::Virt::Domain object with name " . $ret->get_name);
	    } else {
		$Tester->diag("found '$ret'");
	    }
	}
    }
}

sub ok_error(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $code = shift;

    die "must pass coderef, description and (optional) expected error code"
	unless defined $description;

    my ($ret, $exception) = _try_as_caller($coderef);

    my $ok = ref($exception) && $exception->isa("Sys::Virt::Error") &&
	(!defined $code || ($exception->code() == $code));

    $Tester->ok($ok, $description);
    unless ($ok) {
	$Tester->diag("expecting Sys::Virt::Error object" . ($code ?  " with code $code" : ""));
	$Tester->diag("found '$exception'");
    }
    $@ = $exception;
    return $ok;
}

1;
