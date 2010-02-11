# -*- perl -*-

use Test::More tests => 2;

BEGIN {
      use_ok("Sys::Virt::TCK::DomainBuilder");
}


my $xml = <<EOF;
<domain type="xen">
  <name>tck</name>
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
      <driver name="qemu" type="qcow2" />
      <source dev="/dev/hda1" />
      <target dev="/dev/xvda" bus="xen" />
      <encryption format="qcow">
        <secret type="passphrase" uuid="0a81f5b2-8403-7b23-c8d6-21ccc2f80d6f" />
      </encryption>
    </disk>
    <console type="pty" />
  </devices>
</domain>
EOF
chomp $xml;

my $conn = Sys::Virt->new(address => "test:///default");

my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $conn, domain => "xen", ostype => 'hvm')
    ->with_acpi->memory(500*1025)->vcpu(3)
    ->disk(format => ["qemu", "qcow2"], type => 'block', src => "/dev/hda1", dst => "/dev/xvda", bus => "xen", secret => "0a81f5b2-8403-7b23-c8d6-21ccc2f80d6f")
    ->as_xml;


is ($b, $xml);
