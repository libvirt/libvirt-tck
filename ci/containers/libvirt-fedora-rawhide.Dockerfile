FROM registry.fedoraproject.org/fedora:rawhide

RUN dnf update -y --nogpgcheck fedora-gpg-keys && \
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
        meson \
        ninja-build \
        perl \
        perl-Archive-Tar \
        perl-CPAN-Changes \
        perl-Config-Record \
        perl-Digest \
        perl-Digest-MD5 \
        perl-File-Slurp \
        perl-IO-Compress-Bzip2 \
        perl-IO-String \
        perl-Module-Build \
        perl-NetAddr-IP \
        perl-Sub-Uplevel \
        perl-TAP-Formatter-HTML \
        perl-TAP-Formatter-JUnit \
        perl-TAP-Harness-Archive \
        perl-Test-Exception \
        perl-Test-LWP-UserAgent \
        perl-Test-Pod \
        perl-Test-Pod-Coverage \
        perl-Time-HiRes \
        perl-XML-Twig \
        perl-XML-Writer \
        perl-XML-XPath \
        perl-accessors \
        perl-generators \
        pkgconfig \
        python3 \
        python3-docutils \
        rpcgen \
        rpm-build && \
    dnf autoremove -y && \
    dnf clean all -y && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/$(basename /usr/bin/gcc)

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
