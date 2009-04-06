use strict;
use warnings;
use Test::More tests => 7;

use Sys::Virt::TCK;

my $tck = Sys::Virt::TCK->new();
ok(defined $tck, "initialize tck");

END {
    $tck->cleanup if $tck;
}


my $xml = $tck->generic_domain("test")->as_xml;

my $conn = $tck->conn;

print "# Creating transient guest\n";
my $dom = $conn->create_domain($xml);

isa_ok($dom, "Sys::Virt::Domain", "defined domain");

my $livexml = $dom->get_xml_description();

print "# Defining config for transient guest\n";
my $dom1 = $conn->define_domain($livexml);
isa_ok($dom1, "Sys::Virt::Domain", "transient domain became permanent");

print "# Destroying running guest\n";
$dom->destroy;

$dom1 = $conn->get_domain_by_name("test");
isa_ok($dom1, "Sys::Virt::Domain", "domain still exists after destroy");

print "# Removing guest config\n";
$dom->undefine;


eval {
    my $dom1 = $conn->get_domain_by_name("test");
};
my $err = $@;
ok(defined $err, "error raised");
isa_ok($err, "Sys::Virt::Error");
is($err->code, 42, "NO_DOMAIN");
