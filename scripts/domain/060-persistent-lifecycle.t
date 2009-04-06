use strict;
use warnings;
use Test::More tests => 14;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
ok(defined $tck, "initialize tck");

END {
    $tck->cleanup if $tck;
}


my $xml = $tck->generic_domain("test")->as_xml;

my $conn = $tck->conn;

my $dom = $conn->define_domain($xml);

isa_ok($dom, "Sys::Virt::Domain", "defined domain");

$dom->undefine;
$dom->DESTROY;
$dom = undef;

eval {
    my $dom1 = $conn->get_domain_by_name("test");
};
my $err = $@;
ok(defined $err, "domain gone after undefine");
isa_ok($err, "Sys::Virt::Error");
is($err->code, 42, "error code is NO_DOMAIN");



$dom = $conn->define_domain($xml);
isa_ok($dom, "Sys::Virt::Domain", "defined domain again");

$dom->create;
ok($dom->get_id() > 0, "running domain ID > 0");


my $dom1 = $conn->get_domain_by_name("test");
isa_ok($dom1, "Sys::Virt::Domain", "got the running domain");
ok($dom1->get_id() > 0, "running domain ID > 0");


$dom->destroy();


$dom1 = $conn->get_domain_by_name("test");
isa_ok($dom1, "Sys::Virt::Domain", "got the inactive domain");
is($dom1->get_id(), -1 , "inactive domain ID == -1");


$dom->undefine;

eval {
    $dom1 = $conn->get_domain_by_name("test");
};
$err = $@;
ok(defined $err, "domain gone after undefine");
isa_ok($err, "Sys::Virt::Error");
is($err->code, 42, "error code is NO_DOMAIN");
