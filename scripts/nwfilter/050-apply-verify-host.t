#!/bin/sh

cwd=$(dirname -- "$0")

(cd -- "${cwd}"; sh ./nwfilter2vmtest.sh --tap-test --noattach)
