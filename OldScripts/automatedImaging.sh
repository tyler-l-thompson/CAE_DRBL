#!/bin/bash
RUNAS="root"
main(){
	enablePorts
	setupDrbl
	setupClonezilla
}
enablePorts(){
	printf "\nSetting up ports for imaging...\n"
	sleep 1
	su "$RUNAS" -c "ifconfig eno3 up -broadcast 192.168.100.254"
	su "$RUNAS" -c "ifconfig eno4 up -broadcast 192.168.101.254"
	sleep 1
	su "$RUNAS" -c "ifconfig"
	printf "\nPorts have been setup for imaging.\n"
	sleep 1
}
setupDrbl(){
	printf "\nEnter the lab you would like to image [a|b|c|d|e|f|bc|de|printstations]: "
	read lab
	case "$lab" in
		a|b|c|d|e|f|bc|de|printstations)
			printf "\nSetting up drbl to handle computers in ${lab^^} lab...\n"
			sleep 1
			CONFIG=/automatedImaging/drbl/drblpush-${lab^^}-Lab.conf
			su "$RUNAS" -c "/usr/sbin/drblpush -c $CONFIG"
			printf "\nDrbl has been setup to handle computers in ${lab^^} lab.\n"
			sleep 1
			;;
		*)
			printf "\nInvalid input.\n"
			setupDrbl
	esac
}
setupClonezilla(){
	dir /images
	printf "\nEnter name of image to restore: "
	read imageName
	printf "\nEnter number of clients to image: "
	read clients
	printf "\nSetting up CloneZilla to restore image $imageName to $clients clients...\n"
	sleep 1
	drbl-ocs -b -g auto -e1 auto -e2 -x -j2 -icds -icrc -scr -sc -sc0 -ntfs-ok -p poweroff --clients-to-wait $clients --max-time-to-wait 6000  -l en_US.UTF-8 startdisk multicast_restore $imageName sda 
	printf "\nCloneZilla has been setup to restore $imageName to $clients clients. You can now PXE boot the computers.\n"
	printf "After the computers have finished imageing, you can run 'image off' to disable the imaging ports and restore the internet connection to the computers.\n"
	sleep 1
}
case "$1" in
	off)
		printf "\nShutting down CloneZilla...\n"
		sleep 1
		su "$RUNAS" -c "drbl-ocs stop"
		printf "\nCloneZilla has been shutdown.\n"
		sleep 1
		printf "\nDisabling ports used for imaging.\n"
		sleep 1
		su "$RUNAS" -c "ifconfig eno3 down"
		su "$RUNAS" -c "ifconfig eno4 down"
		su "$RUNAS" -c "ifconfig"
		printf "\nImaging ports have been disabled.\n"
		printf "Done."
		;;
	*)
		main
		;;
esac
