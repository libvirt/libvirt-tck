#!/bin/sh

cwd=$(dirname -- "$0")

(cd -- "${cwd}"; sh ./networkApplyTest.sh --tap-test)
