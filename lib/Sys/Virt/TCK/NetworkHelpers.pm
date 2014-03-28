use Sys::Virt::TCK qw(xpath);
use strict;
use utf8;

sub get_first_macaddress {
    my $dom = shift;
    my $mac = xpath($dom, "string(/domain/devices/interface[1]/mac/\@address)");
    utf8::encode($mac);
    return $mac;
}

sub get_ip_from_leases{
    my $mac = shift;
    my $tmp = `grep $mac /var/lib/libvirt/dnsmasq/default.leases`;
    my @fields = split(/ /, $tmp);
    my $ip = $fields[2];
    return $ip;
}


sub shutdown_vm_gracefully {
    my $dom = shift;

    my $target = time() + 30;
    $dom->shutdown;
    while ($dom->is_active()) {
	sleep(1);
	diag ".. waiting for virtual machine to shutdown.. ";
	$dom->destroy() if time() > $target;
    }
    sleep(1);
    diag ".. shutdown complete.. ";
}

1;
