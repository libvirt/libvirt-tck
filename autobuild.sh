#!/bin/sh
#
# This script is used to Test::AutoBuild (http://www.autobuild.org)
# to perform automated builds of the Sys-Virt module

NAME=Sys-Virt-TCK

set -e

rm -rf MANIFEST blib _build Build

perl Build.PL install_base=$AUTOBUILD_INSTALL_ROOT

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
  if [ -n "$AUTOBUILD_COUNTER" ]; then
    EXTRA_RELEASE=".auto$AUTOBUILD_COUNTER"
  else
    NOW=`date +"%s"`
    EXTRA_RELEASE=".$USER$NOW"
  fi
  rpmbuild -ta --define "extra_release $EXTRA_RELEASE" --clean $NAME-*.tar.gz
fi

exit 0
