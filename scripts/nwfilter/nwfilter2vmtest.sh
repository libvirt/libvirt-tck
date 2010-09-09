#!/bin/bash

ORIG_IFNAME="vnet0"
ATTACH_IFNAME="attach0"
TESTFILTERNAME="nwfiltertestfilter"
TESTVM2FWALLDATA="nwfilterxml2fwallout/testvm.fwall.dat"
VIRSH=virsh

uri=
if [ "x${LIBVIRT_TCK_CONFIG}x" != "xx" ]; then
     uri_exp=`cat ${LIBVIRT_TCK_CONFIG} | grep "^uri\s*=" | sed -e 's/uri\s*=\s*//' | tail -n 1`
     echo "$uri_exp"
     if [ "x${uri_exp}x" != "xx" ]; then
         eval "uri=${uri_exp}"
     fi
else
      uri="qemu:///system"
fi
LIBVIRT_URI=${uri}


FLAG_WAIT="$((1<<0))"
FLAG_ATTACH="$((1<<1))"
FLAG_VERBOSE="$((1<<2))"
FLAG_LIBVIRT_TEST="$((1<<3))"
FLAG_TAP_TEST="$((1<<4))"

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
 --noattach     : Skip tests that attach and detach a network interface
 --wait         : Wait for the user to press the enter key once an error
                  was detected
 --verbose      : Verbose output
 --libvirt-test : Use the libvirt test output format
 --tap-test     : TAP format output

This test will create two virtual machines. The one virtual machine
will use a filter called '${TESTFILTERNAME}', and reference the filter
'clean-traffic' which should be available by default with every install.
The other virtual machine will reference the filter 'tck-testcase' and will
have its filter permanently updated.
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

  okay=`echo "($TAP_TOT_CTR-$TAP_FAIL_CTR)*100/$TAP_TOT_CTR" | bc -l`
  echo "Failed ${TAP_FAIL_CTR}/${TAP_TOT_CTR} tests, ${okay:0:5}% okay"
}

# A wrapper for mktemp in case it does not exist
# Echos the name of a temporary file.
function mktmpfile() {
  local tmp
  type -P mktemp > /dev/null
  if [ $? -eq 0 ]; then
    tmp=$(mktemp -t nwfvmtest.XXXXXX)
    echo ${tmp}
  else
    while :; do
      tmp="/tmp/nwfvmtest.${RANDOM}"
      if [ ! -f ${tmp} ]; then
          touch ${tmp}
          chmod 666 ${tmp}
          echo ${tmp}
          break
      fi
    done
  fi
  return 0
}


function checkExpectedOutput() {
  local xmlfile="$1"
  local fwallfile="$2"
  local ifname="$3"
  local flags="$4"
  local skipregex="$5"
  local regex="s/${ORIG_IFNAME}/${ifname}/g"
  local cmd line tmpfile tmpfile2 skip

  tmpfile=`mktmpfile`
  tmpfile2=`mktmpfile`

  exec 4<${fwallfile}

  read <&4
  line="${REPLY}"

  while [ "x${line}x" != "xx" ]; do
    cmd=`echo ${line##\#} | sed ${regex}`

    skip=0
    if [ "x${skipregex}x" != "xx" ]; then
    	skip=`echo ${cmd} | grep -c -E ${skipregex}`
    fi

    eval ${cmd} 2>&1 | tee ${tmpfile} 1>/dev/null

    rm ${tmpfile2} 2>/dev/null
    touch ${tmpfile2}

    while [ 1 ]; do
      read <&4
      line="${REPLY}"

      if [ "${line:0:1}" == "#" ] || [ "x${line}x" == "xx"  ]; then

	if [ ${skip} -ne 0 ]; then
	  break
	fi

        diff ${tmpfile} ${tmpfile2} >/dev/null

        if [ $? -ne 0 ]; then
          if [ $((flags & FLAG_VERBOSE)) -ne 0 ]; then
            echo "FAIL ${xmlfile} : ${cmd}"
            diff ${tmpfile} ${tmpfile2}
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
      echo "${line}" | sed ${regex} >> ${tmpfile2}
    done
  done

  exec 4>&-

  rm -rf "${tmpfile}" "${tmpfile2}" 2>/dev/null
}


function doTest() {
  local xmlfile="$1"
  local fwallfile="$2"
  local vm1name="$3"
  local vm2name="$4"
  local flags="$5"
  local testnum="$6"
  local linenums ctr=0
  local tmpfile b msg rc

  if [ ! -r "${xmlfile}" ]; then
    echo "FAIL : Cannot access filter XML file ${xmlfile}."
    return 1
  fi

  ${VIRSH} nwfilter-define "${xmlfile}" > /dev/null

  checkExpectedOutput "${xmlfile}" "${fwallfile}" "${vm1name}" "${flags}" \
  	""

  checkExpectedOutput "${TESTFILTERNAME}" "${TESTVM2FWALLDATA}" \
  	"${vm2name}" "${flags}" ""

  if [ $((flags & FLAG_ATTACH)) -ne 0 ]; then

    tmpfile=`mktmpfile`

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

    ((attachctr++))

    if [ $rc -eq 0 ]; then
      checkExpectedOutput "${xmlfile}" "${fwallfile}" "${ATTACH_IFNAME}" \
        "${flags}" "(PRE|POST)ROUTING"
      checkExpectedOutput "${TESTFILTERNAME}" "${TESTVM2FWALLDATA}" \
        "${vm2name}" "${flags}" "(PRE|POST)ROUTING"
      msg=`${VIRSH} detach-device "${vm1name}" "${tmpfile}"`
      if [ $? -ne 0 ]; then
        echo "FAIL: Detach of interface failed."
      fi
    else
      if [ $((flags & FLAG_TAP_TEST)) -ne 0 ]; then
        # In case of TAP, run the test anyway so we get to the full number
        # of tests
        checkExpectedOutput "${xmlfile}" "${fwallfile}" "${ATTACH_IFNAME}" \
          "${flags}" "" #"(PRE|POST)ROUTING"
        checkExpectedOutput "${TESTFILTERNAME}" "${TESTVM2FWALLDATA}" \
          "${vm2name}" "${flags}" #"(PRE|POST)ROUTING"
      fi
       
      ((attachfailctr++))
      if [ $((flags & FLAG_VERBOSE)) -ne 0 ]; then
        echo "FAIL: Could not attach interface to vm ${vm1name}."
        if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
          echo "Press enter"
          read
        fi
      fi
    fi

    rm -rf ${tmpfile}
  fi

  return 0
}


function runTests() {
  local vm1name="$1"
  local vm2name="$2"
  local xmldir="$3"
  local fwalldir="$4"
  local flags="$5"
  local fwallfiles f c
  local tap_total=0 ctr=0

  pushd ${PWD} > /dev/null
  cd ${fwalldir}
  fwallfiles=`ls *.fwall`
  popd > /dev/null

  if [ $((flags & FLAG_TAP_TEST)) -ne 0 ]; then
    # Need to count the number of total tests
    for fil in ${fwallfiles}; do
      c=$(grep -c "^#" ${fwalldir}/${fil})
      ((tap_total+=c))
      ((ctr++))
    done
    c=$(grep -c "^#" "${TESTVM2FWALLDATA}")
    ((tap_total+=c*ctr))
    [ $((flags & FLAG_ATTACH)) -ne 0 ] && ((tap_total*=2))
    echo "1..${tap_total}"
  fi

  for fil in ${fwallfiles}; do
    f=${fil%%.fwall}
    doTest "${xmldir}/${f}.xml" "${fwalldir}/${fil}" "${vm1name}" \
           "${vm2name}" "${flags}"
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


function createVM() {
  local vmname="$1"
  local filtername="$2"
  local ipaddr="$3"
  local macaddr="$4"
  local flags="$5"
  local res
  local tmpfile='mktmpfile'

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
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    $(${VIRSH} undefine ${vmname})
    return 1
  fi

  [ $((flags & FLAG_VERBOSE)) -ne 0 ] && echo "Created VM ${vmname}."

  rm -rf ${tmpfile}

  return 0
}


function destroyVM() {
  local vmname="$1"
  local flags="$2"
  local res

  res=$(${VIRSH} destroy ${vmname})
  if [ $? -ne 0 ]; then
    echo "Could not destroy VM ${vmname} : ${res}"
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    return 1
  fi

  res=$(${VIRSH} undefine ${vmname})
  if [ $? -ne 0 ]; then
    echo "Could not undefine VM ${vmname} : ${res}"
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    return 1
  fi

  [ $((flags & FLAG_VERBOSE)) -ne 0 ] && echo "Destroyed VM ${vmname}."

  return 0
}


function createTestFilters() {
  local flags="$1"
  local tmpfile=`mktmpfile`
  local res

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
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    rm -rf ${tmpfile}
    return 1
  fi

  cat >${tmpfile} << EOF
<filter name="tck-testcase">
</filter>
EOF
  res=$(${VIRSH} nwfilter-define ${tmpfile})
  if [ $? -ne 0 ]; then
    echo "Could not define filter : ${res}"
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    rm -rf ${tmpfile}
    return 1
  fi

  rm -rf ${tmpfile}

  return 0
}


function deleteTestFilter() {
  local flags="$1"
  local res

  res=$(${VIRSH} nwfilter-undefine ${TESTFILTERNAME} 2>&1)
  if [ $? -ne 0 ]; then
    echo "Could not undefine filter : ${res}"
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    return 1
  fi
  res=$(${VIRSH} nwfilter-undefine tck-testcase 2>&1)
  if [ $? -ne 0 ]; then
    echo "Could not undefine filter : ${res}"
    if [ $((flags & FLAG_WAIT)) -ne 0 ]; then
      echo "Press enter."
      read
    fi
    return 1
  fi
  return 0
}


function main() {
  local prgname="$0"
  local vm1 vm2
  local xmldir="nwfilterxml2xmlin"
  local fwalldir="nwfilterxml2fwallout"
  local found=0 vms res
  local filtername="tck-testcase"
  local libvirtdpid=-1
  local flags OPWD

  ((flags=${FLAG_ATTACH}))

  while [ $# -ne 0 ]; do
    case "$1" in
    --help|-h|-\?) usage ${prgname}; exit 0;;
    --noattach)     ((flags ^= FLAG_ATTACH  ));;
    --wait)         ((flags |= FLAG_WAIT    ));;
    --verbose)      ((flags |= FLAG_VERBOSE ));;
    --libvirt-test) ((flags |= FLAG_LIBVIRT_TEST ));;
    --tap-test)     ((flags |= FLAG_TAP_TEST ));;
    *) usage ${prgname}; exit 1;;
    esac
    shift 1
  done

  if [ `uname` != "Linux" ]; then
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

    for name in `virsh nwfilter-list | awk '{print $2}'`
    do
      case ${name} in
      tck*)
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" == "x1" ]; then
          res=$(virsh nwfilter-undefine ${name} 2>&1)
          if [ $? -ne 0 ]; then
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
        if [ "x${LIBVIRT_TCK_AUTOCLEAN}" == "x1" ]; then
          res=$(virsh undefine ${name} 2>&1)
          if [ $? -ne 0 ]; then
            echo "Bail out! Could not undefine domain ${name}: ${res}"
            exit 1
          fi
        else
          echo "Bail out! Domain ${name} already exists, use --force to clean"
          exit 1
        fi
      esac
    done
  fi

  if [ $((flags & FLAG_LIBVIRT_TEST)) -ne 0 ]; then
    pushd ${PWD} > /dev/null
    . test-lib.sh
    if [ $? -ne 0 ]; then
        exit 1
    fi
    test_intro $this_test
    popd > /dev/null
  fi

  res=$(${VIRSH} capabilities 2>&1)

  vm1="tck-testvm${RANDOM}"
  vm2="tck-testvm${RANDOM}"

  createTestFilters "${flags}"
  if [ $? -ne 0 ]; then
  	exit 1;
  fi

  createVM "${vm1}" "tck-testcase" "10.2.2.2" "52:54:0:0:0:1" "${flags}"
  if [ $? -ne 0 ]; then
  	echo "Could not create VM ${vm1}. Exiting."
  	exit 1
  fi

  createVM "${vm2}" "${TESTFILTERNAME}" "10.1.1.1" "52:54:0:9f:33:da" \
           "${flags}"
  if [ $? -ne 0 ]; then
  	echo "Could not create VM ${vm2}. Exiting."
  	destroyVM "${vm1}" "${flags}"
  	exit 1
  fi

  runTests "${vm1}" "${vm2}" "${xmldir}" "${fwalldir}" "${flags}"

  destroyVM "${vm1}" "${flags}"
  destroyVM "${vm2}" "${flags}"
  deleteTestFilter "${flags}"

  return 0
}

main "$@"
