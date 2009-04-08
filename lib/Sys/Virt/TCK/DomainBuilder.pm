package Sys::Virt::TCK::DomainBuilder;

use strict;
use warnings;
use Sys::Virt;

use IO::String;
use XML::Writer;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $conn = $params{conn} ? $params{conn} : die "conn parameter is required";

    my $type = $conn->get_type();
    my $domtype;
    if ($type eq "QEMU") {
	$domtype = "qemu";
    } else {
	$domtype = "xen";
    }
    # Some older Xen can't boot kernel+initrd, so default to PV
    my $ostype;
    if ($type eq "Xen") {
	$ostype = "xen";
    } else {
	$ostype = "hvm";
    }

    my $self = {
	name => $params{name} ? $params{name} : "test" ,
	type => $domtype,
	ostype => $ostype,
	boot => { type => "disk" },
	lifecycle => {},
	features => {},
	disks => [],
	interfaces => [],
	serials => [],
	parallels => [],
	consoles => [],
	inputs => [],
	graphics => [],
	hostdevs => []
    };

    bless $self, $class;

    return $self;
}

sub memory {
    my $self = shift;
    my $mem = shift;

    $self->{memory} = $mem
	unless defined $self->{memory};
    $self->{currentMemory} = $mem;

    return $self;
}

sub maxmem {
    my $self = shift;

    $self->{memory} = shift;

    return $self;
}

sub vcpu {
    my $self = shift;

    $self->{vcpu} = shift;

    return $self;
}

sub uuid {
    my $self = shift;

    $self->{uuid} = shift;

    return $self;
}

sub boot_network {
    my $self = shift;

    $self->{boot} = {
	type => "network"
    };

    return $self;
}

sub boot_disk {
    my $self = shift;

    $self->{boot} = {
	type => "disk"
    };

    return $self;
}

sub boot_cdrom {
    my $self = shift;

    $self->{boot} = {
	type => "cdrom"
    };

    return $self;
}

sub boot_floppy {
    my $self = shift;

    $self->{boot} = {
	type => "floppy"
    };

    return $self;
}

sub boot_kernel {
    my $self = shift;
    my $kernel = shift;
    my $initrd = shift;
    my $cmdline = shift;

    die "kernel parameter is required" unless $kernel;

    $self->{boot} = {
	type => "kernel",
	kernel => $kernel,
	($initrd ? (initrd => $initrd) : ()),
	($cmdline ? (cmdline => $cmdline) : ()),
    };

    return $self;
}

sub boot_bootloader {
    my $self = shift;
    my $path = shift;

    $self->{boot} = {
	type => "bootloader",
	bootloader => $path
    };

    return $self;
}



sub on_reboot {
    my $self = shift;
    $self->{lifecycle}->{on_reboot} = shift;
    return $self;
}

sub on_poweroff {
    my $self = shift;
    $self->{lifecycle}->{on_poweroff} = shift;
    return $self;
}

sub on_crash {
    my $self = shift;
    $self->{lifecycle}->{on_crash} = shift;
    return $self;
}

sub with_acpi {
    my $self = shift;
    $self->{features}->{acpi} = 1;
    return $self;
}
sub with_pae {
    my $self = shift;
    $self->{features}->{pae} = 1;
}
sub with_apic {
    my $self = shift;
    $self->{features}->{apic} = 1;
}

sub disk {
    my $self = shift;
    my %params = @_;

    die "src parameter is required" unless $params{src};
    die "dst parameter is required" unless $params{dst};
    die "type parameter is required" unless $params{type};

    push @{$self->{disks}}, \%params;

    return $self;
}

sub as_xml {
    my $self = shift;

    my $data;
    my $fh = IO::String->new(\$data);
    my $w = XML::Writer->new(OUTPUT => $fh,
			     DATA_MODE => 1,
			     DATA_INDENT => 2);
    $w->startTag("domain",
		 "type" => $self->{type});
    foreach (qw(name uuid memory currentMemory vcpu)) {
	$w->dataElement("$_" => $self->{$_}) if $self->{$_};
    }

    $w->startTag("os");
    $w->dataElement("type", $self->{ostype});

    if ($self->{boot}->{type} eq "disk") {
	$w->emptyTag("boot", dev => "hd");
    } elsif ($self->{boot}->{type} eq "floppy") {
	$w->emptyTag("boot", dev => "fd");
    } elsif ($self->{boot}->{type} eq "cdrom") {
	$w->emptyTag("boot", dev => "cdrom");
    } elsif ($self->{boot}->{type} eq "network") {
	$w->emptyTag("boot", dev => "network");
    } elsif ($self->{boot}->{type} eq "kernel") {
	foreach (qw(kernel initrd cmdline)) {
	    $w->dataElement($_, $self->{boot}->{$_}) if $self->{boot}->{$_};
	}
    }
    $w->endTag("os");

    if ($self->{boot}->{type} eq "bootloader") {
	$w->dataElement("bootloader" => $self->{boot}->{bootloader});
    }

    foreach (qw(on_reboot on_poweroff on_crash)) {
	$w->dataElement($_ => $self->{lifecycle}->{$_}) if $self->{lifecycle}->{$_};
    }

    if (%{$self->{features}}) {
	$w->startTag("features");
	foreach (qw(pae acpi apic)) {
	    $w->emptyTag($_) if $self->{features}->{$_};
	}
	$w->endTag("features");
    }

    $w->startTag("devices");
    foreach my $disk (@{$self->{disks}}) {
	$w->startTag("disk",
		     type => $disk->{type},
		     $disk->{device} ? (device => $disk->{device}) : ());

	if ($disk->{type} eq "block") {
	    $w->emptyTag("source",
			 dev => $disk->{src});
	} else {
	    $w->emptyTag("source",
			 file => $disk->{src});
	}
	$w->emptyTag("target",
		     dev => $disk->{dst},
		     $disk->{bus} ? (bus => $disk->{bus}) : ());
	$w->endTag("disk");
    }
    $w->endTag("devices");
    $w->endTag("domain");

    return $data;
}

1;
