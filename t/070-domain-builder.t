# -*- perl -*-

use Test::More tests => 2;

BEGIN {
      use_ok("Sys::Virt::TCK::DomainBuilder");
}


my $xml = <<EOF;
<domain type="xen">
  <name>test</name>
  <memory>512500</memory>
  <currentMemory>512500</currentMemory>
  <vcpu>3</vcpu>
  <os>
    <type>hvm</type>
    <boot dev="hd" />
  </os>
  <features>
    <acpi />
  </features>
  <devices>
    <disk type="block">
      <source dev="/dev/hda1" />
      <target dev="/dev/xvda" bus="xen" />
    </disk>
  </devices>
</domain>
EOF
chomp $xml;

my $conn = Sys::Virt->new(address => "test:///default");

my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $conn)
    ->with_acpi->memory(500*1025)->vcpu(3)
    ->disk(type => 'block', src => "/dev/hda1", dst => "/dev/xvda", bus => "xen")
    ->as_xml;


is ($b, $xml);
