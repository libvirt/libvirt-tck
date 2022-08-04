#!/bin/sh

ORIG_IFNAME="vnet0"
ATTACH_IFNAME="attach0"
TESTFILTERNAME="nwfiltertestfilter"
TESTVM2FWALLDATA="nwfilterxml2fwallout/testvm.fwall.dat"
VIRSH=virsh

PATTERN="^uri[ ]*:[ ]*"
uri=$(grep -E "$PATTERN" "$LIBVIRT_TCK_CONFIG" | \
      sed "/$PATTERN/ {s///;s/\"//g}" | \
      tail -1)

: "${uri:=qemu:///system}"

LIBVIRT_URI=${uri}

FLAG_WAIT="$((1<<0))"
FLAG_ATTACH="$((1<<1))"
FLAG_VERBOSE="$((1<<2))"
FLAG_LIBVIRT_TEST="$((1<<3))"
FLAG_TAP_TEST="$((1<<4))"
FLAG_FORCE_CLEAN="$((1<<5))"

# --ctdir original vs. --ctdir reply's meaning was inverted in
# netfilter at some point. We probe for it.
IPTABLES_CTRDIR_CORRECTED=0

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
  txt=$(echo "$2")
  echo "not ok $1 - ${txt}"
  TAP_FAIL_LIST="$TAP_FAIL_LIST $1 "
  TAP_FAIL_CTR=$(($TAP_FAIL_CTR + 1))
  TAP_TOT_CTR=$(($TAP_TOT_CTR + 1))
}

tap_pass() {
  txt=$(echo "$2")
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

checkExpectedOutput() {
  xmlfile="$1"
  fwallfile="$2"
  ifname="$3"
  flags="$4"
  skipregex="$5"
  skiptest="$6"
  regex="s/${ORIG_IFNAME}/${ifname}/g"

  tmpdir=$(mktmpdir)
  tmpfile=$tmpdir/file
  tmpfile2=$tmpdir/file2
  OIFS="${IFS}"

  exec 4<${fwallfile}

  IFS=""

  read -r line <&4

  while [ "x${line}x" != "xx" ]; do
    cmd=$(printf %s\\n ${line##\#} | sed ${regex})

    skip=0
    if [ "x${skipregex}x" != "xx" ]; then
        skip=$(printf %s\\n ${cmd} | grep -c -E ${skipregex})
    fi

    eval ${cmd} 2>&1 | tee ${tmpfile} 1>/dev/null

    rm ${tmpfile2} 2>/dev/null
    touch ${tmpfile2}

    while [ 1 ]; do
      read -r line <&4

      case "${line}" in
      '#'*)  letter="#";;
      *)     letter="";;
      esac

      if [ "x${letter}x" = "x#x" ] || [ "x${line}x" = "xx"  ]; then

        if [ ${skip} -ne 0 ]; then
          break
        fi

        if [ -n "${skiptest}" ]; then
          # treat all skips as passes
          passctr=$(($passctr + 1))
          [ $(($flags & $FLAG_VERBOSE)) -ne 0 ] && \
              echo "SKIP ${xmlfile} : ${cmd}"
          [ $(($flags & $FLAG_LIBVIRT_TEST)) -ne 0 ] && \
              test_result $(($passctr + $failctr)) "" 0
          [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ] && \
              tap_pass $(($passctr + $failctr)) "SKIP: ${xmlfile} : ${skiptest}"
          break
        fi

        # there was a problem in some version of ebtables that MAC addresses
        # formatted in uppercase breaking some of the tests; prevent these
        # breakages by converting the ebtables output to lowercase (test
        # outputs were already treated this way)
        sed -i "s/[A-Z]/\L&/g" "${tmpfile}"

        diff -w ${tmpfile} ${tmpfile2} >/dev/null

        if [ $? -ne 0 ]; then
          if [ $(($flags & $FLAG_VERBOSE)) -ne 0 ]; then
            echo "FAIL ${xmlfile} : ${cmd}"
            diff -w ${tmpfile} ${tmpfile2}
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
      printf %s\\n "${line}" | sed ${regex} >> ${tmpfile2}
    done
  done

  exec 4>&-

  rm -rf "${tmpdir}"

  IFS="${OIFS}"
}


doTest() {
  xmlfile="$1"
  fwallfile="$2"
  vm1name="$3"
  vm2name="$4"
  flags="$5"
  testnum="$6"
  ctr=0
  skiptest=""

  if [ ! -r "${xmlfile}" ]; then
      echo "FAIL : Cannot access filter XML file ${xmlfile}."
      return 1
  fi

  # Check whether we can run this test at all
  cmd=$(sed -n '1 s/^<\!--[	 ]*#\(.*\)#[	 ]*-->/\1/p' "${xmlfile}")
  if [ -n "${cmd}" ]; then
      eval "${cmd}" 2>/dev/null 1>/dev/null
      [ $? -ne 0 ] && skiptest="${cmd}"
  fi

  [ -z "${skiptest}" ] && ${VIRSH} nwfilter-define "${xmlfile}" > /dev/null

  checkExpectedOutput "${xmlfile}" "${fwallfile}" "${vm1name}" "${flags}" \
       "" "${skiptest}"

  checkExpectedOutput "${TESTFILTERNAME}" "${TESTVM2FWALLDATA}" \
       "${vm2name}" "${flags}" "" "${skiptest}"

  if [ $(($flags & $FLAG_ATTACH)) -ne 0 ]; then

    tmpdir=$(mktmpdir)
    tmpfile=$tmpdir/tmpfile

    b=`{ ${VIRSH} dumpxml ${vm1name} | tr -d "\n"; echo; } | \
       sed "s/.*\<interface.*source bridge='\([a-zA-Z0-9_]\+\)'.*<\/interface>.*/\1/"`

    cat >>${tmpfile} <<EOF
<interface type='bridge'>
  <source bridge='${b}'/>
  <mac address='52:54:00:11:22:33'/>
  <target dev='${ATTACH_IFNAME}'/>
  <filterref filter='tck-testcase'/>
</interface>
EOF
    msg=`${VIRSH} attach-device "${vm1name}" "${tmpfile}" > /dev/null`
    rc=$?

    attachctr=$(($attachctr + 1))

    if [ $rc -eq 0 ]; then
      checkExpectedOutput "${xmlfile}" "${fwallfile}" "${ATTACH_IFNAME}" \
        "${flags}" "(PRE|POST)ROUTING" "${skiptest}"
      checkExpectedOutput "${TESTFILTERNAME}" "${TESTVM2FWALLDATA}" \
        "${vm2name}" "${flags}" "(PRE|POST)ROUTING" "${skiptest}"
      msg=`${VIRSH} detach-device "${vm1name}" "${tmpfile}"`
      if [ $? -ne 0 ]; then
        echo "FAIL: Detach of interface failed."
      fi
    else
      if [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
        # In case of TAP, run the test anyway so we get to the full number
        # of tests
        checkExpectedOutput "${xmlfile}" "${fwallfile}" "${ATTACH_IFNAME}" \
          "${flags}" "" "${skiptest}" #"(PRE|POST)ROUTING"
        checkExpectedOutput "${TESTFILTERNAME}" "${TESTVM2FWALLDATA}" \
          "${vm2name}" "${flags}" "${skiptest}" #"(PRE|POST)ROUTING"
      fi

      attachfailctr=$(($attachfailctr + 1))
      if [ $(($flags & $FLAG_VERBOSE)) -ne 0 ]; then
        echo "FAIL: Could not attach interface to vm ${vm1name}."
        if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
          echo "Press enter"
          read enter
        fi
      fi
    fi

    rm -rf ${tmpdir}
  fi

  return 0
}


runTests() {
  vm1name="$1"
  vm2name="$2"
  xmldir="$3"
  fwalldir="$4"
  flags="$5"
  tap_total=0
  ctr=0

  fwallfiles=$(cd ${fwalldir}; ls *.fwall)

  if [ $(($flags & $FLAG_TAP_TEST)) -ne 0 ]; then
    # Need to count the number of total tests
    for fil in ${fwallfiles}; do
      c=$(grep -c "^#" ${fwalldir}/${fil})
      tap_total=$(($tap_total + $c))
      ctr=$(($ctr + 1))
    done
    c=$(grep -c "^#" "${TESTVM2FWALLDATA}")
    tap_total=$(($tap_total + $c * $ctr))
    [ $(($flags & $FLAG_ATTACH)) -ne 0 ] && tap_total=$(($tap_total * 2))
    echo "1..${tap_total}"
  fi

  for fil in ${fwallfiles}; do
    f=${fil%%.fwall}
    doTest "${xmldir}/${f}.xml" "${fwalldir}/${fil}" "${vm1name}" \
           "${vm2name}" "${flags}"
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


createVM() {
  vmname="$1"
  filtername="$2"
  ipaddr="$3"
  macaddr="$4"
  flags="$5"
  tmpdir=$(mktmpdir)
  tmpfile=$tmpdir/tmpfile

  cat > ${tmpfile} << EOF
  <domain type='kvm'>
    <name>${vmname}</name>
    <memory>32768</memory>
    <currentMemory>32768</currentMemory>
    <vcpu>1</vcpu>
    <os>
      <type>hvm</type>
      <boot dev='hd'/>
    </os>
    <features>
      <acpi/>
      <apic/>
    </features>
    <clock offset='utc'/>
    <on_poweroff>destroy</on_poweroff>
    <on_reboot>restart</on_reboot>
    <on_crash>destroy</on_crash>
    <devices>
      <interface type='bridge'>
        <mac address='${macaddr}'/>
        <source bridge='virbr0'/>
        <filterref filter='${filtername}'>
          <parameter name='IP' value='${ipaddr}'/>
          <parameter name='A' value='1.1.1.1'/>
          <parameter name='A' value='2.2.2.2'/>
          <parameter name='A' value='3.3.3.3'/>
          <parameter name='A' value='3.3.3.3'/>
          <parameter name='B' value='80'/>
          <parameter name='B' value='90'/>
          <parameter name='B' value='80'/>
          <parameter name='B' value='80'/>
          <parameter name='C' value='1080'/>
          <parameter name='C' value='1090'/>
          <parameter name='C' value='1100'/>
          <parameter name='C' value='1110'/>
          <parameter name='IPSETNAME' value='tck_test'/>
        </filterref>
        <target dev='${vmname}'/>
      </interface>
      <console type='pty'>
      </console>
      <input type='mouse' bus='ps2'/>
      <graphics type='vnc' port='-1' autoport='yes'/>
    </devices>
  </domain>
EOF

  res=$(${VIRSH} define ${tmpfile})
  if [ $? -ne 0 ]; then
    echo "Could not define VM ${vmname} : ${res}"
    return 1
  fi

  res=$(${VIRSH} start ${vmname})
  if [ $? -ne 0 ]; then
    echo "Could not start VM ${vmname} : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    ${VIRSH} undefine ${vmname}
    return 1
  fi

  [ $(($flags & $FLAG_VERBOSE)) -ne 0 ] && echo "Created VM ${vmname}."

  rm -rf ${tmpdir}

  return 0
}


destroyVM() {
  vmname="$1"
  flags="$2"

  res=$(${VIRSH} destroy ${vmname})
  if [ $? -ne 0 ]; then
    echo "Could not destroy VM ${vmname} : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    return 1
  fi

  res=$(${VIRSH} undefine ${vmname})
  if [ $? -ne 0 ]; then
    echo "Could not undefine VM ${vmname} : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    return 1
  fi

  [ $(($flags & $FLAG_VERBOSE)) -ne 0 ] && echo "Destroyed VM ${vmname}."

  return 0
}


createTestFilters() {
  flags="$1"
  tmpdir=$(mktmpdir)
  tmpfile=$tmpdir/tmpfile

  cat >${tmpfile} << EOF
<filter name="${TESTFILTERNAME}">
  <filterref filter='clean-traffic'/>

  <rule action='drop' direction='inout' priority='1000'>
    <all/>
  </rule>

  <rule action='drop' direction='inout' priority='1000'>
    <all-ipv6/>
  </rule>
</filter>
EOF
  res=$(${VIRSH} nwfilter-define ${tmpfile})
  if [ $? -ne 0 ]; then
    echo "Could not define filter : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    rm -rf ${tmpdir}
    return 1
  fi

  cat >${tmpfile} << EOF
<filter name="tck-testcase">
  <uuid>5c6d49af-b071-6127-b4ec-6f8ed4b55335</uuid>
</filter>
EOF
  res=$(${VIRSH} nwfilter-define ${tmpfile})
  if [ $? -ne 0 ]; then
    echo "Could not define filter : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    rm -rf ${tmpdir}
    return 1
  fi

  rm -rf ${tmpdir}

  return 0
}


deleteTestFilter() {
  flags="$1"

  res=$(${VIRSH} nwfilter-undefine ${TESTFILTERNAME} 2>&1)
  if [ $? -ne 0 ]; then
    echo "Could not undefine filter : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    return 1
  fi
  res=$(${VIRSH} nwfilter-undefine tck-testcase 2>&1)
  if [ $? -ne 0 ]; then
    echo "Could not undefine filter : ${res}"
    if [ $(($flags & $FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read enter
    fi
    return 1
  fi
  return 0
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
            echo "Bail out! Could not undefine nwfiler ${name}: ${res}"
            exit 0
          fi
        else
          echo "Bail out! Filter ${name} already exists, use --force to clean"
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
    cd "${curdir}" || { echo "cd failed" >&2; exit 1; }
  fi

  vm1="tck-$$1"
  vm2="tck-$$2"

  createTestFilters "${flags}"
  if [ $? -ne 0 ]; then
      exit 1;
  fi

  createVM "${vm1}" "tck-testcase" "10.2.2.2" "52:54:0:0:0:1" "${flags}"
  if [ $? -ne 0 ]; then
      echo "Could not create VM ${vm1}. Exiting."
      deleteTestFilter "${flags}"
      exit 1
  fi

  createVM "${vm2}" "${TESTFILTERNAME}" "10.1.1.1" "52:54:10:9f:33:da" \
           "${flags}"
  if [ $? -ne 0 ]; then
      echo "Could not create VM ${vm2}. Exiting."
      destroyVM "${vm1}" "${flags}"
      deleteTestFilter "${flags}"
      exit 1
  fi

  runTests "${vm1}" "${vm2}" "${xmldir}" "${fwalldir}" "${flags}"

  destroyVM "${vm1}" "${flags}"
  destroyVM "${vm2}" "${flags}"
  deleteTestFilter "${flags}"

  return 0
}

main "$@"
