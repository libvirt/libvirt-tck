#!/bin/sh

export LIBVIRT_TCK_CONFIG=$(realpath ${LIBVIRT_TCK_CONFIG:=./conf/default.yml})
cwd=$(dirname -- "$0")

(cd -- "${cwd}"; sh ./nwfilter2vmtest.sh --tap-test --noattach)
