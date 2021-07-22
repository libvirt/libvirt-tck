#!/bin/sh

pwd=$(dirname -- "$0")

(cd -- "${pwd}" && sh ./nwfilter_concurrent.sh --tap-test)
