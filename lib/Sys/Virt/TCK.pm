
package Sys::Virt::TCK;

use strict;
use warnings;

use Sys::Virt;
use Sys::Virt::TCK::DomainBuilder;
use Config::Record;
use File::Copy qw(copy);
use File::Path qw(mkpath);
use File::Spec::Functions qw(catfile catdir rootdir);
use Cwd qw(cwd);
use LWP::UserAgent;
use IO::Uncompress::Gunzip qw(gunzip);
use IO::Uncompress::Bunzip2 qw(bunzip2);

use Test::Builder;
use Sub::Uplevel qw(uplevel);
use base qw(Exporter);

our @EXPORT = qw(ok_error ok_domain);

our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{config} = $params{config} ? $params{config} :
	Config::Record->new(file => ($ENV{LIBVIRT_TCK_CONFIG} || "/etc/tck.conf"));

    $self->{autoclean} = $params{autoclean} ? $params{autoclean} :
	($ENV{LIBVIRT_TCK_AUTOCLEAN} || 0);

    bless $self, $class;

    return $self;
}


sub setup {
    my $self = shift;

    my $uri = $self->config("uri", undef);
    $self->{conn} = Sys::Virt->new(address => $uri);
    my $type = $self->{conn}->get_type();
    $self->{type} = lc $type;

    $self->reset if $self->{autoclean};

    $self->sanity_check;

    return $self->{conn};
}


sub sanity_check {
    my $self = shift;

    my @doms = $self->{conn}->list_domains;
    if (@doms) {
	die "there is/are " . int(@doms) . " pre-existing active domain(s) in this driver";
    }

    @doms = $self->{conn}->list_defined_domains;
    if (@doms) {
	die "there is/are " . int(@doms) . " pre-existing inactive domain(s) in this driver";
    }
}

sub reset {
    my $self = shift;

    my @doms = $self->{conn}->list_domains;
    foreach my $dom (@doms) {
	if ($dom->get_id != 0) {
	    $dom->destroy;
	}
    }

    @doms = $self->{conn}->list_defined_domains();
    foreach my $dom (@doms) {
	$dom->undefine;
    }
}

sub cleanup {
    my $self = shift;

    $self->reset();

    delete $self->{conn};
}

sub config {
    my $self = shift;
    my $key = shift;
    if (@_) {
	my $default = shift;
	return $self->{config}->get($key, $default);
    } else {
	return $self->{config}->get($key);
    }
}


sub conn {
    my $self = shift;
    return $self->{conn};
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

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    my $response = $ua->get($source);

    if ($response->is_success) {
	open TGT, ">$target" or die "cannot create $target: $!";
	if (defined $uncompress) {
	warn "uncomp $uncompress $source $target\n";
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
	#print TGT $response->decoded_content or die "cannot write $target: $!";
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

    if (defined $uncompress) {
	warn "uncomp $uncompress $source $target\n";
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

    open DISK, ">$target" or die "cannot create $target: $1";

    truncate DISK, ($size * 1024 * 1024);

    close DISK or die "cannot save $target: $!";

    return $target;
}


sub get_kernel {
    my $self = shift;
    my $arch = shift;
    my $ostype = shift;

    my $kernels = $self->config("kernels", []);

    foreach my $entry (@$kernels) {
	next unless $arch eq $entry->{arch};
	next unless grep { $_ eq $ostype } @{$entry->{ostype}};

	my $kernel = $entry->{kernel};
	my $initrd = $entry->{initrd};
	my $disk = $entry->{disk};

	my $bucket = "os-$arch-$ostype";

	my $kfile = $self->get_scratch_resource($kernel, $bucket, "vmlinuz");
	my $ifile = $initrd ? $self->get_scratch_resource($initrd, $bucket, "initrd") : undef;
	my $dfile = $disk ? $self->get_scratch_resource($disk, $bucket, "disk.img") : undef;

	unless (defined $dfile) {
	    $dfile = $self->create_sparse_disk($bucket, "disk.img", 100);
	}

	return ($kfile, $ifile, $dfile);
    }

    die "cannot find a kernel with arch '$arch' and ostype '$ostype'";
}



sub generic_domain {
    my $self = shift;
    my $name = @_ ? shift : "test";

    # XXX fix arch/type basedon capabilities
    my ($kernel, $initrd, $root) = $self->get_kernel("i686", "hvm");

    my $b = Sys::Virt::TCK::DomainBuilder->new(conn => $self->{conn},
					       name => $name);
    $b->memory(64 * 1024);

    # XXX boot CDROM or vroot for other HVs
    $b->boot_kernel($kernel, $initrd);
    # XXX non-IDE
    $b->disk(src =>$root, dst => "hda", type => "file");

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

    # local works here because Sub::Uplevel has already overridden caller
    local *CORE::GLOBAL::caller;
    { no warnings 'redefine'; *CORE::GLOBAL::caller = \&_quiet_caller; }

    my $ret = eval { uplevel 3, $coderef };
    return ($ret, $@);
};


my $Tester = Test::Builder->new;

sub ok_domain(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $name = shift;

    die "must pass coderef, description and (optional) expected name"
	unless defined $description;

    my ($ret, $exception) = _try_as_caller($coderef);

    my $ok = "$exception" eq "" &&
	$ret && ref($ret) && $ret->isa("Sys::Virt::Domain") &&
	(!defined $name || ($ret->get_name() eq $name));

    $Tester->ok($ok, $description);
    unless ($ok) {
	$Tester->diag("expected Sys::Virt::Domain object" . ($name ? " with name $name" : ""));
	if ($exception) {
	    $Tester->diag("found '$exception'");
	} else {
	    if ($ret && ref($ret) && $ret->isa("Sys::Virt::Domain")) {
		$Tester->diag("found Sys::Virt::Domain object with name " . $ret->get_name);
	    } else {
		$Tester->diag("found '$ret'");
	    }
	}
    }
}

sub ok_error(&$;$) {
    my $coderef = shift;
    my $description = shift;
    my $code = shift;

    die "must pass coderef, description and (optional) expected error code"
	unless defined $description;

    my ($ret, $exception) = _try_as_caller($coderef);

    my $ok = ref($exception) && $exception->isa("Sys::Virt::Error") &&
	(!defined $code || ($exception->code() == $code));

    $Tester->ok($ok, $description);
    unless ($ok) {
	$Tester->diag("expecting Sys::Virt::Error object" . ($code ?  " with code $code" : ""));
	$Tester->diag("found '$exception'");
    }
    $@ = $exception;
    return $ok;
}

1;
