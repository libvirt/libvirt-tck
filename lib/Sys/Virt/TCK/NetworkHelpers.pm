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
    my $tmp = `grep $mac /var/lib/dnsmasq/dnsmasq.leases`;
    my @fields = split(/ /, $tmp);
    my $ip = $fields[2];
    return $ip;
}

sub build_cdrom_ks_image {
    my $tck = shift;

    my $ks = $tck->config("ks");

    # Where we put the source files for the ISO
    my $bucket1 = "nwfilter-install-ks";
    # Where we put the ISO itself
    my $bucket2 = "nwfilter-install-iso";

    my $isoimage = catfile($tck->bucket_dir($bucket2), "boot.iso");

    unless (-e $isoimage) {
	my $isofiledir = $tck->bucket_dir($bucket1);
	my $ksfile = $tck->get_scratch_resource($ks, $bucket1, "ks.cfg");
	my @progs = `which mkisofs genisoimage`;
	chomp(@progs);

	`$progs[0] -o "$isoimage" $isofiledir`;
    }

    return ($isoimage, "cdrom:/ks.cfg");
}

sub build_domain{
    my $tck = shift;
    my $domain_name = shift;
    my $mode = @_ ? shift : "bridge";

    my $guest;
    my $mac = "52:54:00:11:11:11";
    my $model = "virtio";
    #my $filterref = "no-spoofing";
    my $filterref = "clean-traffic";
    my $network = "network";
    my $source = "default";
    my $dev = "eth2";
    my $virtualport;

    my ($cdrom, $ksurl) = build_cdrom_ks_image($tck);

    my $guest = $tck->generic_domain($domain_name);

    # change the type of network connection for 802.1Qbg tests
    if ($mode eq  "vepa") {
	$network ="direct";
	$virtualport = "802.1Qbg";
   }

    # We want a bigger disk than normal
    $guest->rmdisk();
    my $diskpath = $tck->create_sparse_disk("nwfilter", "main.img", 5120);
    $guest->disk(src => $diskpath,
		 dst => "vda",
		 type=> "file");

    my $diskalloc = (stat $diskpath)[12];

    # No few blocks are allocated, then it likely hasn't been installed yet
    my $install = 0;
    if ($diskalloc < 10) {
	$install = 1;
	diag "Add cdrom";
	$guest->disk(src => $cdrom, dst=>"hdc",
			     type=> "file", device => "cdrom");
	my $cmdline = "ip=dhcp gateway=192.168.122.1 ks=$ksurl";
	$guest->boot_cmdline($cmdline);
	$guest->interface(type => $network,
			  source => $source,
			  model => $model,
			  mac => $mac);
    } else {
	diag "Do normal boot";
	$guest->clear_kernel_initrd_cmdline();
	if ($mode eq "vepa") {
	    $guest->interface(type => $network,
			      source => $source,
			      model => $model,
			      mac => $mac,
			      dev => $dev,
			      mode => $mode,
			      virtualport => $virtualport);
	} else {
	    $guest->interface(type => $network,
			      source => $source,
			      model => $model,
			      mac => $mac,
			      filterref => $filterref);
	}
    }

    # common configuration
    $guest->maxmem("1048576");
    $guest->memory("1048576");
    $guest->graphics(type => "vnc",
		     port => "-1",
		     autoport => "yes",
		     listen => "127.0.0.1");

    return ($guest, $install);
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
    my $mode = @_ ? shift : "bridge";

    my ($guest, $need_install) = build_domain($tck, $domain_name, $mode);
    if ($need_install) {
	my $dom = $conn->define_domain($guest->as_xml);
	diag "Starting installation domain";
	$dom->create;
	diag "wait for installation to finish .. ";
	while($dom->is_active()) {
	    sleep(10);
	    diag ".. to view progress connect to virtual machine ${domain_name} .. ";
	}
	# cleanup install domain
	$dom->undefine;
	$dom = undef;
	sleep (10);
	diag " .. done";
    }

    ($guest, $need_install) = build_domain($tck, $domain_name, $mode);
    if ($need_install) {
	die "guest install appears to have failed";
    }
    # now the disk is installed and we can boot it
    my $dom = $conn->define_domain($guest->as_xml);
    return $dom;
}

1;
