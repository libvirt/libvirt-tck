#
# Copyright (C) 2009 Red Hat, Inc.
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

package Sys::Virt::TCK::Capabilities;

use strict;
use warnings;

use XML::Twig;


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $self = {};

    my $xml = $params{xml};
    die "xml parameter is required" unless defined $xml;

    bless $self, $class;

    $self->parse($xml);

    return $self;
}


sub parse {
    my $self = shift;
    my $xml = shift;

    my $twig = XML::Twig->new();
    $twig->parse($xml);

    $self->{host} = {};
    $self->{guests} = [];

    $self->_parse_capabilities($twig->root);
}


sub _parse_capabilities {
    my $self = shift;
    my $node = shift;

    my $host = $node->first_child("host");
    $self->_parse_host($host) if $host;

    foreach my $child ($node->children("guest")) {
	$self->_parse_guest($child);
    }
}

sub _parse_host {
    my $self = shift;
    my $node = shift;

    my $cpu = $node->first_child("cpu");
    $self->_parse_host_cpu($cpu) if $cpu;

    my $mig = $node->first_child("migration_features");
    $self->_parse_host_migration($mig) if $mig;

    my $top = $node->first_child("topology");
    $self->_parse_host_topology($top) if $top;

    my $sec = $node->first_child("secmodel");
    $self->_parse_host_secmodel($sec) if $sec;
}


sub _parse_host_cpu {
    my $self = shift;
    my $node = shift;

    my $cpu = {};

    my $arch = $node->first_child_text("arch");
    $cpu->{arch} = $arch if $arch;

    my $feat = $node->first_child("features");
    if (defined $feat) {
	$cpu->{features} = {};
	foreach my $child ($feat->children()) {
	    my $name = $child->name;
	    $cpu->{features}->{$name} = 1;
	}
    }

    $self->{host}->{cpu} = $cpu;
}


sub _parse_host_migration {
    my $self = shift;
    my $node = shift;

    my $mig = {};

    my $live = $node->first_child("live");

    $mig->{live} = defined $live ? 1 : 0;

    $mig->{transports} = [];
    my $trans = $node->first_child("uri_transports");
    if (defined $trans) {
	foreach my $child ($trans->children("uri_transport")) {
	    push @{$mig->{transports}}, $child->text;
	}
    }

    $self->{host}->{migration} = $mig;
}


sub _parse_host_topology {
    my $self = shift;
    my $node = shift;

    my $top = [];

    my $cells = $node->first_child("cells");
    return unless $cells;

    my @cells;
    foreach my $cell ($cells->children("cell")) {
	my $topcell = [];
	push @{$top}, $topcell;

	my $cpus = $cell->first_child("cpus");
	next unless $cpus;

	foreach my $cpu ($cpus->children("cpu")) {
	    my $id = $cpu->att("id");
	    push @{$topcell}, $id;
	}
    }

    $self->{host}->{topology} = $top;
}

sub _parse_host_secmodel {
    my $self = shift;
    my $node = shift;

    my $sec = {
	model => $node->first_child_text("model"),
	doi => $node->first_child_text("doi"),
    };

    $self->{host}->{secmodel} = $sec;
}

sub _parse_guest {
    my $self = shift;
    my $node = shift;

    my $guest = {};

    $guest->{os_type} = $node->first_child_text("os_type");

    my $arch = $node->first_child("arch");
    my $wordsize = $arch->first_child_text("wordsize");

    $guest->{arch} = {
	name => $arch->att("name"),
	wordsize => $wordsize,
	domains => {},
    };

    my $defemu = $arch->first_child("emulator") ? $arch->first_child_text("emulator") : undef;
    my $defload = $arch->first_child("loader") ? $arch->first_child_text("loader") : undef;
    my @defmachines = ();
    foreach my $child ($arch->children("machine")) {
	push @defmachines, $child->text;
    }

    foreach my $dom ($arch->children("domain")) {
	my $emu = $dom->first_child("emulator") ? $dom->first_child_text("emulator") : undef;
	my $load = $dom->first_child("loader") ? $dom->first_child_text("loader") : undef;
	my @machines = ();
	foreach my $child ($dom->children("machine")) {
	    push @machines, $child->text;
	}
	$emu = $defemu unless $emu;
	$load = $defload unless $load;
	@machines = @defmachines unless @machines;

	my $type = $dom->att("type");
	$guest->{arch}->{domains}->{$type} = {
	    emulator => $emu,
	    loader => $load,
	    machines => \@machines,
	};
    }


    $guest->{features} = {};
    my $features = $node->first_child("features");
    if ($features) {
	foreach my $child ($features->children) {
	    $guest->{features}->{$child->name} = 1;
	}
    }

    push @{$self->{guests}}, $guest;
}


sub host_cpu_arch {
    my $self = shift;

    return $self->{host}->{cpu}->{arch};
}

sub host_cpu_features {
    my $self = shift;

    return keys %{$self->{host}->{cpu}->{features}};
}


sub host_live_migration {
    my $self = shift;
    return $self->{host}->{migration}->{live};
}


sub host_migration_transports {
    my $self = shift;
    return @{$self->{host}->{migration}->{transports}};
}


sub host_topology_num_cells {
    my $self = shift;

    return $#{$self->{host}->{topology}} + 1;
}


sub host_topology_cpus_for_cell {
    my $self = shift;
    my $cell = shift;

    return @{$self->{host}->{topology}->[$cell]};
}


sub host_secmodel {
    my $self = shift;

    return undef unless exists $self->{host}->{secmodel};

    return $self->{host}->{secmodel}->{model};
}

sub host_secmodel_doi {
    my $self = shift;

    return $self->{host}->{secmodel}->{doi};
}

sub num_guests {
    my $self = shift;

    return $#{$self->{guests}} + 1;
}

sub guest_os_type {
    my $self = shift;
    my $guest = shift;

    return $self->{guests}->[$guest]->{os_type};
}

sub guest_arch_name {
    my $self = shift;
    my $guest = shift;

    return $self->{guests}->[$guest]->{arch}->{name};
}

sub guest_arch_wordsize {
    my $self = shift;
    my $guest = shift;

    return $self->{guests}->[$guest]->{arch}->{wordsize};
}

sub guest_domain_types {
    my $self = shift;
    my $guest = shift;

    return keys %{$self->{guests}->[$guest]->{arch}->{domains}};
}

sub guest_domain_emulator {
    my $self = shift;
    my $guest = shift;
    my $domain = shift;

    return $self->{guests}->[$guest]->{arch}->{domains}->{$domain}->{emulator};
}

sub guest_domain_loader {
    my $self = shift;
    my $guest = shift;
    my $domain = shift;

    return $self->{guests}->[$guest]->{arch}->{domains}->{$domain}->{loader};
}

sub guest_domain_machines {
    my $self = shift;
    my $guest = shift;
    my $domain = shift;

    return @{$self->{guests}->[$guest]->{arch}->{domains}->{$domain}->{machines}};
}


1;

