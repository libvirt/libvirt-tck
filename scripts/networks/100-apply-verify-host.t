#!/bin/sh

pwd=$(dirname -- "$0")

(cd -- "${pwd}"; sh ./networkApplyTest.sh --tap-test)
