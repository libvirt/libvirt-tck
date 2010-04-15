# -*- perl -*-
#
# Copyright (C) 2009, 2010 Red Hat, Inc.
# Copyright (C) 2009 Daniel P. Berrange
#
# This program is free software; You can redistribute it and/or modify
# it under the GNU General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any
# later version
#
# The file "LICENSE" distributed along with this file provides full
# details of the terms and conditions
#

use Test::More tests => 8;
use strict;
use warnings;

BEGIN {
      use_ok("Sys::Virt::TCK::StoragePoolBuilder");
}


my $xmlDir = <<EOF;
<pool type="dir">
  <name>tck</name>
  <source>
    <dir path="/var/lib/libvirt/images" />
  </source>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
chomp $xmlDir;

my $builtDir = Sys::Virt::TCK::StoragePoolBuilder->new()
   ->source_dir("/var/lib/libvirt/images")
   ->target("/var/lib/libvirt/images")
   ->as_xml;


is ($builtDir, $xmlDir);


my $xmlFS = <<EOF;
<pool type="fs">
  <name>tck</name>
  <source>
    <dev path="/dev/sda1" />
  </source>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
chomp $xmlFS;

my $builtFS = Sys::Virt::TCK::StoragePoolBuilder->new(type => "fs")
   ->source_device("/dev/sda1")
   ->target("/var/lib/libvirt/images")
   ->as_xml;


is ($builtFS, $xmlFS);


my $xmlNetFS = <<EOF;
<pool type="netfs">
  <name>tck</name>
  <source>
    <host name="nfs.example.com" />
    <dir path="/var/lib/libvirt/images" />
  </source>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
chomp $xmlNetFS;

my $builtNetFS = Sys::Virt::TCK::StoragePoolBuilder->new(type => "netfs")
   ->source_host("nfs.example.com")
   ->source_dir("/var/lib/libvirt/images")
   ->target("/var/lib/libvirt/images")
   ->as_xml;


is ($builtNetFS, $xmlNetFS);


my $xmlLogical = <<EOF;
<pool type="logical">
  <name>tck</name>
  <source>
    <dev path="/dev/sda1" />
    <dev path="/dev/sdb1" />
    <dev path="/dev/sdc1" />
    <name>tck</name>
  </source>
  <target>
    <path>/dev/tck</path>
  </target>
</pool>
EOF
chomp $xmlLogical;

my $builtLogical = Sys::Virt::TCK::StoragePoolBuilder->new(type => "logical")
   ->source_device("/dev/sda1", "/dev/sdb1", "/dev/sdc1")
   ->source_name("tck")
   ->target("/dev/tck")
   ->as_xml;


is ($builtLogical, $xmlLogical);


my $xmlDisk = <<EOF;
<pool type="disk">
  <name>tck</name>
  <source>
    <dev path="/dev/sda" />
  </source>
  <target>
    <path>/dev</path>
  </target>
</pool>
EOF
chomp $xmlDisk;

my $builtDisk = Sys::Virt::TCK::StoragePoolBuilder->new(type => "disk")
   ->source_device("/dev/sda")
   ->target("/dev")
   ->as_xml;


is ($builtDisk, $xmlDisk);


my $xmlSCSI = <<EOF;
<pool type="scsi">
  <name>tck</name>
  <source>
    <adapter name="scsi1" />
  </source>
  <target>
    <path>/dev</path>
  </target>
</pool>
EOF
chomp $xmlSCSI;

my $builtSCSI = Sys::Virt::TCK::StoragePoolBuilder->new(type => "scsi")
   ->source_adapter("scsi1")
   ->target("/dev")
   ->as_xml;


is ($builtSCSI, $xmlSCSI);


my $xmlISCSI = <<EOF;
<pool type="iscsi">
  <name>tck</name>
  <source>
    <host name="iscsi.example.com" />
    <dev path="tck.target" />
  </source>
  <target>
    <path>/dev</path>
  </target>
</pool>
EOF
chomp $xmlISCSI;

my $builtISCSI = Sys::Virt::TCK::StoragePoolBuilder->new(type => "iscsi")
   ->source_host("iscsi.example.com")
   ->source_device("tck.target")
   ->target("/dev")
   ->as_xml;


is ($builtISCSI, $xmlISCSI);


