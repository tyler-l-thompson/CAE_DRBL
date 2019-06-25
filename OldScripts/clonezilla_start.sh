#!/bin/bash
if [ -z $1 ] 
then
	echo "Example Usage: clonzilla_start.sh HPZ2-ServerTest-190619"
	exit 0
fi

drbl-ocs -g auto -e1 auto -e2 -x -r -e -icds -j2 -a -srel -sc0 -p poweroff --clients-to-wait 1 -l en_US.UTF-8 --mcast-iface bond0.142 startdisk multicast_restore $1 nvme0n1
