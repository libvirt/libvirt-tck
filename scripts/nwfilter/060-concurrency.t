#!/bin/sh

cwd=$(dirname -- "$0")

(cd -- "${cwd}" && sh ./nwfilter_concurrent.sh --tap-test)
