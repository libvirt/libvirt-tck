#!/usr/bin/perl
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

use Module::Build;

my $class = Module::Build->subclass(code => <<'EOF');
use File::Find;
use File::Spec;

# This seems stupidly complex. There must be a easier
# way to recursively copy 'scripts/*' to 'blib/tck/'
sub process_pkgdata_files {
    my $self = shift;

    my %tck_dirs;
    my $wanted = sub {
        my $dir = $File::Find::dir;
        my $name = $File::Find::name;
        if (-d) {
            $tck_dirs{$name} = [];
        } elsif (-f && /\.(t|sh|fwall|xml|dat)$/) {
            push @{$tck_dirs{$dir}}, $name;
        }
    };

    find($wanted, 'scripts');

    my $tck_dir = File::Spec->catdir($self->blib, 'pkgdata');
    File::Path::mkpath($tck_dir);

    foreach my $srcdir (keys %tck_dirs) {
        next unless @{$tck_dirs{$srcdir}};

        my $dstdir = $srcdir;
        $dstdir =~ s,scripts/,,;

        $dstdir = File::Spec->catdir($self->blib, 'pkgdata', $dstdir);
        File::Path::mkpath($dstdir);

        foreach my $file (@{$tck_dirs{$srcdir}}) {
            my $result = $self->copy_if_modified(from => $file,
                                                 to_dir => $dstdir,
                                                 flatten => 1);
        }
    }
}

EOF

my $b = $class->new(
    module_name => "Sys::Virt::TCK",
    license => 'gpl',
    configure_requires => {
       'Module::Build' => 0,
    },
    dist_author => 'Daniel Berrange <dan@berrange.com>',
    dist_abstract => 'libvirt Technology Compatability Kit',
    requires => {
        'perl' => '5.8.0',
        'accessors' => 0,
        'App::Prove' => '3.11',
        'Cwd' => 0,
        'Digest' => 0,
        'Digest::MD5' => 0,
        'File::Copy' => 0,
        'File::Path' => 0,
        'File::Slurp' => 0,
        'File::Spec::Functions' => 0,
        'LWP::UserAgent' => 0,
        'IO::String' => 0,
        'IO::Uncompress::Gunzip' => 0,
        'IO::Uncompress::Bunzip2' => 0,
        'NetAddr::IP' => 0,
        'TAP::Formatter::HTML' => 0,
        'TAP::Formatter::JUnit' => 0,
        'TAP::Harness' => 3.11,
        'TAP::Harness::Archive' => 0,
        'Test::Exception' => 0,
        'Test::Builder' => 0,
        'Test::More' => 0,
        'Sub::Uplevel' => 0,
        'Sys::Virt' => '0.2.0',
        'XML::Twig' => 0,
        'XML::Writer' => 0,
        'XML::XPath' => 0,
        'YAML' => 0,
    },
    build_requires => {
        'Test::Pod' => '0',
	'Test::Pod::Coverage' => '0',
	'Test::CPAN::Changes' => '0',
    },
    script_files => [
        "bin/libvirt-tck",
    ],
    meta_add => {
        resources => {
            license => "https://www.gnu.org/licenses/gpl.html",
            homepage =>  "https://libvirt.org/",
            repository => "https://libvirt.org/git/?p=libvirt-tck.git;a=summary",
            MailingList => "https://www.redhat.com/mailman/listinfo/libvir-list",
        },
    },
    conf_files => {
        'conf/default.yml' => 'conf/default.yml',
    },
    PL_files => { 'perl-Sys-Virt-TCK.spec.PL' => 'perl-Sys-Virt-TCK.spec' },
    );
$b->add_build_element("conf");
$b->add_build_element("pkgdata");
$b->install_path('conf' => File::Spec->catdir($b->install_base, "etc", "libvirt-tck"));
$b->install_path('pkgdata' => File::Spec->catdir($b->install_base, "usr/share", "libvirt-tck", "tests"));
$b->create_build_script;
