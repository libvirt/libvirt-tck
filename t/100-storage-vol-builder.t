# -*- perl -*-

use Test::More tests => 2;

BEGIN {
      use_ok("Sys::Virt::TCK::StorageVolBuilder");
}


my $xml = <<EOF;
<volume>
  <name>test</name>
  <capacity>1000000</capacity>
  <allocation>1000000</allocation>
  <target>
    <format type="qcow2" />
  </target>
</volume>
EOF
chomp $xml;

my $b = Sys::Virt::TCK::StorageVolBuilder->new()
    ->capacity(1000000)->allocation(1000000)
    ->format("qcow2")
    ->as_xml;


is ($b, $xml);
