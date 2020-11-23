FROM registry.centos.org/centos:8

RUN dnf install 'dnf-command(config-manager)' -y && \
    dnf config-manager --set-enabled -y PowerTools && \
    dnf install -y centos-release-advanced-virtualization && \
    dnf install -y epel-release && \
    dnf update -y && \
    dnf install -y \
        ca-certificates \
        ccache \
        gcc \
        gettext \
        git \
        glib2-devel \
        glibc-devel \
        glibc-langpack-en \
        gnutls-devel \
        libnl3-devel \
        libtirpc-devel \
        libxml2 \
        libxml2-devel \
        libxslt \
        make \
        ninja-build \
        perl \
        perl-App-cpanminus \
        perl-Archive-Tar \
        perl-CPAN-Changes \
        perl-Digest \
        perl-Digest-MD5 \
        perl-File-Slurp \
        perl-IO-Compress-Bzip2 \
        perl-IO-String \
        perl-Module-Build \
        perl-NetAddr-IP \
        perl-Sub-Uplevel \
        perl-Test-Exception \
        perl-Test-Pod \
        perl-Test-Pod-Coverage \
        perl-Time-HiRes \
        perl-XML-Twig \
        perl-XML-Writer \
        perl-XML-XPath \
        perl-generators \
        pkgconfig \
        python3 \
        python3-docutils \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        rpcgen \
        rpm-build && \
    dnf autoremove -y && \
    dnf clean all -y && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/$(basename /usr/bin/gcc)

RUN pip3 install \
         meson==0.54.0

RUN cpanm --notest \
          Config::Record \
          LWP::UserAgent \
          TAP::Formatter::HTML \
          TAP::Formatter::JUnit \
          TAP::Harness::Archive \
          accessors

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
