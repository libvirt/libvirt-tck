# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci/-/commit/5093d9474cc7e391455e381f437f478b3e077f32

FROM registry.fedoraproject.org/fedora:rawhide

RUN dnf update -y --nogpgcheck fedora-gpg-keys && \
    dnf install -y nosync && \
    echo -e '#!/bin/sh\n\
if test -d /usr/lib64\n\
then\n\
    export LD_PRELOAD=/usr/lib64/nosync/nosync.so\n\
else\n\
    export LD_PRELOAD=/usr/lib/nosync/nosync.so\n\
fi\n\
exec "$@"' > /usr/bin/nosync && \
    chmod +x /usr/bin/nosync && \
    nosync dnf update -y && \
    nosync dnf install -y \
        ca-certificates \
        ccache \
        cpp \
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
        perl-Sys-Hostname \
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
        perl-base \
        perl-generators \
        pkgconfig \
        python3 \
        python3-docutils \
        rpcgen \
        rpm-build && \
    nosync dnf autoremove -y && \
    nosync dnf clean all -y && \
    rpm -qa | sort > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
