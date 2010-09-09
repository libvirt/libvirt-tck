use XML::LibXML;
use utf8;
use strict;


sub get_first_macaddress {
    my $dom = shift;
    my $result = xpath($dom, "/domain/devices/interface/mac/\@address");
    my @macaddrs = map { $_->getNodeValue} $result->get_nodelist;
# we want the first mac
    my $mac = $macaddrs[0];
    utf8::decode($mac);
    return $mac;
}

sub get_ip_from_leases{
    my $mac = shift;
    my $tmp = `grep $mac /var/lib/dnsmasq/dnsmasq.leases`;
    my @fields = split(/ /, $tmp);
    my $ip = $fields[2];
    return $ip;
}

sub build_and_boot_domain{
    my $tck = shift;
    my $conn = shift;
    my $disk_path = shift;
    my $boot_from_disk = shift;

    my $install_guest;
    my $mac = "52:54:00:11:11:11";
    my $model = "virtio";
    my $filterref = "no-spoofing";
    my $network = "network";
    my $source = "default";

    # prepare to boot install kernel and do a network installation
    if ($boot_from_disk == 0) {
	$install_guest = $tck->generic_domain("tckinst");
	my $kickstart_file ="http://192.168.122.1/ks.cfg";
	my $cmdline = "ip=dhcp gateway=192.168.122.1 ks=${kickstart_file}";
	$install_guest->boot_cmdline($cmdline);
	$install_guest->interface(type => $network,
				  source => $source,
				  model => $model,
				  mac => $mac);
    } else {
	# prepare to boot from disk
	$install_guest = $tck->generic_domain("tckboot");
	$install_guest->clear_kernel_initrd_cmdline();
	$install_guest->interface(type => $network,
				  source => $source,
				  model => $model,
				  mac => $mac,
				  filterref => $filterref);
    }
    # common configuration
    $install_guest->maxmem("524288");
    $install_guest->memory("524288");
    # replace disk from generic_domain with our own
    $install_guest->rmdisk();
    $install_guest->disk(src => $disk_path,
			 dst => "sda",
			 type=> "file");
    $install_guest->graphics(type => "vnc",
			     port => "-1",
			     autoport => "yes",
			     listen => "127.0.0.1",
			     keymap => "de");

    my $guest_xml = $install_guest->as_xml;
    diag $guest_xml;
    diag "defining guest";
    my $domtest = undef;
    $domtest = $conn->define_domain($guest_xml);
    my $xmltest = $domtest->get_xml_description;
    diag $xmltest;
    return $domtest;
}
sub shutdown_vm_gracefully{
    my $dom = shift;

    $dom->shutdown;
    while($dom->is_active()) {
	sleep(1);
	diag ".. waiting for virtual machine to shutdown.. ";
    }
    sleep(1);
    diag ".. shutdown complete.. ";
}

sub  prepare_test_disk_and_vm{
my $tck = shift;
my $conn = shift;
my $domain_name = shift;
my $disk_size = "2147483648";

# find disk or create new one
my ($disk_path, $installed) = create_disk_if_not_exists($tck, $conn, "${domain_name}.img", $disk_size);

# if it is new we have to install it
my $boot_from_disk = 0;
if($installed == 0) {
    my $testdom = build_and_boot_domain($tck, $conn, $disk_path, $boot_from_disk);
    $testdom->create();
    diag "wait for installation to finish .. ";
    while($testdom->is_active()) {
	sleep(10);
	diag ".. to view progress connect to virtual machine ${domain_name} .. ";
    }
    # cleanup install domain
    $testdom->undefine;
    $testdom = undef;
    sleep (10);
    diag " .. done";
    }
# now the disk is installed and we can boot it
$boot_from_disk = 1;
my $testdom = build_and_boot_domain($tck, $conn, $disk_path, $boot_from_disk);
return $testdom;
}

sub create_disk_if_not_exists{
    my $tck = shift;
    my $conn = shift;
    my $name = shift;
    my $size = shift;

    my $dir = $tck->bucket_dir("nwfilter");
    my $target = catfile($dir, $name);

# check for installation disk and build it if not exists
    my $already_installed = 0;
    my $pool_exists       = 0;
    my $poolname = "default";
    diag("searching pool name: ${poolname}");
    my $npools = $conn->num_of_storage_pools();
    diag("found pools: ${npools}");
    my @poolnames = $conn->list_storage_pool_names($npools);
    my $pool;

    foreach (@poolnames){
	diag "pool: $_";
	if (/${poolname}/) {
	    $pool_exists = 1;
	    my $pool = $conn->get_storage_pool_by_name($_);
	}
    }
    diag " ${poolname} exists: ${pool_exists}";
    if ($pool_exists == 0){
	diag "Creating pool: ${poolname}";
	my $poolxml = $tck->generic_pool("dir", $poolname)->as_xml;
	diag $poolxml;
	$pool = $conn->define_storage_pool($poolxml);
	$pool->build(0);
	$pool->create();
    } else {
	$pool = $conn->get_storage_pool_by_name($poolname);
    }

    my $nnames = $pool->num_of_storage_volumes();
    my @volNames = $pool->list_storage_vol_names($nnames);
    my $vol;
    foreach (@volNames){
	diag "volume: $_";
	if (/${name}/) {
	    $already_installed = 1;
	    $vol = $pool->get_volume_by_name($_);
	    diag $vol->get_path();
	}
    }

    diag "${name} disk already installed ${already_installed}";
    if ($already_installed == 0){
	diag "Creating ${target}";
	my $volume = $tck->generic_volume($name, "raw", $size, "4", "5");
	$volume->allocation(4096);
	my $volumexml = $volume->as_xml;
	diag $volumexml;

	$vol = $pool->create_volume($volumexml)
    } else {
	diag "${target} already exists";
    }
    return ($vol->get_path, $already_installed);
}

1;
