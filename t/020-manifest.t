# -*- perl -*-
use strict;
use warnings;

use ExtUtils::Manifest qw(filecheck);
use FindBin;
use Test::More tests => 1;

chdir "$FindBin::Bin/.." or die "cannot change to distribution root: $!";

local $ExtUtils::Manifest::Quiet = 1;
my @missing = sort grep { /\.t$/ } filecheck();

ok(!@missing, "all test files are listed in MANIFEST");
diag("Test files missing from MANIFEST:\n  " . join("\n  ", @missing))
    if @missing;
