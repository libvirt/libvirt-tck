# Copyright (C) 2008 Daniel Berrange <dan@berrange.com>

use strict;
use warnings;

die unless (scalar @ARGV == 1);

open SRC, "lib/Sys/Virt/TCK.pm"
    or die "lib/Sys/Virt/TCK.pm: $!";

our $VERSION;
while (<SRC>) {
    if (/\$VERSION\s*=\s*'(.*)'/) {
        $VERSION=$1;
    }
}
close SRC;

local $/ = undef;
$_ = <DATA>;
s/\@VERSION\@/$VERSION/g;

open SPEC, ">$ARGV[0]" or die "$!";
print SPEC $_;
close SPEC;
__DATA__
--- #YAML:1.0
name:                Sys-Virt-TCK
version:             @VERSION@
abstract:            libvirt Technology Compatability Kit
license:             GPLv2+
author:
    - Daniel Berrange <dan@berrange.com>
generated_by:        ExtUtils::MakeMaker version 6.42
distribution_type:   module
requires:
    App::Prove:                    3.11
    Config::Record:                0
    IO::String:                    0
    TAP::Formatter::HTML:          0
    TAP::Harness:                  3.11
    TAP::Harness::Archive:         0
    Sys::Virt:                     0.2.0
    XML::Twig:                     0
    XML::Writer:                   0
build_requires:
    Test::More:                    0
    Test::Pod:                     0
    Test::Pod::Coverage:           0


resources:
    license: http://www.gnu.org/licenses/gpl.html
    homepage: http://libvirt.org/
    repository: http://libvirt.org/hg/libvirt-tck
    MailingList: http://www.redhat.com/mailman/listinfo/libvir-list

meta-spec:
    version: 1.4
    url: http://module-build.sourceforge.net/META-spec-v1.4.html
