#
# Copyright (C) 2010 Red Hat, Inc.
# Copyright (C) 2010 Osier Yang <jyang@redhat.com>
#
# This program is free software; You can redistribute it and/or modify
# it under the GNU General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any
# later version
#
# The file "LICENSE" distributed along with this file provides full
# details of the terms and conditions
#

package Sys::Virt::TCK::Hooks;

use strict;
use warnings;

use Fcntl ':mode';
use POSIX qw(strftime);
use File::Slurp;

my $HOOKS_CONF_DIR="/etc/libvirt/hooks";

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    my $type = $params{type} ? $params{type} : die "type parameter is required";

    $self = {
        type => $type,
        conf_dir => $params{conf_dir} ? $params{conf_dir} : $HOOKS_CONF_DIR,
        name => $params{conf_dir}.'/'.$params{type},
        expect_result => $params{expect_result} ? $params{expect_result} : 0,
        log_name => $params{log_name} ? $params{log_name} : "/tmp/$params{type}.log",
        libvirtd_status => undef,
        domain_name => undef,
        domain_state => undef,
        expect_log => undef,
        action => undef,
    };

    bless $self, $class;

    return $self;
}

sub log_name {
    my $self = shift;
    my $log_name = shift;

    die "log_name parameter is required" unless $log_name;

    $self->{log_name} = $log_name;
}

sub expect_result {
    my $self = shift;
    my $expect_result = shift;

    die "expect_result parameter is required" unless $expect_result;

    $self->{expect_result} = $expect_result;

    return $self;
}

sub libvirtd_status {
    my $self = shift;
    my $status = `service libvirtd status`;
    my $_ = $status;

    if (/stopped|unused|inactive/) {
        $self->{libvirtd_status} = 'stopped';
    } elsif (/running|active/) {
        $self->{libvirtd_status} = 'running';
    }

    return $self;
}

sub domain_name {
    my $self = shift;
    my $domain_name = shift;

    die "domain_name parameter is required" unless $domain_name;

    $self->{domain_name} = $domain_name;

    return $self;
}

sub domain_state {
    my $self = shift;
    my $domain_state = shift;

    die "domain_state parameter is required" unless $domain_state;

    $self->{domain_state} = $domain_state;

    return $self;
}

sub action {
    my $self = shift;
    my $action = shift;

    die "action parameter is required" unless $action;

    $self->{action} = $action;

    return $self;
}

sub expect_log {
    my $self = shift;
    my $expect_log = undef;

    my $hook = $self->{name};
    my $action = $self->{action};
    my $domain_name = $self->{domain_name};
    my $domain_state = $self->{domain_state};
    my $libvirtd_status = $self->{libvirtd_status};

    if ($self->{type} eq 'daemon') {
        if ($libvirtd_status eq 'running') {
            if ($action eq 'stop') {
                $expect_log = "$hook - shutdown - shutdown";
            } elsif ($action eq 'restart') {
                $expect_log = "$hook - shutdown - shutdown\n$hook - start - start";
            } elsif ($action eq 'reload') {
                $expect_log = "$hook - reload begin SIGHUP";
            } else {
                die "hooks testing doesn't support $action running libvirtd";
            }
        } else {
            if ($action eq 'start') {
                $expect_log = "$hook - start - start";
            } else {
                die "hooks testing doesn't support $action stopped libvirtd";
            }
        }
    } elsif ($self->{type} eq 'qemu' or $self->{type} eq 'lxc') {
        if ($domain_state eq &Sys::Virt::Domain::STATE_RUNNING) {
            if ($action eq 'destroy') {
                $expect_log = "$hook $domain_name stopped end -\n".
                              "$hook $domain_name release end -";
            } else {
                die "hooks testing doesn't support $action running domain";
            }
        } elsif ($domain_state eq &Sys::Virt::Domain::STATE_SHUTOFF) {
            if ($action eq 'start') {
                $expect_log = "$hook $domain_name prepare begin -\n".
                              "$hook $domain_name start begin -\n".
                              "$hook $domain_name started begin -";
            } elsif ($action eq 'failstart') {
                $expect_log = "$hook $domain_name prepare begin -\n".
                              "$hook $domain_name stopped end -\n".
                              "$hook $domain_name release end -";
            } else {
                die "hooks testing doesn't support $action shutoff domain";
            }

        } else {
            die "hooks testing doesn't support to test a domain in $domain_state state";
        }
    } else {
            die "hooks only support 'qemu' and 'lxc' currently";
    }

    $self->{expect_log} = $expect_log;

    return $self;
}

sub create_hooks_dir {
    my $self = shift;

    unless (-d $self->{conf_dir}) {
        mkdir $self->{conf_dir} or die "failed to create $self->{conf_dir}: $!";
    }
}

sub backup_hook {
    my $self = shift;
    my $date = undef;

    $date = strftime "%Y-%m-%d-%H:%M:%S", localtime;
    my $orig = $self->{name};
    my $dest = $orig."-$date";

    rename $orig, $dest;
}

sub create_hook {
    my $self = shift;
    my $hook = $self->{name};

    $self->backup_hook;

    open HOOK, "> $hook" or die "failed on opening $hook: $!";

    my $str = <<EOF;
#! /bin/bash
echo "\$0" "\$@" >>$self->{log_name}
exit $self->{expect_result}
EOF

    print HOOK $str;
    close HOOK;

    my $mode = (stat($hook))[2];
    chmod($mode | S_IXUSR, $hook) unless -x $hook;
}

sub prepare {
    my $self = shift;

    $self->create_hooks_dir;
    $self->backup_hook;
    $self->create_hook;

    unlink $self->{log_name} if -f $self->{log_name};

    return $self;
}

sub cleanup {
    my $self = shift;
    my $name = $self->{name};

    unlink $name;
    unlink $self->{log_name} if -f $self->{log_name};
}

sub service_libvirtd {
    my $self = shift;
    my $action = $self->{action};

    truncate $self->{log_name}, 0 if -f $self->{log_name};

    die "failed on $action daemon" if system "service libvirtd $action";

    $self->libvirtd_status;
}

sub compare_log {
    my $self = shift;

    my $expect_log = $self->{expect_log};
    my $log_name = $self->{log_name};

    my $actual_log = read_file($log_name);
    chomp $actual_log;

    return 0 unless defined($actual_log);

    ($expect_log eq $actual_log) ? 1 : 0;
}

1;
