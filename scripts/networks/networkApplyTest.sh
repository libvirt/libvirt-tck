#!/bin/bash

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
}' < "$LIBVIRT_TCK_CONFIG")
: "${uri:=qemu:///system}"

LIBVIRT_URI=${uri}


FLAG_WAIT="$((1<<0))"
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

function usage() {
  local cmd="$0"
cat <<EOF
Usage: ${cmd} [--help|-h|-?] [--noattach] [--wait] [--verbose]
              [--libvirt-test] [--tap-test]

Options:
 --help,-h,-?   : Display this help screen.
 --wait         : Wait for the user to press the enter key once an error
                  was detected
 --verbose      : Verbose output
 --libvirt-test : Use the libvirt test output format
 --tap-test     : TAP format output
 --force        : Allow the automatic cleaning of VMs and networks
                  previously created by the TCK test suite

This test creates libvirt 'networks' and checks for expected results
(iptables, running processes (dnsmasq)) using provided xml and data
file respectively.
EOF
}


function tap_fail() {
  echo "not ok $1 - ${2:0:66}"
  TAP_FAIL_LIST+="$1 "
  ((TAP_FAIL_CTR++))
  ((TAP_TOT_CTR++))
}

function tap_pass() {
  echo "ok $1 - ${2:0:70}"
  ((TAP_TOT_CTR++))
}

function tap_final() {
  local okay

  [ -n "${TAP_FAIL_LIST}" ] && echo "FAILED tests ${TAP_FAIL_LIST}"

  okay=$(echo "($TAP_TOT_CTR-$TAP_FAIL_CTR)*100/$TAP_TOT_CTR" | bc -l)
  echo "Failed ${TAP_FAIL_CTR}/${TAP_TOT_CTR} tests, ${okay:0:5}% okay"
}

# A wrapper for mktemp in case it does not exist
# Echos the name of a secure temporary directory.
function mktmpdir() {
  local tmp
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


function checkExpectedOutput() {
  local xmlfile="$1"
  local datafile="$2"
  local flags="$3"
  local skipregex="$4"
  local cmd line tmpdir tmpfile tmpfile2 skip

  tmpdir=$(mktmpdir)
  tmpfile=$tmpdir/file
  tmpfile2=$tmpdir/file2

  if echo a | grep -E '(a|b)' >/dev/null 2>&1
  then EGREP='grep -E'
  else EGREP=egrep
  fi

  exec 4<"${datafile}"

  read <&4
  line="${REPLY}"

  while [ "x${line}x" != "xx" ]; do
    cmd=$(echo "${line##\#}")

    skip=0
    if [ "x${skipregex}x" != "xx" ]; then
        skip=$(echo "${cmd}" | ${EGREP} -c ${skipregex})
    fi

    eval "${cmd}" 2>&1 | tee "${tmpfile}" 1>/dev/null

    : >"${tmpfile2}"

    while :; do
      read <&4
      line="${REPLY}"

      if [ "${line:0:1}" == "#" ] || [ "x${line}x" == "xx"  ]; then

        if [ ${skip} -ne 0 ]; then
          break
        fi

        diff "${tmpfile}" "${tmpfile2}" >/dev/null

        if [ $? -ne 0 ]; then
          if [ $((flags & FLAG_VERBOSE)) -ne 0 ]; then
            echo "FAIL ${xmlfile} : ${cmd}"
            diff "${tmpfile}" "${tmpfile2}"
          fi
          ((failctr++))
          if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
                echo "tmp files: $tmpfile, $tmpfile2"
                echo "Press enter"
                read
          fi
          [ $((flags & FLAG_LIBVIRT_TEST)) -ne 0 ] && \
              test_result $((passctr+failctr)) "" 1
          [ $((flags & FLAG_TAP_TEST)) -ne 0 ] && \
             tap_fail $((passctr+failctr)) "${xmlfile} : ${cmd}"
        else
          ((passctr++))
          [ $((flags & FLAG_VERBOSE)) -ne 0 ] && \
              echo "PASS ${xmlfile} : ${cmd}"
          [ $((flags & FLAG_LIBVIRT_TEST)) -ne 0 ] && \
              test_result $((passctr+failctr)) "" 0
          [ $((flags & FLAG_TAP_TEST)) -ne 0 ] && \
              tap_pass $((passctr+failctr)) "${xmlfile} : ${cmd}"
        fi

        break

      fi
      echo "${line}" >> "${tmpfile2}"
    done
  done

  exec 4>&-

  rm -rf "${tmpdir}"
}


function doTest() {
  local xmlfile="$1"
  local datafile="$2"
  local postdatafile="$3"
  local flags="$4"
  local netname

  if [ ! -r "${xmlfile}" ]; then
    echo "FAIL : Cannot access filter XML file ${xmlfile}."
    return 1
  fi

  netname=$(sed -n 's/.*<name>\([^<]*\)<.*/\1/p' "${xmlfile}")

  ${VIRSH} net-create "${xmlfile}" > /dev/null

  checkExpectedOutput "${xmlfile}" "${datafile}" "${flags}" ""

  ${VIRSH} net-destroy "${netname}" > /dev/null

  if [ -r "${postdatafile}" ]; then
    checkExpectedOutput "${xmlfile}" "${postdatafile}" "${flags}" ""
  fi

  return 0
}


function runTests() {
  local xmldir="$1"
  local hostoutdir="$2"
  local flags="$3"
  local datafiles f c
  local tap_total=0 ctr=0

  pushd "${PWD}" > /dev/null
  cd "${hostoutdir}"
  datafiles=$(ls *.dat)
  popd > /dev/null

  if [ $((flags & FLAG_TAP_TEST)) -ne 0 ]; then
    # Need to count the number of total tests
    for fil in ${datafiles}; do
      c=$(grep -c "^#" "${hostoutdir}/${fil}")
      ((tap_total+=c))
      ((ctr++))
    done
    echo "1..${tap_total}"
  fi

  for fil in $datafiles; do
    case $fil in
      *.post.dat) continue;;
    esac
    f=${fil%%.dat}
    doTest "${xmldir}/${f}.xml" "${hostoutdir}/${fil}" \
           "${hostoutdir}/${f}.post.dat" "${flags}"
  done

  if [ $((flags & FLAG_LIBVIRT_TEST)) -ne 0 ]; then
    test_final $((passctr+failctr)) $failctr
  elif [ $((flags & FLAG_TAP_TEST)) -ne 0 ]; then
    tap_final
  else
    echo ""
    echo "Summary: ${failctr} failures, ${passctr} passes,"
    if [ ${attachctr} -ne 0 ]; then
      echo "         ${attachfailctr} interface attachment failures with ${attachctr} attempts"
    fi
  fi
}


function main() {
  local prgname="$0"
  local vm1 vm2
  local xmldir="networkxml2xmlin"
  local hostoutdir="networkxml2hostout"
  local res rc
  local flags

  while [ $# -ne 0 ]; do
    case "$1" in
    --help|-h|-\?) usage ${prgname}; exit 0;;
    --wait)         ((flags |= FLAG_WAIT    ));;
    --verbose)      ((flags |= FLAG_VERBOSE ));;
    --libvirt-test) ((flags |= FLAG_LIBVIRT_TEST ));;
    --tap-test)     ((flags |= FLAG_TAP_TEST ));;
    --force)        ((flags |= FLAG_FORCE_CLEAN ));;
    *) usage ${prgname}; exit 1;;
    esac
    shift 1
  done

  if [ $(uname) != "Linux" ]; then
    if [ $((flags & FLAG_TAP_TEST)) -ne 0 ]; then
      echo "1..0 # Skipped: Only valid on Linux hosts"
    else
      echo "This script will only run on Linux."
    fi
    exit 1;
  fi

  if [ $((flags & FLAG_TAP_TEST)) -ne 0 ]; then
    if [ "${LIBVIRT_URI}" != "qemu:///system" ]; then
        echo "1..0 # Skipped: Only valid for Qemu system driver"
        exit 0
    fi

    for name in $(virsh list | awk '{print $2}')
    do
      case ${name} in
      tck*)
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" == "x1" -o \
             $((flags & FLAG_FORCE_CLEAN)) -ne 0 ]; then
          res=$(virsh destroy  ${name} 2>&1)
          res=$(virsh undefine ${name} 2>&1)
          if [ $? -ne 0 ]; then
            echo "Bail out! Could not undefine VM ${name}: ${res}"
            exit 0
          fi
        else
          echo "Bail out! TCK VMs from previous tests still exist, use --force to clean"
          exit 1
        fi
      esac
    done

    for name in $(virsh net-list | sed -n '3,$p')
    do
      case ${name} in
      tck*)
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" == "x1" -o \
             $((flags & FLAG_FORCE_CLEAN)) -ne 0 ]; then
          res=$(virsh net-destroy ${name} 2>&1)
          rc=$?
          res=$(virsh net-undefine ${name} 2>&1)
          if [ $rc -ne 0 -a $? -ne 0 ]; then
            echo "Bail out! Could not destroy/undefine network ${name}: ${res}"
            exit 1
          fi
        else
          echo "Bail out! Network ${name} already exists, use --force to clean"
          exit 1
        fi
      esac
    done
  fi

  if [ $((flags & FLAG_LIBVIRT_TEST)) -ne 0 ]; then
    pushd "${PWD}" > /dev/null
    . ./test-lib.sh
    if [ $? -ne 0 ]; then
        exit 1
    fi
    test_intro $this_test
    popd > /dev/null
  fi

  res=$(${VIRSH} capabilities 2>&1)

  runTests "${xmldir}" "${hostoutdir}" "${flags}"

  return 0
}

main "$@"
