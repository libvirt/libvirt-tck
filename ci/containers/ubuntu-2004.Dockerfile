# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci/-/commit/5093d9474cc7e391455e381f437f478b3e077f32

FROM docker.io/library/ubuntu:20.04

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y eatmydata && \
    eatmydata apt-get dist-upgrade -y && \
    eatmydata apt-get install --no-install-recommends -y \
            ca-certificates \
            ccache \
            cpp \
            gcc \
            gettext \
            git \
            libaccessors-perl \
            libarchive-tar-perl \
            libc-dev-bin \
            libc6-dev \
            libconfig-record-perl \
            libcpan-changes-perl \
            libdigest-perl \
            libdigest-perl-md5-perl \
            libfile-slurp-perl \
            libglib2.0-dev \
            libgnutls28-dev \
            libio-compress-perl \
            libio-string-perl \
            libmodule-build-perl \
            libnetaddr-ip-perl \
            libnl-3-dev \
            libnl-route-3-dev \
            libsub-uplevel-perl \
            libtap-formatter-html-perl \
            libtap-formatter-junit-perl \
            libtap-harness-archive-perl \
            libtest-exception-perl \
            libtest-lwp-useragent-perl \
            libtest-pod-coverage-perl \
            libtest-pod-perl \
            libtime-hr-perl \
            libtirpc-dev \
            libxml-twig-perl \
            libxml-writer-perl \
            libxml-xpath-perl \
            libxml2-dev \
            libxml2-utils \
            locales \
            make \
            ninja-build \
            perl-base \
            pkgconf \
            python3 \
            python3-docutils \
            python3-pip \
            python3-setuptools \
            python3-wheel \
            xsltproc && \
    eatmydata apt-get autoremove -y && \
    eatmydata apt-get autoclean -y && \
    sed -Ei 's,^# (en_US\.UTF-8 .*)$,\1,' /etc/locale.gen && \
    dpkg-reconfigure locales && \
    dpkg-query --showformat '${Package}_${Version}_${Architecture}\n' --show > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

RUN pip3 install \
         meson==0.56.0

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
