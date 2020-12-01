FROM docker.io/library/debian:sid

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install --no-install-recommends -y \
            ca-certificates \
            ccache \
            gcc \
            gettext \
            git \
            libaccessors-perl \
            libc-dev-bin \
            libc6-dev \
            libconfig-record-perl \
            libcpan-changes-perl \
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
            meson \
            ninja-build \
            perl \
            pkgconf \
            python3 \
            python3-docutils \
            xsltproc && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    sed -Ei 's,^# (en_US\.UTF-8 .*)$,\1,' /etc/locale.gen && \
    dpkg-reconfigure locales && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/$(basename /usr/bin/gcc)

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
