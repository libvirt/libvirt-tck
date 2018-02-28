use Sys::Virt::TCK qw(xpath);
use NetAddr::IP qw(:lower);
use strict;
use utf8;

sub get_first_macaddress {
    my $dom = shift;
    my $mac = xpath($dom, "string(/domain/devices/interface[1]/mac/\@address)");
    utf8::encode($mac);
    return $mac;
}

sub get_network_ip {
    my $conn = shift;
    my $netname = shift;
    diag "getting ip for network $netname";
    my $net = $conn->get_network_by_name($netname);
    my $net_ip = xpath($net, "string(/network/ip[1]/\@address");
    my $net_mask = xpath($net, "string(/network/ip[1]/\@netmask");
    my $net_prefix = xpath($net, "string(/network/ip[1]/\@prefix");
    my $ip;

    if ($net_mask) {
        $ip = NetAddr::IP->new($net_ip, $net_mask);
    } elsif ($net_prefix) {
        $ip = NetAddr::IP->new("$net_ip/$net_mask");
    } else {
        $ip = NetAddr::IP->new("$net_ip");
    }
    return $ip;
}


sub get_ip_from_leases{
    my $conn = shift;
    my $netname = shift;
    my $mac = shift;

    my $net = $conn->get_network_by_name($netname);
    if ($net->can('get_dhcp_leases')) {
        my @leases = $net->get_dhcp_leases($mac);
        return @leases ? @leases[0]->{'ipaddr'} : undef;
    }

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
