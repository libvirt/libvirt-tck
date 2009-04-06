#!/usr/bin/perl
#

use ExtUtils::MakeMaker;

WriteMakefile(
              'NAME' => 'Sys::Virt::TCK',
              'VERSION_FROM' => 'lib/Sys/Virt/TCK.pm',
              'PREREQ_PM' => {
		  'App::Prove' => 3.11,
		  'Config::Record' => 0,
		  'IO::String' => 0,
                  'Sys::Virt' => 0.2.0,
		  'TAP::Formatter::HTML' => 0,
		  'TAP::Harness' => 3.11,
		  'TAP::Harness::Archive' => 0,
                  'Test::More'  => 0,
                  'XML::Twig' => 0,
		  'XML::Writer' => 0,
                  },
              'AUTHOR' => 'Daniel Berrange <dan@berrange.com>',
              'NO_META' => 1,
              'depend' => {
                  Sys-Virt-TCK.spec => '$(VERSION_FROM)',
                  Makefile => '$(VERSION_FROM)',
              },
              'realclean' => {
                  FILES => 'Sys-Virt-TCK.spec',
              },
);

package MY;

sub libscan
  {
    my ($self, $path) = @_;
    ($path =~ /\~$/ || $path =~ m,/CVS/,) ? undef : $path;
  }

__END__

