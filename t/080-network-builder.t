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

use Test::More tests => 2;

BEGIN {
      use_ok("Sys::Virt::TCK::NetworkBuilder");
}


my $xml = <<EOF;
<network>
  <name>tck</name>
  <bridge name="virbr0" />
  <forward dev="eth0" />
  <ip address="192.168.100.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.100.50" end="192.168.100.70" />
      <range start="192.168.100.200" end="192.168.100.250" />
    </dhcp>
  </ip>
</network>
EOF
chomp $xml;

my $b = Sys::Virt::TCK::NetworkBuilder->new()
    ->forward(dev => 'eth0')->bridge("virbr0")
    ->ipaddr("192.168.100.1", "255.255.255.0")
    ->dhcp_range("192.168.100.50", "192.168.100.70")
    ->dhcp_range("192.168.100.200", "192.168.100.250")
    ->as_xml;


is ($b, $xml);
