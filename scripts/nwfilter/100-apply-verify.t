#!/bin/bash

pwd=$(dirname $0)

pushd ${PWD} > /dev/null

cd ${pwd}
bash ./nwfilter2vmtest.sh --tap-test --noattach

popd > /dev/null