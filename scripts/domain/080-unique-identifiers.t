# -*- perl -*-

use strict;
use warnings;
use Test::More tests => 16;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
ok(defined $tck, "initialize tck");

END {
    $tck->cleanup if $tck;
}


my $xml1 = $tck->generic_domain("test1")->uuid("11111111-1111-1111-1111-111111111111")->as_xml;
my $xml2 = $tck->generic_domain("test1")->uuid("22222222-1111-1111-1111-111111111111")->as_xml;
my $xml3 = $tck->generic_domain("test2")->uuid("11111111-1111-1111-1111-111111111111")->as_xml;

my $conn = $tck->conn;

my $dom = $conn->define_domain($xml1);

isa_ok($dom, "Sys::Virt::Domain", "defined domain");
is($dom->get_name, "test1", "name is test1");
#$dom->DESTROY;

diag "Trying to define a guest with same name, different UUID";
eval {
    $conn->define_domain($xml2);
};
my $err = $@;
ok(defined $err, "error raised");
isa_ok($err, "Sys::Virt::Error");
is($err && $err->code, 9, "OPERATION_FAILED");

# This should cause a rename of the guest...
diag "Trying to define a guest with same UUID, different name";
$dom = $conn->define_domain($xml3);
isa_ok($dom, "Sys::Virt::Domain", "defined domain");
is($dom->get_name, "test2", "name is test2");
#$dom->DESTROY;

diag "Checking that domain test1 has now gone";
eval {
    $conn->get_domain_by_name("test1");
};
$err = $@;
ok($err, "error raised");
isa_ok($err, "Sys::Virt::Error");
is($err && $err->code, 42, "NO_DOMAIN");



diag "Checking the guest really was renamed";
$dom = $conn->get_domain_by_name("test2");
isa_ok($dom, "Sys::Virt::Domain", "defined domain");
is($dom->get_name, "test2", "name is test2");

$dom->undefine;
#$dom->DESTROY;


diag "Checking that domain test2 has now gone";
eval {
    $conn->get_domain_by_name("test2");
};
$err = $@;
ok($err, "error raised");
isa_ok($err, "Sys::Virt::Error");
is($err && $err->code, 42, "NO_DOMAIN");
