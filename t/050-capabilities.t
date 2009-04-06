# -*- perl -*-

use Test::More tests => 77;

BEGIN {
      use_ok("Sys::Virt::TCK::Capabilities");
}


my $xencaps = <<EOF;
<capabilities>

  <host>
    <cpu>
      <arch>x86_64</arch>
      <features>
        <vmx/>
      </features>
    </cpu>
    <migration_features>
      <live/>
      <uri_transports>
        <uri_transport>xenmigr</uri_transport>
      </uri_transports>
    </migration_features>
    <topology>
      <cells num='1'>
        <cell id='0'>
          <cpus num='2'>
            <cpu id='0'/>
            <cpu id='1'/>
          </cpus>
        </cell>
      </cells>
    </topology>
  </host>

  <guest>
    <os_type>xen</os_type>
    <arch name='x86_64'>
      <wordsize>64</wordsize>
      <emulator>/usr/lib64/xen/bin/qemu-dm</emulator>
      <machine>xenpv</machine>
      <domain type='xen'>
      </domain>
    </arch>
  </guest>

  <guest>
    <os_type>xen</os_type>
    <arch name='i686'>
      <wordsize>32</wordsize>
      <emulator>/usr/lib64/xen/bin/qemu-dm</emulator>
      <machine>xenpv</machine>
      <domain type='xen'>
      </domain>
    </arch>
    <features>
      <pae/>
    </features>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='i686'>
      <wordsize>32</wordsize>
      <emulator>/usr/lib64/xen/bin/qemu-dm</emulator>
      <loader>/usr/lib/xen/boot/hvmloader</loader>
      <machine>xenfv</machine>
      <domain type='xen'>
      </domain>
    </arch>
    <features>
      <pae/>
      <nonpae/>
      <acpi default='on' toggle='yes'/>
      <apic default='on' toggle='yes'/>
    </features>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='x86_64'>
      <wordsize>64</wordsize>
      <emulator>/usr/lib64/xen/bin/qemu-dm</emulator>
      <loader>/usr/lib/xen/boot/hvmloader</loader>
      <machine>xenfv</machine>
      <domain type='xen'>
      </domain>
    </arch>
    <features>
      <acpi default='on' toggle='yes'/>
      <apic default='on' toggle='yes'/>
    </features>
  </guest>

</capabilities>
EOF

my $qemucaps = <<EOF;
<capabilities>

  <host>
    <cpu>
      <arch>x86_64</arch>
    </cpu>
    <topology>
      <cells num='2'>
        <cell id='0'>
          <cpus num='4'>
            <cpu id='0'/>
            <cpu id='1'/>
            <cpu id='2'/>
            <cpu id='3'/>
          </cpus>
        </cell>
        <cell id='1'>
          <cpus num='4'>
            <cpu id='4'/>
            <cpu id='5'/>
            <cpu id='6'/>
            <cpu id='7'/>
          </cpus>
        </cell>
      </cells>
    </topology>
    <secmodel>
      <model>selinux</model>
      <doi>0</doi>
    </secmodel>
  </host>

  <guest>
    <os_type>hvm</os_type>
    <arch name='i686'>
      <wordsize>32</wordsize>
      <emulator>/usr/bin/qemu</emulator>
      <machine>pc</machine>
      <machine>isapc</machine>
      <domain type='qemu'>
      </domain>
    </arch>
    <features>
      <pae/>
      <nonpae/>
      <acpi default='on' toggle='yes'/>
      <apic default='on' toggle='no'/>
    </features>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='x86_64'>
      <wordsize>64</wordsize>
      <emulator>/usr/bin/qemu-system-x86_64</emulator>
      <machine>pc</machine>
      <machine>isapc</machine>
      <domain type='qemu'>
      </domain>
      <domain type='kvm'>
        <emulator>/usr/bin/qemu-kvm</emulator>
      </domain>
    </arch>
    <features>
      <acpi default='on' toggle='yes'/>
      <apic default='on' toggle='no'/>
    </features>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='mips'>
      <wordsize>32</wordsize>
      <emulator>/usr/bin/qemu-system-mips</emulator>
      <machine>mips</machine>
      <domain type='qemu'>
      </domain>
    </arch>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='mipsel'>
      <wordsize>32</wordsize>
      <emulator>/usr/bin/qemu-system-mipsel</emulator>
      <machine>mips</machine>
      <domain type='qemu'>
      </domain>
    </arch>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='sparc'>
      <wordsize>32</wordsize>
      <emulator>/usr/bin/qemu-system-sparc</emulator>
      <machine>sun4m</machine>
      <domain type='qemu'>
      </domain>
    </arch>
  </guest>

  <guest>
    <os_type>hvm</os_type>
    <arch name='ppc'>
      <wordsize>32</wordsize>
      <emulator>/usr/bin/qemu-system-ppc</emulator>
      <machine>g3bw</machine>
      <machine>mac99</machine>
      <machine>prep</machine>
      <domain type='qemu'>
      </domain>
    </arch>
  </guest>

  <guest>
    <os_type>xen</os_type>
    <arch name='i686'>
      <wordsize>32</wordsize>
      <emulator>/usr/bin/xenner</emulator>
      <machine>xenner</machine>
      <domain type='kvm'>
      </domain>
    </arch>
    <features>
      <pae/>
      <nonpae/>
      <acpi default='on' toggle='yes'/>
      <apic default='on' toggle='no'/>
    </features>
  </guest>

  <guest>
    <os_type>xen</os_type>
    <arch name='x86_64'>
      <wordsize>64</wordsize>
      <emulator>/usr/bin/xenner</emulator>
      <machine>xenner</machine>
      <domain type='kvm'>
      </domain>
    </arch>
    <features>
      <acpi default='on' toggle='yes'/>
      <apic default='on' toggle='no'/>
    </features>
  </guest>

</capabilities>
EOF


my $c1  = Sys::Virt::TCK::Capabilities->new(xml => $xencaps);

isa_ok($c1, "Sys::Virt::TCK::Capabilities");
is($c1->host_cpu_arch, "x86_64", "host arch");
my @feat = $c1->host_cpu_features;
is_deeply(\@feat, ["vmx"], "host cpu fatures");

ok($c1->host_live_migration, "live migration");
my @uris = $c1->host_migration_transports;
is_deeply(\@uris, ["xenmigr"], "migration uris");


is($c1->host_topology_num_cells, 1, "1 numa cells");
my @cpus1 = $c1->host_topology_cpus_for_cell(0);
is_deeply(\@cpus1, [0, 1], "2 cpus in cell");



is($c1->num_guests, 4, "4 guests");
is($c1->guest_arch_name(0), "x86_64", "guest arch");
is($c1->guest_arch_name(1), "i686", "guest arch");
is($c1->guest_arch_name(2), "i686", "guest arch");
is($c1->guest_arch_name(3), "x86_64", "guest arch");

is($c1->guest_arch_wordsize(0), 64, "guest arch_wordsize");
is($c1->guest_arch_wordsize(1), 32, "guest arch_wordsize");
is($c1->guest_arch_wordsize(2), 32, "guest arch_wordsize");
is($c1->guest_arch_wordsize(3), 64, "guest arch_wordsize");

is($c1->guest_os_type(0), "xen", "guest os type");
is($c1->guest_os_type(1), "xen", "guest os type");
is($c1->guest_os_type(2), "hvm", "guest os type");
is($c1->guest_os_type(3), "hvm", "guest os type");

my @doms;
@doms = $c1->guest_domain_types(0);
is_deeply(\@doms, ["xen"], "guest domain types");
@doms = $c1->guest_domain_types(1);
is_deeply(\@doms, ["xen"], "guest domain types");
@doms = $c1->guest_domain_types(2);
is_deeply(\@doms, ["xen"], "guest domain types");
@doms = $c1->guest_domain_types(3);
is_deeply(\@doms, ["xen"], "guest domain types");


is($c1->guest_domain_emulator(0, "xen"), "/usr/lib64/xen/bin/qemu-dm", "emulator");
is($c1->guest_domain_loader(0, "xen"), undef, "no loader");
is($c1->guest_domain_emulator(2, "xen"), "/usr/lib64/xen/bin/qemu-dm", "emulator");
is($c1->guest_domain_loader(2, "xen"), "/usr/lib/xen/boot/hvmloader", "hvmloader");

my @macs;
@macs = $c1->guest_domain_machines(0, "xen");
is_deeply(\@macs, ["xenpv"], "guest machines");
@macs = $c1->guest_domain_machines(2, "xen");
is_deeply(\@macs, ["xenfv"], "guest machines");




my $c2  = Sys::Virt::TCK::Capabilities->new(xml => $qemucaps);
isa_ok($c2, "Sys::Virt::TCK::Capabilities");

is($c2->host_topology_num_cells, 2, "2 numa cells");
my @cpus21 = $c2->host_topology_cpus_for_cell(0);
my @cpus22 = $c2->host_topology_cpus_for_cell(1);
is_deeply(\@cpus21, [0, 1, 2, 3], "4 cpus in cell");
is_deeply(\@cpus22, [4, 5, 6, 7], "4 cpus in cell");


is($c2->host_secmodel, "selinux", "security model");
is($c2->host_secmodel_doi, 0, "security model doi");


is($c2->num_guests, 8, "8 guests");
is($c2->guest_arch_name(0), "i686", "guest arch");
is($c2->guest_arch_name(1), "x86_64", "guest arch");
is($c2->guest_arch_name(2), "mips", "guest arch");
is($c2->guest_arch_name(3), "mipsel", "guest arch");
is($c2->guest_arch_name(4), "sparc", "guest arch");
is($c2->guest_arch_name(5), "ppc", "guest arch");
is($c2->guest_arch_name(6), "i686", "guest arch");
is($c2->guest_arch_name(7), "x86_64", "guest arch");

is($c2->guest_arch_wordsize(0), 32, "guest arch_wordsize");
is($c2->guest_arch_wordsize(1), 64, "guest arch_wordsize");
is($c2->guest_arch_wordsize(2), 32, "guest arch_wordsize");
is($c2->guest_arch_wordsize(3), 32, "guest arch_wordsize");
is($c2->guest_arch_wordsize(4), 32, "guest arch_wordsize");
is($c2->guest_arch_wordsize(5), 32, "guest arch_wordsize");
is($c2->guest_arch_wordsize(6), 32, "guest arch_wordsize");
is($c2->guest_arch_wordsize(7), 64, "guest arch_wordsize");

is($c2->guest_os_type(0), "hvm", "guest os type");
is($c2->guest_os_type(1), "hvm", "guest os type");
is($c2->guest_os_type(2), "hvm", "guest os type");
is($c2->guest_os_type(3), "hvm", "guest os type");
is($c2->guest_os_type(4), "hvm", "guest os type");
is($c2->guest_os_type(5), "hvm", "guest os type");
is($c2->guest_os_type(6), "xen", "guest os type");
is($c2->guest_os_type(7), "xen", "guest os type");

@doms = sort { $a cmp $b } $c2->guest_domain_types(0);
is_deeply(\@doms, ["qemu"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(1);
is_deeply(\@doms, ["kvm", "qemu"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(2);
is_deeply(\@doms, ["qemu"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(3);
is_deeply(\@doms, ["qemu"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(4);
is_deeply(\@doms, ["qemu"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(5);
is_deeply(\@doms, ["qemu"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(6);
is_deeply(\@doms, ["kvm"], "guest domain types");
@doms = sort { $a cmp $b } $c2->guest_domain_types(7);
is_deeply(\@doms, ["kvm"], "guest domain types");


is($c2->guest_domain_emulator(0, "qemu"), "/usr/bin/qemu", "emulator");
is($c2->guest_domain_loader(0, "xen"), undef, "no loader");
is($c2->guest_domain_emulator(1, "qemu"), "/usr/bin/qemu-system-x86_64", "emulator");
is($c2->guest_domain_emulator(1, "kvm"), "/usr/bin/qemu-kvm", "emulator");
is($c2->guest_domain_emulator(6, "kvm"), "/usr/bin/xenner", "emulator");

@macs = sort { $a cmp $b } $c2->guest_domain_machines(0, "qemu");
is_deeply(\@macs, ["isapc", "pc"], "guest machines");
@macs = sort { $a cmp $b } $c2->guest_domain_machines(2, "qemu");
is_deeply(\@macs, ["mips"], "guest machines");


