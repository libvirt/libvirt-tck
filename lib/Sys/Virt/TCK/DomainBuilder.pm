#
# Copyright (C) 2009-2010 Red Hat, Inc.
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

    my $domain = $params{domain} ? $params{domain} : die "domain parameter is required";
    my $ostype = $params{ostype} ? $params{ostype} : die "ostype parameter is required";

    my $self = {
	name => $params{name} ? $params{name} : "tck" ,
	type => $domain,
	ostype => $ostype,
	boot => { type => "disk" },
	emulator => undef,
	lifecycle => {},
	features => {},
	disks => [],
	filesystems => [],
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


sub boot_init {
    my $self = shift;
    my $path = shift;

    $self->{boot} = {
	type => "init",
	init => $path
    };

    return $self;
}

sub boot_cmdline {
    my $self = shift;
    my $cmdline = shift;

    my $kernel = $self->{boot}->{kernel};
    my $initrd = $self->{boot}->{initrd};

    $self->{boot} = {
	type => "kernel",
	kernel => $kernel,
	initrd => $initrd,
	cmdline => $cmdline
    };

    return $self;
}

sub clear_kernel_initrd_cmdline {
    my $self = shift;

    $self->{boot} = {
	type => "kernel",
	kernel => "",
	initrd => "",
	cmdline => ""
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

sub emulator {
    my $self = shift;

    $self->{emulator} = shift;

    return $self;
}

sub loader {
    my $self = shift;

    $self->{boot}->{loader} = shift;

    return $self;
}


sub rmdisk {
    my $self = shift;

    return pop @{$self->{disks}};
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

sub interface {
    my $self = shift;
    my %params = @_;

    die "type parameter is required" unless $params{type};
    die "source parameter is required" unless $params{source};
    die "model parameter is required" unless $params{model};

    push @{$self->{interfaces}}, \%params;

    return $self;
}

sub graphics {
    my $self = shift;
    my %params = @_;

    die "type parameter is required" unless $params{type};

    push @{$self->{graphics}}, \%params;

    return $self;
}


sub filesystem {
    my $self = shift;
    my %params = @_;

    die "src parameter is required" unless $params{src};
    die "dst parameter is required" unless $params{dst};
    die "type parameter is required" unless $params{type};

    push @{$self->{filesytems}}, \%params;

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
    } elsif ($self->{boot}->{type} eq "init") {
	$w->dataElement("init", $self->{boot}->{init});
    }

    if (exists $self->{boot}->{loader}) {
	$w->dataElement("loader" => $self->{boot}->{loader});
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
    if ($self->{emulator}) {
	$w->dataElement("emulator" => $self->{emulator});
    }
    foreach my $disk (@{$self->{disks}}) {
	$w->startTag("disk",
		     type => $disk->{type},
		     $disk->{device} ? (device => $disk->{device}) : ());

	if ($disk->{format}) {
	    $w->emptyTag("driver",
			 name => $disk->{format}->{name},
			 type => $disk->{format}->{type});
	}

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
	if ($disk->{secret}) {
	    $w->startTag("encryption", format => "qcow");
	    $w->emptyTag("secret", type => "passphrase", uuid => $disk->{secret});
	    $w->endTag("encryption");
	}
	$w->endTag("disk");
    }
    foreach my $fs (@{$self->{filesystems}}) {
	$w->startTag("filesystem",
		     type => $fs->{type});

	$w->emptyTag("source",
		     dir => $fs->{src});
	$w->emptyTag("target",
		     dir => $fs->{dst});
	$w->endTag("filesystem");
    }
    foreach my $interface (@{$self->{interfaces}}) {
	$w->startTag("interface",
		     type => $interface->{type});

	$w->emptyTag("mac",
		     address =>  $interface->{mac});

	if( $interface->{dev}) {
	    $w->emptyTag("source",
			 dev => $interface->{dev},
			 mode => $interface->{mode});
	} else {
	    $w->emptyTag("source",
			 network => $interface->{source});
	}
	if( $interface->{virtualport}) {
	    $w->startTag("virtualport",
			 type => $interface->{virtualport});
	    $w->emptyTag("parameters",
			 managerid => '1',
			 typeid => '2',
			 typeidversion => '3',
			 instanceid => '40000000-0000-0000-0000-000000000000');
	    $w->endTag("virtualport");
	}
	$w->emptyTag("model",
		     type => $interface->{model});
	if( $interface->{filterref}) {
	    $w->emptyTag("filterref",
			 filter => $interface->{filterref});
	}
	$w->endTag("interface");
    }
    foreach my $graphic (@{$self->{graphics}}) {
	$w->startTag("graphics",
		     type => $graphic->{type});

	$w->emptyTag("port",
		     port => $graphic->{port});
	$w->emptyTag("autoport",
		     autoport => $graphic->{autoport});
	$w->emptyTag("listen",
		     listen => $graphic->{listen});
	$w->emptyTag("keymap",
		     keymap => $graphic->{keymap});
	$w->endTag("graphics");
    }
    $w->emptyTag("console", type => "pty");
    $w->endTag("devices");
    $w->endTag("domain");

    return $data;
}

1;
