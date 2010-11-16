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

usage() {
  cmd="$0"
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


tap_fail() {
  txt=$(echo "$2" | gawk '{print substr($0,1,66)}')
  echo "not ok $1 - ${txt}"
  TAP_FAIL_LIST="$TAP_FAIL_LIST $1 "
  TAP_FAIL_CTR=$(($TAP_FAIL_CTR + 1))
  TAP_TOT_CTR=$(($TAP_TOT_CTR + 1))
}

tap_pass() {
  txt=$(echo "$2" | gawk '{print substr($0,1,66)}')
  echo "ok $1 - ${txt}"
  TAP_TOT_CTR=$(($TAP_TOT_CTR + 1))
}

tap_final() {
  [ -n "${TAP_FAIL_LIST}" ] && echo "FAILED tests ${TAP_FAIL_LIST}"

  okay=$(echo "($TAP_TOT_CTR-$TAP_FAIL_CTR)*100/$TAP_TOT_CTR" | bc -l)
  txt=$(echo $okay | gawk '{print substr($0,1,5)}')
  echo "Failed ${TAP_FAIL_CTR}/${TAP_TOT_CTR} tests, ${txt}% okay"
}

# A wrapper for mktemp in case it does not exist
# Echos the name of a secure temporary directory.
mktmpdir() {
  {
    tmp=$( (umask 077 && mktemp -d ./nwtst.XXXXXX) 2>/dev/null) &&
    test -n "$tmp" && test -d "$tmp"
  } ||
  {
    tmp=./nwtst$$-$RANDOM
    (umask 077 && mkdir "$tmp")
  } || { echo "failed to create secure temporary directory" >&2; exit 1; }
  echo "${tmp}"
  return 0
}


checkExpectedOutput() {
  xmlfile="$1"
  datafile="$2"
  flags="$3"
  skipregex="$4"

  tmpdir=$(mktmpdir)
  tmpfile=$tmpdir/file
  tmpfile2=$tmpdir/file2
  OIFS="${IFS}"

  if echo a | grep -E '(a|b)' >/dev/null 2>&1
  then EGREP='grep -E'
  else EGREP=egrep
  fi

  exec 4<"${datafile}"

  IFS=""

  read -r line <&4

  while [ "x${line}x" != "xx" ]; do
    cmd=$(printf %s\\n "${line##\#}")

    skip=0
    if [ "x${skipregex}x" != "xx" ]; then
        skip=$(echo "${cmd}" | ${EGREP} -c ${skipregex})
    fi

    eval "${cmd}" 2>&1 | tee "${tmpfile}" 1>/dev/null

    : >"${tmpfile2}"

    while :; do
      read -r line <&4

      case "${line}" in
      '#'*) letter="#";;
      *)    letter="";;
      esac

      if [ "x${letter}x" = "x#x" ] || [ "x${line}x" = "xx"  ]; then

        if [ ${skip} -ne 0 ]; then
          break
        fi

        diff "${tmpfile}" "${tmpfile2}" >/dev/null

        if [ $? -ne 0 ]; then
          if [ $(($flags & $FLAG_VERBOSE)) -ne 0 ]; then
            echo "FAIL ${xmlfile} : ${cmd}"
            diff "${tmpfile}" "${tmpfile2}"
          fi
          failctr=$(($failctr + 1))
          if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
            echo "tmp files: $tmpfile, $tmpfile2"
            echo "Press enter"
            read enter
          fi
          [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ] && \
            test_result $(($passctr + $failctr)) "" 1
          [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ] && \
            tap_fail $(($passctr + $failctr)) "${xmlfile} : ${cmd}"
        else
          passctr=$(($passctr + 1))
          [ $(($flags & $FLAG_VERBOSE)) -ne 0 ] && \
            echo "PASS ${xmlfile} : ${cmd}"
          [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ] && \
            test_result $(($passctr + $failctr)) "" 0
          [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ] && \
            tap_pass $(($passctr + $failctr)) "${xmlfile} : ${cmd}"
        fi

        break

      fi
      printf %s\\n "${line}" >> "${tmpfile2}"
    done
  done

  exec 4>&-

  rm -rf "${tmpdir}"

  IFS="${OIFS}"
}


doTest() {
  xmlfile="$1"
  datafile="$2"
  postdatafile="$3"
  flags="$4"

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


runTests() {
  xmldir="$1"
  hostoutdir="$2"
  flags="$3"
  tap_total=0 ctr=0

  datafiles=$(cd "${hostoutdir}";ls *.dat)

  if [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
    # Need to count the number of total tests
    for fil in ${datafiles}; do
      c=$(grep -c "^#" "${hostoutdir}/${fil}")
      tap_total=$(($tap_total + $c))
      ctr=$(($ctr + 1))
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

  if [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ]; then
    test_final $(($passctr + $failctr)) $failctr
  elif [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
    tap_final
  else
    echo ""
    echo "Summary: ${failctr} failures, ${passctr} passes,"
    if [ ${attachctr} -ne 0 ]; then
      echo "         ${attachfailctr} interface attachment failures with ${attachctr} attempts"
    fi
  fi
}


main() {
  prgname="$0"
  xmldir="networkxml2xmlin"
  hostoutdir="networkxml2hostout"
  flags=0

  while [ $# -ne 0 ]; do
    case "$1" in
    --help|-h|-\?) usage ${prgname}; exit 0;;
    --wait)         flags=$(($flags | $FLAG_WAIT    ));;
    --verbose)      flags=$(($flags | $FLAG_VERBOSE ));;
    --libvirt-test) flags=$(($flags | $FLAG_LIBVIRT_TEST ));;
    --tap-test)     flags=$(($flags | $FLAG_TAP_TEST ));;
    --force)        flags=$(($flags | $FLAG_FORCE_CLEAN ));;
    *) usage ${prgname}; exit 1;;
    esac
    shift 1
  done

  if [ $(uname) != "Linux" ]; then
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

    for name in $(virsh list | awk '{print $2}')
    do
      case ${name} in
      tck*)
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" == "x1" ] || \
           [ $(($flags & $FLAG_FORCE_CLEAN)) -ne 0 ]; then
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
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" == "x1" ] || \
           [ $(($flags & $FLAG_FORCE_CLEAN)) -ne 0 ]; then
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

  if [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ]; then
    curdir="${PWD}"
    . ./test-lib.sh
    if [ $? -ne 0 ]; then
        exit 1
    fi
    test_intro $this_test
    cd "${curdir}" || { echo "cd failed" >&2; exit 1; }
  fi

  runTests "${xmldir}" "${hostoutdir}" "${flags}"

  return 0
}

main "$@"
