#!/bin/sh
cleanup()
{
    virsh nwfilter-undefine tck-vm${idx}-filter 2>/dev/null
}

cd $(dirname "$0")
ctr=0
[ -z "$2" ] && exit 1
idx="$1"
logfile="$2"
rm -f "${logfile}"
touch "${logfile}"

trap cleanup 2

while :;
do
    virsh nwfilter-define tck-vm${idx}-filter1.xml
    [ $? -ne 0 ] && break
    [ ! -w "${logfile}" ] && break
    virsh nwfilter-define tck-vm${idx}-filter2.xml
    [ $? -ne 0 ] && break
    ctr=$(($ctr + 1))
    [ ! -w "${logfile}" ] && break
    echo "${ctr}" >> "${logfile}"
done

cleanup
