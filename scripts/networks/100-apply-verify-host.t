#!/bin/bash

pwd=$(dirname $0)

pushd ${PWD} > /dev/null

cd ${pwd}
bash ./networkApplyTest.sh --tap-test

popd > /dev/null
