# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

function install_buildenv() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get dist-upgrade -y
    apt-get install --no-install-recommends -y \
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
            libcpan-changes-perl \
            libdigest-perl \
            libdigest-perl-md5-perl \
            libextutils-cbuilder-perl \
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
            libyaml-perl \
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
            xsltproc
    sed -Ei 's,^# (en_US\.UTF-8 .*)$,\1,' /etc/locale.gen
    dpkg-reconfigure locales
    dpkg-query --showformat '${Package}_${Version}_${Architecture}\n' --show > /packages.txt
    mkdir -p /usr/libexec/ccache-wrappers
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc
    /usr/bin/pip3 install meson==0.56.0
}

export CCACHE_WRAPPERSDIR="/usr/libexec/ccache-wrappers"
export LANG="en_US.UTF-8"
export MAKE="/usr/bin/make"
export NINJA="/usr/bin/ninja"
export PYTHON="/usr/bin/python3"
