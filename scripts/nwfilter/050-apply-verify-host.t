#!/bin/sh

pwd=$(dirname -- "$0")

(cd -- "${pwd}"; sh ./nwfilter2vmtest.sh --tap-test --noattach)
