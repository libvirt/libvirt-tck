#!/bin/sh

VIRSH=virsh

# For each line starting with uri=, remove the prefix and set the hold
# space to the rest of the line.  Then at file end, print the hold
# space, which is effectively the last uri= line encountered.
uri=$(sed -n '/^uri[     ]*=[     ]*/ {
  s///
  h
}
$ {
  x
  p
}' < "$LIBVIRT_TCK_CONFIG" | sed -e 's/"//g')
: "${uri:=qemu:///system}"

LIBVIRT_URI=${uri}

FLAG_WAIT="$((1<<0))"
FLAG_ATTACH="$((1<<1))"
FLAG_VERBOSE="$((1<<2))"
FLAG_LIBVIRT_TEST="$((1<<3))"
FLAG_TAP_TEST="$((1<<4))"
FLAG_FORCE_CLEAN="$((1<<5))"

failctr=0
passctr=0
attachfailctr=0
attachctr=0

TAP_FAIL_LIST=""
TAP_FAIL_CTR=0
TAP_TOT_CTR=0

usage() {
  cmd="$0"
cat <<EOF
Usage: ${cmd} [--help|-h|-?] [--noattach] [--wait] [--verbose]
              [--libvirt-test] [--tap-test]

Options:
 --help,-h,-?   : Display this help screen.
 --noattach     : Skip tests that attach and detach a network interface
 --wait         : Wait for the user to press the enter key once an error
                  was detected
 --verbose      : Verbose output
 --libvirt-test : Use the libvirt test output format
 --tap-test     : TAP format output
 --force        : Allow the automatic cleaning of VMs and nwfilters
                  previously created by the TCK test suite

This test will create two virtual machines. The one virtual machine
will use a filter called '${TESTFILTERNAME}', and reference the filter
'clean-traffic' which should be available by default with every install.
The other virtual machine will reference the filter 'tck-testcase' and will
have its filter permanently updated.
EOF
}


tap_fail() {
  txt=$(echo "$2" | gawk '{print substr($0,1,66)}')
  echo "not ok $1 - ${txt}"
  TAP_FAIL_LIST="$TAP_FAIL_LIST $1 "
  TAP_FAIL_CTR=$(($TAP_FAIL_CTR + 1))
  TAP_TOT_CTR=$(($TAP_TOT_CTR + 1))
}

tap_pass() {
  txt=$(echo "$2" | gawk '{print substr($0,1,70)}')
  echo "ok $1 - ${txt}"
  TAP_TOT_CTR=$(($TAP_TOT_CTR + 1))
}

tap_final() {
  [ -n "${TAP_FAIL_LIST}" ] && echo "FAILED tests ${TAP_FAIL_LIST}"

  okay=`echo "($TAP_TOT_CTR-$TAP_FAIL_CTR)*100/$TAP_TOT_CTR" | bc -l`
  txt=$(echo $okay | gawk '{print substr($0,1,5)}')
  echo "Failed ${TAP_FAIL_CTR}/${TAP_TOT_CTR} tests, ${txt}% okay"
}

# A wrapper for mktemp in case it does not exist
# Echos the name of a temporary file.
mktmpdir() {
  {
    tmp=$( (umask 077 && mktemp -d ./nwfvmtest.XXXXXX) 2>/dev/null) &&
    test -n "$tmp" && test -d "$tmp"
  } ||
  {
    tmp=./nwfvmtest$$-$RANDOM
    (umask 077 && mkdir "$tmp")
  } || { echo "failed to create secure temporary directory" >&2; exit 1; }
  echo "${tmp}"
  return 0
}


PRGDIR="./concurrency"
CREATE_DES_VM1="${PRGDIR}/start-destroy-vm.sh 1"
CREATE_DES_VM2="${PRGDIR}/start-destroy-vm.sh 2"
CHG_FILTER_VM1="${PRGDIR}/chg-vm-filter.sh 1"
CHG_FILTER_VM2="${PRGDIR}/chg-vm-filter.sh 2"


startPrgs()
{
  flags="$1"

  sh ${CHG_FILTER_VM1} "$4" 2>&1 >/dev/null &
  [ $? -ne 0 ] && \
    ( killPrgs "${flags}" "Could not start program 3" ; return 1; )
  CHG_FILTER_VM1_THR=$!

  sh ${CHG_FILTER_VM2} "$5" 2>&1 >/dev/null &
  [ $? -ne 0 ] && \
    ( killPrgs "${flags}" "Could not start program 4" ; return 1; )
  CHG_FILTER_VM2_THR=$!

  # Give some time for the filters to be created
  sleep 2

  sh ${CREATE_DES_VM1} "$2" 2>&1 >/dev/null &
  [ $? -ne 0 ] && \
    ( killPrgs "${flags}" "Could not start program 1" ; return 1; )
  CREATE_DES_VM1_THR=$!

  sh ${CREATE_DES_VM2} "$3" 2>&1 >/dev/null &
  [ $? -ne 0 ] && \
    ( killPrgs "${flags}" "Could not start program 2" ; return 1; )
  CREATE_DES_VM2_THR=$!

}


killPrgs()
{
  msg="$1"

  # terminate all process
  [ "x${CREATE_DES_VM1_THR}x" != "xx" ] && \
    kill -2 ${CREATE_DES_VM1_THR}
  [ "x${CREATE_DES_VM2_THR}x" != "xx" ] && \
    kill -2 ${CREATE_DES_VM2_THR}
  [ "x${CHG_FILTER_VM1_THR}x" != "xx" ] && \
    kill -2 ${CHG_FILTER_VM1_THR}
  [ "x${CHG_FILTER_VM2_THR}x" != "xx" ] && \
    kill -2 ${CHG_FILTER_VM2_THR}

  wait
}


testFail()
{
  flags="$1"
  msg="$2"

  failctr=$(($failctr + 1))
  if [ $(($flags & $FLAG_VERBOSE)) -ne 0 ]; then
    echo "FAIL : ${msg}"
  fi
  if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
    echo "Press enter"
    read enter
  fi
  [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ] && \
    test_result $(($passctr + $failctr)) "" 1
  [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ] && \
    tap_fail $(($passctr + $failctr)) "${msg}"
}


testPass()
{
  flags="$1"
  msg="$2"

  passctr=$(($passctr + 1))
  if [ $(($flags & $FLAG_VERBOSE)) -ne 0 ]; then
    echo "PASS : ${msg}"
  fi
  [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ] && \
    test_result $(($passctr + $failctr)) "" 0
  [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ] && \
    tap_pass $(($passctr + $failctr)) "${msg}"
}

cleanup()
{
  rm -rf "$1"
  killPrgs
  exit $2
}

missedSteps()
{
  cur="$1"
  exp="$2"
  flags="$3"

  while [ $cur -lt $exp ]; do
    cur=$(($cur + 1))
    testFail "${flags}" "$4 ${cur}"
  done
}

runTest()
{
  flags="$1"

  passctr=0
  failctr=0

  tmpdir=`mktmpdir`
  failctr=0
  passctr=0
  logvm1="${PWD}/${tmpdir}/logvm1"
  logvm2="${PWD}/${tmpdir}/logvm2"
  logfivm1="${PWD}/${tmpdir}/logfivm1"
  logfivm2="${PWD}/${tmpdir}/logfivm2"

  # exp. number of steps each 'thread' has to do
  steps=10

  steps_vm1=0
  steps_vm2=0
  steps_fivm1=0
  steps_fivm2=0

  trap "cleanup ${tmpdir} 1" INT

  if [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
    # Need to display the number of total tests
    tap_total=$((4 * $steps))
    echo "1..${tap_total}"
  fi

  startPrgs "${flags}" "${logvm1}" "${logvm2}" \
    "${logfivm1}" "${logfivm2}"

  [ $? -ne 0 ] && rm -rf "${tmpdir}" && return 1;

  # Test runs for a maximum of 5 minutes
  now=`date +%s`
  test_end=$(($now + 5 * 60))

  while :;
  do
    # The logs give us the number of cycles the VMs were created
    # and destroyed.
    val=$(tail -n 1 "${logvm1}" 2>/dev/null )
    while [ -n "${val}" ] && \
          [ $steps_vm1 -lt $steps ] && [ $steps_vm1 -lt $val ]; do
      steps_vm1=$(($steps_vm1 + 1))
      testPass "${flags}" \
        "VM1 log - step ${steps_vm1}"
    done

    val=$(tail -n 1 "${logvm1}" 2>/dev/null )
    while [ -n "${val}" ] && \
          [ $steps_vm2 -lt $steps ] && [ $steps_vm2 -lt $val ]; do
      steps_vm2=$(($steps_vm2 + 1))
      testPass "${flags}" \
        "VM2 log - step ${steps_vm2}"
    done

    # The changing of the filters is expected to work much faster
    val=$(cat "${logfivm1}" 2>/dev/null | tail -n 1)
    while [ -n "${val}" ] && \
          [ $steps_fivm1 -lt $steps ] && [ $steps_fivm1 -lt $(($val / 50)) ];
    do
      steps_fivm1=$(($steps_fivm1 + 1))
      testPass "${flags}" \
        "VM1 filter log - step ${steps_fivm1}"
    done

    val=$(cat "${logfivm2}" 2>/dev/null | tail -n 1)
    while [ -n "${val}" ] && \
          [ $steps_fivm2 -lt $steps ] && [ $steps_fivm2 -lt $(($val / 50)) ];
    do
      steps_fivm2=$(($steps_fivm2 + 1))
      testPass "${flags}" \
        "VM2 filter log - step ${steps_fivm2}"
    done

    [ $steps_vm1 -ge $steps ] && \
       [ $steps_vm2   -ge $steps ] && \
       [ $steps_fivm1 -ge $steps ] && \
       [ $steps_fivm2 -ge $steps ] && \
       break

    now=`date +%s`
    [ $now -gt $test_end ] && break

    sleep 4
  done

  missedSteps $steps_vm1   $steps $flags "VM1 log - step "
  missedSteps $steps_vm2   $steps $flags "VM2 log - step "
  missedSteps $steps_fivm1 $steps $flags "VM1 filter log - step "
  missedSteps $steps_fivm1 $steps $flags "VM2 filter log - step "

  [ $now -gt $test_end ] && \
    echo "Bail out! Not all tests finished before test expired. Busy system?"

  cleanup "${tmpdir}" 0
}


main() {
  prgname="$0"
  xmldir="nwfilterxml2xmlin"
  fwalldir="nwfilterxml2fwallout"
  found=0
  filtername="tck-testcase"
  libvirtdpid=-1

  flags=${FLAG_ATTACH}

  while [ $# -ne 0 ]; do
    case "$1" in
    --help|-h|-\?) usage ${prgname}; exit 0;;
    --noattach)     flags=$(($flags & ~$FLAG_ATTACH));;
    --wait)         flags=$(($flags | $FLAG_WAIT    ));;
    --verbose)      flags=$(($flags | $FLAG_VERBOSE ));;
    --libvirt-test) flags=$(($flags | $FLAG_LIBVIRT_TEST ));;
    --tap-test)     flags=$(($flags | $FLAG_TAP_TEST ));;
    --force)        flags=$(($flags | $FLAG_FORCE_CLEAN ));;
    *) usage ${prgname}; exit 1;;
    esac
    shift 1
  done

  if [ `uname` != "Linux" ]; then
    if [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
      echo "1..0 # Skipped: Only valid on Linux hosts"
    else
      echo "This script will only run on Linux."
    fi
    exit 1;
  fi

  if [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
    if [ "${LIBVIRT_URI}" != "qemu:///system" ]; then
        echo "1..0 # Skipped: Only valid for Qemu system driver"
        exit 0
    fi

    for name in `virsh list --all | awk '{print $2}'`
    do
      case ${name} in
      tck*)
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" = "x1" ] || \
           [ $(($flags & $FLAG_FORCE_CLEAN)) -ne 0 ]; then
          res=$(virsh destroy  ${name} 2>&1)
          rc1=$?
          res=$(virsh undefine ${name} 2>&1)
          rc2=$?
          if [ $rc1 -ne 0 ] && [ $rc2 -ne 0 ]; then
            echo "Bail out! Could not destroy VM ${name}: ${res}"
            exit 0
          fi
        else
          echo "Bail out! VM ${name} already exists, use --force to clean"
          exit 1
        fi
      esac
    done

    for name in `virsh nwfilter-list | awk '{print $2}'`
    do
      case ${name} in
      tck*)
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" = "x1" ] || \
           [ $(($flags & $FLAG_FORCE_CLEAN)) -ne 0 ]; then
          res=$(virsh nwfilter-undefine ${name} 2>&1)
          if [ $? -ne 0 ]; then
            echo "Bail out! Could not undefine filter ${name}: ${res}"
            exit 1
          fi
        else
          echo "Bail out! Filter ${name} already exists, use --force to clean"
          exit 1
        fi
      esac
    done
  fi

  if [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ]; then
    curdir="${PWD}"
    . test-lib.sh
    if [ $? -ne 0 ]; then
        exit 1
    fi
    test_intro $this_test
    cd "${curdir}" || { echo "cd failed" >&2; exit 1;}
  fi

  runTest "${flags}"

  return 0
}

main "$@"
