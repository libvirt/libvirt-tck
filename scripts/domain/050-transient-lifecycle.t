use strict;
use warnings;
use Test::More tests => 5;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
ok(defined $tck, "initialize tck");

END {
    $tck->cleanup if $tck;
}


my $xml = $tck->generic_domain("test")->as_xml;

my $conn = $tck->conn;

my $dom = $conn->create_domain($xml);

isa_ok($dom, "Sys::Virt::Domain", "defined domain");

$dom->destroy;

eval {
    my $dom1 = $conn->get_domain_by_name("test");
};
my $err = $@;
ok(defined $err, "error raised");
isa_ok($err, "Sys::Virt::Error");
is($err->code, 42, "NO_DOMAIN");
