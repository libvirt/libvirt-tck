# -*- perl -*-
use strict;
use warnings;
use Test::More;
eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
plan skip_all => "Haven't written POD yet";
all_pod_coverage_ok()
