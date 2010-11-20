#!/bin/sh

cleanup()
{
	virsh destroy tck-vm${idx} 2>/dev/null
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
	virsh create tck-vm${idx}.xml
	[ $? -ne 0 ] && break
	sleep 2
	virsh destroy tck-vm${idx}
	[ $? -ne 0 ] && break
	ctr=$(($ctr + 1))
	[ ! -w "${logfile}" ] && break
	echo "${ctr}" >> "${logfile}"
done

cleanup
