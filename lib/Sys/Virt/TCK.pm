
package Sys::Virt::TCK;

use strict;
use warnings;

use Sys::Virt;
use Sys::Virt::TCK::DomainBuilder;
use Config::Record;

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

    $self->{conn} = Sys::Virt->new(address => $self->config("uri", undef));
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
    my $default = shift;
    return $self->{config}->get($key, $default);
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

1;
