#
# Copyright (C) 2009-2010 Red Hat, Inc.
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

package Sys::Virt::TCK;

use strict;
use warnings;

use Sys::Virt;
use Sys::Virt::TCK::DomainBuilder;
use Sys::Virt::TCK::NetworkBuilder;
use Sys::Virt::TCK::StoragePoolBuilder;
use Sys::Virt::TCK::StorageVolBuilder;
use Sys::Virt::TCK::Capabilities;

use YAML qw();
use File::Copy qw(copy);
use File::Path qw(mkpath);
use File::Spec::Functions qw(catfile catdir rootdir);
use Cwd qw(cwd);
use LWP::UserAgent;
use IO::Interface::Simple;
use IO::Uncompress::Gunzip qw(gunzip);
use IO::Uncompress::Bunzip2 qw(bunzip2);
use XML::XPath;
use Carp qw(cluck carp);
use Fcntl qw(O_RDONLY SEEK_END);
use NetAddr::IP qw(:lower);
use Net::OpenSSH;

use Test::More;
use Sub::Uplevel qw(uplevel);
use base qw(Exporter);

our @EXPORT = qw(ok_error ok_domain ok_domain_snapshot ok_pool
                 ok_volume ok_network ok_interface ok_node_device
                 xpath err_not_implemented get_first_macaddress
                 get_first_interface_target_dev get_network_ip
                 get_ip_from_leases shutdown_vm_gracefully);

our $VERSION = 'v2.1.0';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{config} = $params{config} ? $params{config} :
        YAML::LoadFile($ENV{LIBVIRT_TCK_CONFIG} || "/etc/libvirt-tck/default.yml");

    $self->{autoclean} = $params{autoclean} ? $params{autoclean} :
        ($ENV{LIBVIRT_TCK_AUTOCLEAN} || 0);

    if ($ENV{LIBVIRT_TCK_DEBUG}) {
        $SIG{__WARN__} = sub { Carp::cluck $_[0]; };
        $SIG{__DIE__} = sub { Carp::confess $_[0]; };
    }

    bless $self, $class;

    return $self;
}

sub root_password {
    my $self = shift;

    return $self->config("rootpassword", "123456");
}

sub setup_conn {
    my $self = shift;
    my $uri = shift;

    my $conn = Sys::Virt->new(address => $uri);
    my $type = lc ($conn->get_type());

    $self->reset($conn) if $self->{autoclean};

    $self->sanity_check($conn);

    return $conn;
}

sub setup {
    my $self = shift;
    my %params = @_;
    my $dualhost = $params{dualhost} || 0;

    my $uri = $self->config("uri", undef);
    my $otheruri;
    $otheruri = $self->config("otheruri", undef) if $dualhost;

    my $conn = $self->setup_conn($uri);
    my $otherconn;
    $otherconn = $self->setup_conn($otheruri) if $otheruri;

    $self->{conns} = [ $conn, $otherconn ];

    return wantarray ? @{$self->{conns}} : $self->{conns}->[0];
}


sub sanity_check {
    my $self = shift;
    my $conn = shift;

    my @doms = grep { $_->get_name =~ /^tck/ } $conn->list_domains;
    if (@doms) {
        die "there is/are " . int(@doms) . " pre-existing active domain(s) in this driver";
    }

    @doms = grep { $_->get_name =~ /^tck/ } $conn->list_defined_domains;
    if (@doms) {
        die "there is/are " . int(@doms) . " pre-existing inactive domain(s) in this driver";
    }

    my @nets = grep { $_->get_name =~ /^tck/ } $conn->list_networks;
    if (@nets) {
        die "there is/are " . int(@nets) . " pre-existing active network(s) in this driver";
    }

    @nets = grep { $_->get_name =~ /^tck/ } $conn->list_defined_networks;
    if (@nets) {
        die "there is/are " . int(@nets) . " pre-existing inactive network(s) in this driver";
    }

    my @nwfilters = grep { $_->get_name =~ /^tck/ } $conn->list_nwfilters;
    if (@nwfilters) {
        die "there is/are " . int(@nwfilters) . " pre-existing nwfilter(s) in this driver";
    }

    my @pools = grep { $_->get_name =~ /^tck/ } $conn->list_storage_pools;
    if (@pools) {
        die "there is/are " . int(@pools) . " pre-existing active storage_pool(s) in this driver";
    }

    @pools = grep { $_->get_name =~ /^tck/ } $conn->list_defined_storage_pools;
    if (@pools) {
        die "there is/are " . int(@pools) . " pre-existing inactive storage_pool(s) in this driver";
    }
}

sub reset_snapshots {
    my $self = shift;
    my $dom = shift;

    # Use eval as not all drivers support snapshots
    my @domss = eval { $dom->list_snapshots };
    foreach my $domss (@domss) {
        $domss->delete;
    }
}

sub reset_domains {
    my $self = shift;
    my $conn = shift;

    my @doms = grep { $_->get_name =~ /^tck/ } $conn->list_domains;
    foreach my $dom (@doms) {
        $self->reset_snapshots($dom);
        if ($dom->get_id != 0) {
            $dom->destroy;
        }
    }

    @doms = grep { $_->get_name =~ /^tck/ } $conn->list_defined_domains();
    foreach my $dom (@doms) {
        $self->reset_snapshots($dom);
        $dom->undefine;
    }
}

sub reset_networks {
    my $self = shift;
    my $conn = shift;

    my @nets = grep { $_->get_name =~ /^tck/ } $conn->list_networks;
    foreach my $net (@nets) {
        if ($net->is_active()) {
            $net->destroy;
        }
    }

    @nets = grep { $_->get_name =~ /^tck/ } $conn->list_defined_networks();
    foreach my $net (@nets) {
        $net->undefine;
    }
}

sub reset_nwfilters {
    my $self = shift;
    my $conn = shift;

    my @nwfilters = grep { $_->get_name =~ /^tck/ } $conn->list_nwfilters;
    foreach my $nwfilter (@nwfilters) {
        $nwfilter->undefine;
    }
}

sub reset_storage_pools {
    my $self = shift;
    my $conn = shift;

    my @pools = grep { $_->get_name =~ /^tck/ } $conn->list_storage_pools;
    foreach my $pool (@pools) {
        my @vols = $pool->list_volumes;
        foreach my $vol (@vols) {
            eval { $vol->delete(0) };
        }
        $pool->destroy;
    }

    @pools = grep { $_->get_name =~ /^tck/ } $conn->list_defined_storage_pools();
    foreach my $pool (@pools) {
        eval {
            $pool->delete(0);
        };
        $pool->undefine;
    }
}


sub reset {
    my $self = shift;
    my $conn = shift || $self->conn;

    $self->reset_domains($conn);
    $self->reset_networks($conn);
    $self->reset_nwfilters($conn);
    $self->reset_storage_pools($conn);
}

sub cleanup {
    my $self = shift;

    foreach my $conn (@{$self->{conns}}) {
        $self->reset($conn);
    }

    delete $self->{conns};
}

sub config {
    my $self = shift;
    my $key = shift;
    if (@_) {
        my $default = shift;
	if (exists $self->{config}->{$key}) {
	    return $self->{config}->{$key};
	} else {
	    return $default;
	}
    } else {
	return $self->{config}->{$key};
    }
}


sub conn {
    my $self = shift;
    my $index = @_ ? shift : 0;
    return $self->{conns}->[$index];
}


sub scratch_dir {
    my $self = shift;

    my $scratch = $self->config("scratch_dir", $< > 0 ?
                                catdir(cwd(), "libvirt-tck") :
                                catdir(rootdir(), "var", "cache", "libvirt-tck"));

    mkpath($scratch) unless -e $scratch;

    return $scratch;
}

sub bucket_dir {
    my $self = shift;
    my $name = shift;

    my $scratch = $self->scratch_dir;

    my $bucket = catdir($scratch, $name);
    mkpath($bucket) unless -e $bucket;

    return $bucket;
}

sub get_scratch_resource {
    my $self = shift;
    my $source = shift;
    my $bucket = shift;
    my $name = shift;

    my $dir = $self->bucket_dir($bucket);
    my $target = catfile($dir, $name);

    return $target if -e $target;

    my $uncompress = undef;
    if (ref($source)) {
        $uncompress = $source->{uncompress};
        $source = $source->{source};
    }

    if ($source =~ m,^/,) {
        $self->copy_scratch($source, $target, $uncompress);
    } else {
        $self->download_scratch($source, $target, $uncompress);
    }

    return $target;
}


sub download_scratch {
    my $self = shift;
    my $source = shift;
    my $target = shift;
    my $uncompress = shift;

    print "# downloading $source\n";
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    my $response = $ua->get($source);

    if ($response->is_success) {
        open TGT, ">$target" or die "cannot create $target: $!";
        if (defined $uncompress) {
            my $data = $response->content;
            if ($uncompress eq "gzip") {
                gunzip \$data => \*TGT;
            } elsif ($uncompress eq "bzip2") {
                bunzip2 \$data => \*TGT;
            } else {
                die "unknown compression method '$uncompress'";
            }
        } else {
            print TGT $response->content or die "cannot write $target: $!";
        }
        close TGT or die "cannot save $target: $!";
    } else {
        die "cannot download $source: " . $response->status_line;
    }

}

sub copy_scratch {
    my $self = shift;
    my $source = shift;
    my $target = shift;
    my $uncompress = shift;

    print "# copying $source\n";
    if (defined $uncompress) {
        if ($uncompress eq "gzip") {
            gunzip $source => $target;
        } elsif ($uncompress eq "bzip2") {
            bunzip2 $source => $target;
        } else {
            die "unknown compression method '$uncompress'";
        }
    } else {
        copy ($source, $target) or die "cannot copy $source to $target: $!";
    }
}


sub create_sparse_disk {
    my $self = shift;
    my $bucket = shift;
    my $name = shift;
    my $size = shift;

    my $dir = $self->bucket_dir($bucket);

    my $target = catfile($dir, $name);

    open DISK, ">>$target" or die "cannot create $target: $!";

    truncate DISK, ($size * 1024 * 1024);

    close DISK or die "cannot save $target: $!";

    return $target;
}


sub has_disk_image {
    my $self = shift;
    my $bucket = shift;
    my $name = shift;
    my $osname = shift;

    my $dir = $self->bucket_dir($bucket);

    my $target = catfile($dir, $name);

    return -f $target
}

sub ssh_key_path {
    my $self = shift;
    my $basedir = shift;

    return catfile($basedir, "ssh", "id_rsa");
}

sub create_host_ssh_keys {
    my $self = shift;

    my $scratch = $self->scratch_dir;
    my $ssh_dir_path = catfile($scratch, "ssh");
    my $ssh_key_path = $self->ssh_key_path($scratch);

    if (! -d "$ssh_dir_path") {
        mkdir "$ssh_dir_path", 0700;
    }

    if (! -e "$ssh_key_path") {
        diag "generating a new SSH RSA key pair under $ssh_dir_path\n";
        system "ssh-keygen -q -t rsa -f $ssh_key_path -N ''";
    }

    return $ssh_key_path;
}

sub create_virt_builder_disk {
    my $self = shift;
    my $bucket = shift;
    my $name = shift;
    my $osname = shift;

    my $dir = $self->bucket_dir($bucket);

    my $target = catfile($dir, $name);

    my $password = $self->root_password;

    if ($self->has_disk_image($bucket, $name, $osname)) {
        return $target;
    }

    my $ssh_key_path = $self->create_host_ssh_keys;

    print "# running virt-builder $osname\n";
    system "virt-builder", "--install", "dsniff", "--selinux-relabel", "--root-password", "password:$password", "--ssh-inject", "root:file:$ssh_key_path.pub", "--output", $target, "--memsize", "2048", $osname;

    die "cannot run virt-builder: $?" if $? != 0;

    return $target;
}

sub create_empty_dir {
    my $self = shift;
    my $bucket = shift;
    my $name = shift;

    my $dir = $self->bucket_dir($bucket);

    my $target = catfile($dir, $name);

    mkpath($target) unless -e $target;

    return $target;
}


sub create_minimal_vroot {
    my $self = shift;
    my $bucket = shift;
    my $name = shift;

    my $dir = $self->bucket_dir($bucket);
    my $target = catdir($dir, $name);

    mkpath($target) unless -e $target;

    my $busybox = $self->config("busybox", "/sbin/busybox");

    die "$busybox does not exist" unless $busybox;

    my $type = `file $busybox 2>&1`;

    die "$busybox is not statically linked" unless $type =~ /statically/;

    my @dirs = qw(sbin bin dev proc sys tmp);

    foreach my $dir (@dirs) {
        my $fulldir = catdir($target, $dir);
        next if -e $fulldir;
        mkpath($fulldir);
    }

    my $dst = catfile($target, "sbin", "busybox");
    copy ($busybox, $dst) or die "cannot copy $busybox to $dst: $!";
    chmod 0755, $dst or die "cannot make $dst executable: $!";

    my @links = qw(
            ed           kill        ping6              svlogd
            egrep        killall     pipe_progress      swapoff
addgroup    eject        killall5    pivot_root         swapon
adduser     env          klogd       pkill              switch_root
adjtimex    envdir       last        poweroff           sync
ar          envuidgid    length      printenv           sysctl
arp         expand       less        printf             syslogd
arping      expr         linux32     ps                 tail
ash         fakeidentd   linux64     pscan              tar
awk         false        linuxrc     pwd                tcpsvd
basename    fbset        ln          raidautorun        tee
bunzip2     fdformat     loadfont    rdate              telnet
busybox     fdisk        loadkmap    readahead          telnetd
bzcat       fgrep        logger      readlink           test
bzip2       find         login       readprofile        tftp
cal         fold         logname     realpath           time
cat         free         logread     reboot             top
catv        freeramdisk  losetup     renice             touch
chattr      fsck         ls          reset              tr
chgrp       fsck.minix   lsattr      resize             traceroute
chmod       ftpget       lsmod       rm                 true
chown       ftpput       lzmacat     rmdir              tty
chpasswd    fuser        makedevs    rmmod              ttysize
chpst       getopt       md5sum      route              udhcpc
chroot      getty        mdev        rpm                udhcpd
chrt        grep         mesg        rpm2cpio           udpsvd
chvt        gunzip       microcom    runlevel           umount
cksum       gzip         mkdir       run-parts          uname
clear       halt         mkfifo      runsv              uncompress
cmp         hdparm       mkfs.minix  runsvdir           unexpand
comm        head         mknod       rx                 uniq
cp          hexdump      mkswap      sed                unix2dos
cpio        hostid       mktemp      seq                unlzma
crond       hostname     modprobe    setarch            unzip
crontab     httpd        more        setconsole         uptime
cryptpw     hwclock      mount       setkeycodes        usleep
cut         id           mountpoint  setlogcons         uudecode
date        ifconfig     msh         setsid             uuencode
dc          ifdown       mt          setuidgid          vconfig
dd          ifup         mv          sh                 vi
deallocvt   inetd        nameif      sha1sum            vlock
delgroup    init         nc          slattach           watch
deluser     insmod       netstat     sleep              watchdog
df          install      nice        softlimit          wc
dhcprelay   ip           nmeter      sort               wget
diff        ipaddr       nohup       split              which
dirname     ipcalc       nslookup    start-stop-daemon  who
dmesg       ipcrm        od          stat               whoami
dnsd        ipcs         openvt      strings            xargs
dos2unix    iplink       passwd      stty               yes
du          iproute      patch       su                 zcat
dumpkmap    iprule       pgrep       sulogin            zcip
dumpleases  iptunnel     pidof       sum
echo        kbd_mode     ping        sv);

    foreach my $file (@links) {
        my $fullfile = catfile($target, "bin", $file);
        next if -e $fullfile;
        symlink "../sbin/busybox", $fullfile
            or die "cannot symlink $fullfile to ../sbin/busybox: $!";
    }

    my $init = catfile($target, "sbin", "init");
    open INIT, ">$init" or die "cannot create $init: $!";

    print INIT <<EOF;
#!/sbin/busybox

sh
EOF

    close INIT or die "cannot save $init: $!";
    chmod 0755, $init or die "cannot make $init executable: $!";

    return ($target, catfile(rootdir, "sbin", "init"));
}

sub best_domain {
    my $self = shift;
    my $caps = shift;
    my $ostype = shift;

    for (my $i = 0 ; $i < $caps->num_guests ; $i++) {
        if ($caps->guest_os_type($i) eq $ostype &&
            $caps->guest_arch_name($i) eq $caps->host_cpu_arch()) {

            my @domains = $caps->guest_domain_types($i);
            next unless int(@domains);

            # Prefer kvm if multiple domain types are returned
            my $domain = (grep /^kvm$/, @domains) ? "kvm" : $domains[0];

            return ($domain,
                    $caps->host_cpu_arch());
        }
    }

    return ();
}


sub match_guest_domain {
    my $self = shift;
    my $caps = shift;
    my $arch = shift;
    my $ostype = shift;

    for (my $i = 0 ; $i < $caps->num_guests ; $i++) {
        if ($caps->guest_os_type($i) eq $ostype &&
            $caps->guest_arch_name($i) eq $arch) {

            my @domains = $caps->guest_domain_types($i);
            next unless int(@domains);

            # Prefer kvm if multiple domain types are returned
            my $domain = (grep /^kvm$/, @domains) ? "kvm" : $domains[0];

            return ($domain,
                    $caps->guest_domain_emulator($i, $domain),
                    $caps->guest_domain_loader($i, $domain));
        }
    }

    return ();
}


sub best_kernel {
    my $self = shift;
    my $caps = shift;
    my $wantostype = shift;

    my $kernels = $self->config("kernels", []);
    my $hostarch = $caps->host_cpu_arch();

    for (my $i = 0 ; $i <= $#{$kernels} ; $i++) {
        my $arch = $kernels->[$i]->{arch};
        my $ostype = $kernels->[$i]->{ostype};
        my @ostype = ref($ostype) ? @{$ostype} : ($ostype);

        next unless $arch eq $hostarch;

        foreach $ostype (@ostype) {
            if ((defined $wantostype) &&
                ($wantostype ne $ostype)) {
                next;
            }

            my ($domain, $emulator, $loader) =
                $self->match_guest_domain($caps, $arch, $ostype);

            if (defined $domain) {
                return ($i, $domain, $arch, $ostype, $emulator, $loader)
            }
        }
    }

    return ();
}


# Find an image matching the host arch and requested ostype
sub best_image {
    my $self = shift;
    my $caps = shift;
    my $wantostype = shift;

    my $images = $self->config("images", []);
    my $hostarch = $caps->host_cpu_arch();

    for (my $i = 0 ; $i <= $#{$images} ; $i++) {
        my $arch = $images->[$i]->{arch};
        my $ostype = $images->[$i]->{ostype};
        my @ostype = ref($ostype) ? @{$ostype} : ($ostype);

        next unless $arch eq $hostarch;

        foreach $ostype (@ostype) {
            if ((defined $wantostype) &&
                ($wantostype ne $ostype)) {
                next;
            }

            my ($domain, $emulator, $loader) =
                $self->match_guest_domain($caps, $arch, $ostype);

            if (defined $domain) {
                return ($i, $domain, $arch, $ostype, $emulator, $loader)
            }
        }
    }

    return ();
}

sub get_disk_dev {
    my $self = shift;
    my $ostype = shift;
    my $domain = shift;

    my $dev;
    if ($ostype eq "xen") {
        $dev = "xvda";
    } elsif ($ostype eq "hvm") {
        if ($domain eq "kvm" ||
            $domain eq "qemu" ||
            $domain eq "kqemu") {
            $dev = "vda";
        } else {
            $dev = "hda";
        }
    }
    return $dev;
}


sub get_kernel {
    my $self = shift;
    my $caps = shift;
    my $wantostype = shift;

    my ($cfgindex, $domain, $arch, $ostype, $emulator, $loader) =
        $self->best_kernel($caps, $wantostype);

    if (!defined $cfgindex) {
        die "cannot find any supported kernel configuration";
    }

    my $kernels = $self->config("kernels", []);

    my $kernel = $kernels->[$cfgindex]->{kernel};
    my $initrd = $kernels->[$cfgindex]->{initrd};
    my $disk = $kernels->[$cfgindex]->{disk};

    my $bucket = "os-$arch-$ostype";

    my $kfile = $self->get_scratch_resource($kernel, $bucket, "vmlinuz");
    my $ifile = $initrd ? $self->get_scratch_resource($initrd, $bucket, "initrd") : undef;
    my $dfile = $disk ? $self->get_scratch_resource($disk, $bucket, "disk.img") : undef;

    unless (defined $dfile) {
        $dfile = $self->create_sparse_disk($bucket, "disk.img", 100);
    }

    chmod 0755, $kfile;

    my $dev = $self->get_disk_dev($ostype, $domain);

    return (
        domain => $domain,
        arch => $arch,
        ostype => $ostype,
        emulator => $emulator,
        loader => $loader,
        kernel => $kfile,
        initrd => $ifile,
        root => $dfile,
        dev => $dev,
    );
}


sub get_image {
    my $self = shift;
    my $caps = shift;
    my $wantostype = shift;

    my ($cfgindex, $domain, $arch, $ostype, $emulator, $loader) =
        $self->best_image($caps, $wantostype);

    if (!defined $cfgindex) {
        die "cannot find any supported image configuration";
    }

    my $kernels = $self->config("images", []);

    my $osname = $kernels->[$cfgindex]->{osname};

    my $bucket = "os-$arch-$ostype";

    my $needs_firstboot = ! $self->has_disk_image($bucket, "disk-$osname.img", $osname);
    my $dfile = $self->create_virt_builder_disk($bucket, "disk-$osname.img", $osname);

    my $dev = $self->get_disk_dev($ostype, $domain);

    return (
        domain => $domain,
        arch => $arch,
        ostype => $ostype,
        emulator => $emulator,
        loader => $loader,
        root => $dfile,
        dev => $dev,
    firstboot => $needs_firstboot,
    );
}



sub generic_machine_domain {
    my $self = shift;
    my %params = @_;
    my $name = exists $params{name} ? $params{name} : "tck";
    my $caps = exists $params{caps} ? $params{caps} : die "caps parameter is required";
    my $ostype = exists $params{ostype} ? $params{ostype} : "hvm";
    my $fullos = exists $params{fullos} ? $params{fullos} : 0;
    my $shareddisk = exists $params{shareddisk} ? $params{shareddisk} : 0;
    my $filterref = exists $params{filterref} ? $params{filterref} : undef;
    my %filterparams = exists $params{filterparams} ? %{$params{filterparams}} : ();

    if ($fullos) {
        my %config = $self->get_image($caps, $ostype);

        my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $self->conn,
                                                   name => $name,
                                                   arch => $config{arch},
                                                   domain => $config{domain},
                                                   ostype => $config{ostype});
        $b->memory(1024 * 1024);
        $b->with_acpi();
        $b->with_apic();

        $b->boot_disk();

        $b->disk(src => $config{root},
                 dst => $config{dev},
                 type => "file");
        $b->rng(backend_model => "random");

        if ($config{firstboot}) {
            print "# Running the first boot\n";

            $b->interface(type => "network",
                          source => "default",
                          model => "virtio",
                          mac => "52:54:00:11:11:11",
                          filterref => $filterref,
                          filterparams => \%filterparams);
            my $xml = $b->as_xml();
            # Cleanup the temporary interface
            $b->rminterface();

            my $dom = $self->conn->define_domain($xml);
            $dom->create();

            # Wait for the first boot to reach network setting
            my $iface = get_first_interface_target_dev($dom);
            my $stats;
            my $tries = 0;
            do {
                sleep(10);
                $stats  = $dom->interface_stats($iface);
                $tries++;
            } while ($stats->{"tx_packets"} < 10 && $tries < 10);

            # Safe to shutdown domain now
            my $target = time() + 30;
            $dom->shutdown;
            while ($dom->is_active()) {
                sleep(1);
                $dom->destroy() if time() > $target;
            }
            sleep(1);
            $dom->undefine();
        }

        return $b;
    } else {
        my %config = $self->get_kernel($caps, $ostype);

        my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $self->conn,
                                                   name => $name,
                                                   arch => $config{arch},
                                                   domain => $config{domain},
                                                   ostype => $config{ostype});
        $b->memory(1024 * 1024);
        $b->with_acpi();
        $b->with_apic();

        # XXX boot CDROM or vroot for other HVs
        $b->boot_kernel($config{kernel}, $config{initrd});

        $b->disk(src => $config{root},
                 dst => $config{dev},
                 type => "file",
                 shareable => $shareddisk);
        $b->rng(backend_model => "random");
        return $b;
    }
}


sub best_container_domain {
    my $self = shift;
    my $caps = shift;

    for (my $i = 0 ; $i < $caps->num_guests ; $i++) {
        if ($caps->guest_os_type($i) eq "exe") {
            my @domains = $caps->guest_domain_types($i);
            next unless int(@domains);

            return $domains[0];
        }
    }

    return undef;

}

sub generic_container_domain {
    my $self = shift;
    my %params = @_;
    my $name = exists $params{name} ? $params{name} : "tck";
    my $caps = exists $params{caps} ? $params{caps} : die "caps parameter is required";
    my $domain = exists $params{domain} ? $params{domain} : die "domain parameter is required";

    my $bucket = "os-exe";

    my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $self->conn,
                                               name => $name,
                                               domain => $domain,
                                               ostype => "exe");
    $b->memory(64 * 1024);

    my ($root, $init) = $self->create_minimal_vroot($bucket, $name);

    $b->boot_init($init);

    $b->filesystem(src => $root,
                   dst => "/",
                   type => "mount");

    return $b;
}


sub generic_domain {
    my $self = shift;
    my %params = @_;

    my $name = exists $params{name} ? $params{name} : "tck";
    my $ostype = exists $params{ostype} ? $params{ostype} : undef;
    my $fullos = exists $params{fullos} ? $params{fullos} : 0;
    my $netmode = exists $params{netmode} ? $params{netmode} : undef;
    my $shareddisk = exists $params{shareddisk} ? $params{shareddisk} : 0;
    my $filterref = exists $params{filterref} ? $params{filterref} : undef;
    my %filterparams = exists $params{filterparams} ? %{$params{filterparams}} : ();

    my $caps = Sys::Virt::TCK::Capabilities->new(xml => $self->conn->get_capabilities);

    my $container;

    $container = $self->best_container_domain($caps)
        unless $ostype && $ostype ne "exe";

    my $b;
    if ($container) {
        die "Full provisioned OS not supported with containers yet" if $fullos;

        $b = $self->generic_container_domain(name => $name,
                                             caps => $caps,
                                             domain => $container);
    } else {
        $b = $self->generic_machine_domain(name => $name,
                                           caps => $caps,
                                           ostype => $ostype,
					   shareddisk => $shareddisk,
                                           fullos => $fullos,
                                           filterref => $filterref,
                                           filterparams => \%filterparams);
    }
    if ($netmode) {
        if ($netmode eq "vepa") {
            $b->interface(type => "direct",
                          source => "default",
                          model => "virtio",
                          mac => "52:54:00:11:11:11",
                          dev => $self->get_host_network_device(),
                          mode => "vepa",
                          virtualport => "802.1Qbg");
        } else {
            $b->interface(type => "network",
                          source => "default",
                          model => "virtio",
                          mac => "52:54:00:11:11:11",
                          filterref => $filterref,
                          filterparams => \%filterparams);
        }
    }
    return $b;
}

sub generic_pool {
    my $self = shift;
    my $type = shift;
    my $name = @_ ? shift : "tck";

    my $bucket = $self->bucket_dir("storage-fs");

    my $b = Sys::Virt::TCK::StoragePoolBuilder->new(name => $name,
                                                    type => $type);

    $b->target(catdir($bucket, $name));

    return $b;
}


sub generic_network {
    my $self = shift;
    my $name = @_ ? shift : "tck";

    my $b = Sys::Virt::TCK::NetworkBuilder->new(name => $name);

    $b->bridge($name);
    # XXX check for host clash
    #$b->ipaddr("10.250.250.250", "255.255.255.0");

    return $b;
}


sub generic_volume {
    my $self = shift;
    my $name = @_ ? shift : "tck";
    my $format = @_ ? shift :undef;
    my $capacity = @_ ? shift : 1024*1024*50;

    my $b = Sys::Virt::TCK::StorageVolBuilder->new(name => $name);
    $b->format($format) if $format;
    $b->capacity($capacity);

    return $b;
}

# Borrowed from Test::Exception

sub _quiet_caller (;$) { ## no critic Prototypes
    my $height = $_[0];
    $height++;
    if( wantarray and !@_ ) {
        return (CORE::caller($height))[0..2];
    }
    else {
        return CORE::caller($height);
    }
                   }

sub _try_as_caller {
    my $coderef = shift;
    my $depth = shift;

    # local works here because Sub::Uplevel has already overridden caller
    local *CORE::GLOBAL::caller;
    { no warnings 'redefine'; *CORE::GLOBAL::caller = \&_quiet_caller; }

    my $ret = eval { uplevel $depth, $coderef };
    return ($ret, $@);
};


sub ok_object($$$;$) {
    my $coderef = shift;
    my $class = shift;
    my $description = shift;
    my $name = shift;

    die "must pass coderef, class, description and (optional) expected name"
        unless defined $description;

    my ($ret, $exception) = _try_as_caller($coderef, 4);

    my $ok = "$exception" eq "" &&
        $ret && ref($ret) && $ret->isa($class) &&
        (!defined $name || ($ret->get_name() eq $name));

    ok($ok, $description);
    unless ($ok) {
        diag("expected $class object" . ($name ? " with name $name" : ""));
        if ($exception) {
            diag("found '$exception'");
        } else {
            if ($ret && ref($ret) && $ret->isa($class)) {
                diag("found $class object with name " . $ret->get_name);
            } else {
                diag("found '$ret'");
            }
        }
    }
}

sub ok_domain(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::Domain", $description, $name);
}

sub ok_domain_snapshot(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::DomainSnapshot", $description, $name);
}

sub ok_pool(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::StoragePool", $description, $name);
}

sub ok_network(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::Network", $description, $name);
}

sub ok_volume(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::StorageVol", $description, $name);
}

sub ok_interface(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::Interface", $description, $name);
}

sub ok_node_device(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    ok_object($coderef, "Sys::Virt::NodeDevice", $description, $name);
}


sub ok_error(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $code = shift;

    die "must pass coderef, description and (optional) expected error code"
        unless defined $description;

    my ($ret, $exception) = _try_as_caller($coderef, 3);

    my $ok = ref($exception) && $exception->isa("Sys::Virt::Error") &&
        (!defined $code || ($exception->code() == $code));

    ok($ok, $description);
    unless ($ok) {
        diag("expecting Sys::Virt::Error object" . ($code ?  " with code $code" : ""));
        diag("found '$exception'");
    }
    $@ = $exception;
    return $ok;
}


sub err_not_implemented {
    my $exception = shift;

    if ($exception &&
        ref($exception) &&
        $exception->isa("Sys::Virt::Error") &&
        $exception->code() == 3) {
        return 1;
    }
    return 0;
}

sub xpath {
    my $object = shift;
    my $path = shift;

    my $xml = $object->get_xml_description;

    my $xp = XML::XPath->new(xml => $xml);

    return $xp->find($path);
}

sub get_host_usb_device {
    my $self = shift;
    my $devindex = @_ ? shift : 0;

    my $devs = $self->config("host_usb_devices", []);

    if ($devindex > $#{$devs}) {
        return ();
    }

    my $dev = $devs->[$devindex];
    my $bus = $dev->{"bus"};
    my $device = $dev->{"device"};
    my $vendor = $dev->{"vendor"};
    my $product = $dev->{"product"};

    return ($bus, $device, $vendor, $product);
}

sub get_host_pci_device {
    my $self = shift;
    my $devindex = @_ ? shift : 0;

    my $devs = $self->config("host_pci_devices", []);

    if ($devindex > $#{$devs}) {
        return ();
    }

    my $dev = $devs->[$devindex];
    my $domain = $dev->{"domain"};
    my $bus = $dev->{"bus"};
    my $slot = $dev->{"slot"};
    my $function = $dev->{"fnuction"};

    return ($domain, $bus, $slot, $function);
}

sub get_host_block_device {
    my $self = shift;
    my $devindex = @_ ? shift : 0;

    my $devs = $self->config("host_block_devices", []);
    if ($devindex >= $#{$devs}) {
	return undef;
    }
    my $device = $devs->[$devindex];
    my $size;
    if (defined $device &&
	ref($device) == 'HASH') {
	$device = $device->{"path"};
	$size = $device->{"size"};
    }
    return undef unless $device;

    my $match = 1;
    if (defined $size) {
	# Filter out devices that the current user can't open.
	sysopen(BLK, $device, O_RDONLY) or return undef;
	if (sysseek(BLK, 0, SEEK_END) != ($size * 1024)) {
	    $match = 0;
	}
	close BLK;
    }

    return $match ? $device : undef;
}

sub get_host_network_device {
    my $self = shift;
    my $devindex = @_ ? shift : 0;

    my $devs = $self->config("host_network_devices", []);

    if ($devindex >= $#{$devs}) {
	return undef;
    }

    return $devs->[$devindex];
}

sub get_first_macaddress {
    my $dom = shift;
    my $mac = xpath($dom, "string(/domain/devices/interface[1]/mac/\@address)");
    utf8::encode($mac);
    return $mac;
}

sub get_first_interface_target_dev {
    my $dom = shift;
    my $targetdev = xpath($dom, "string(/domain/devices/interface[1]/target/\@dev)");
    return $targetdev;
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
        $ip = NetAddr::IP->new("$net_ip/$net_prefix");
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
        return @leases ? $leases[0]->{'ipaddr'} : undef;
    }

    my $tmp = `grep $mac /var/lib/libvirt/dnsmasq/default.leases`;
    my @fields = split(/ /, $tmp);
    my $ip = $fields[2];
    return $ip;
}


sub find_free_ipv4_subnet {
    my $index;

    my %used;

    foreach my $iface (IO::Interface::Simple->interfaces()) {
	if ($iface->netmask eq "255.255.255.0" &&
	    $iface->address =~ /^192.168.(\d+).\d+/) {
	    $used{"$1"} = 1;
	    print "Used $1\n";
	} else {
	    print "Not used ", $iface->address, "\n";
	}
    }

    for (my $i = 1; $i < 255; $i++) {
	if (!exists $used{"$i"}) {
	    $index = $i;
	    last;
	}
    }

    return () unless defined $index;

    return (
	address => "192.168.$index.1",
	netmask => "255.255.255.0",
	dhcpstart => "192.168.$index.100",
	dhcpend => "192.168.$index.200"
	);
}

sub wait_for_vm_to_boot {
    my $self = shift;
    my $dom = shift;
    my $mac = get_first_macaddress($dom);
    my $ip;
    my $ssh;

    local $SIG{ALRM} = sub { die "timeout while waiting for domain to bootup" };

    diag "Waiting 60 seconds for guest to finish booting";
    alarm(60);

    do {
        sleep(5);
        $ip = get_ip_from_leases($self->conn, "default", $mac);
    } while(not $ip);

    do {
        sleep(5);
        $ssh = Net::OpenSSH->new($ip,
                                 user => "root",
                                 key_path => $self->ssh_key_path($self->scratch_dir()),
                                 master_opts => [-o => "UserKnownHostsFile=/dev/null",
                                                 -o => "StrictHostKeyChecking=no"]);
    } while ($ssh->error);

    alarm(0);

    $ssh->disconnect();

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
