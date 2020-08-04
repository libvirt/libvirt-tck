FROM opensuse/leap:15.1

RUN zypper update -y && \
    zypper install -y \
           autoconf \
           automake \
           bash \
           bash-completion \
           ca-certificates \
           ccache \
           chrony \
           cppi \
           gcc \
           gdb \
           gettext \
           gettext-devel \
           git \
           glib2-devel \
           glibc-devel \
           glibc-locale \
           libgnutls-devel \
           libnl3-devel \
           libtirpc-devel \
           libtool \
           libxml2 \
           libxml2-devel \
           libxslt \
           lsof \
           make \
           net-tools \
           ninja \
           patch \
           perl \
           perl-App-cpanminus \
           perl-Archive-Tar \
           perl-CPAN-Changes \
           perl-Digest \
           perl-Digest-MD5 \
           perl-File-Slurp \
           perl-IO-String \
           perl-Module-Build \
           perl-NetAddr-IP \
           perl-Sub-Uplevel \
           perl-Test-Exception \
           perl-Test-Pod \
           perl-Test-Pod-Coverage \
           perl-XML-Twig \
           perl-XML-Writer \
           perl-XML-XPath \
           pkgconfig \
           python3 \
           python3-docutils \
           python3-pip \
           python3-setuptools \
           python3-wheel \
           rpcgen \
           rpm-build \
           screen \
           strace \
           sudo \
           vim \
           xz && \
    zypper clean --all && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/$(basename /usr/bin/gcc)

RUN pip3 install \
         meson==0.54.0

RUN cpanm --notest \
          Config::Record \
          IO::Compress::Bzip2 \
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
