#!/bin/sh
#
# Copyright (C) 2009 Red Hat, Inc.
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

NAME=Sys-Virt-TCK

set -e

rm -rf MANIFEST blib _build Build

perl Build.PL install_base=$HOME/builder

./Build
./Build manifest


if [ -z "$USE_COVER" ]; then
  perl -MDevel::Cover -e '' 1>/dev/null 2>&1 && USE_COVER=1 || USE_COVER=0
fi

if [ -z "$SKIP_TESTS" -o "$SKIP_TESTS" = "0" ]; then
  if [ "$USE_COVER" = "1" ]; then
    ./Build test
  else
    ./Build test
  fi
fi

./Build install

rm -f $NAME-*.tar.gz
./Build dist

if [ -f /usr/bin/rpmbuild ]; then
  NOW=`date +"%s"`
  EXTRA_RELEASE=".$USER$NOW"
  rpmbuild -ta --define "extra_release $EXTRA_RELEASE" --clean $NAME-*.tar.gz
fi

exit 0
