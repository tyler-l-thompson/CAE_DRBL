#!/usr/bin/env bash
#
# DRBL optimized for the CAE Center
# Author: Tyler Thompson
# Date: July 1, 2019
#

image_dir="/images"
mac_dir="/alva/LabInfo/mac"
drbl_config_file="/etc/drbl/drblpush.conf"
image_port_1="bond0.142:1"
image_port_2="bond0.142:2"
multicast_port="bond0.142"
time_to_wait="1500"
log_watch_files="/var/log/syslog /var/log/clonezilla/ocsmgrd-notify.log /var/log/clonezilla/ocsmgrd.log /var/log/clonezilla/clonezilla-jobs.log"

declare lab_1 lab_2 image_name mac_path_1 mac_path_2 machine_count clients_to_wait image_path

#######################################
# Parses command line for arguments
# Globals: lab_1 lab_2 image_name
#   time_to_wait clients_to_wait
#   image_dir mac_dir mac_path_1
#   image_path
# Arguments: None
# Returns: None
#######################################
get_args() {
    local OPTIND
    local OPTARG

    usage="
    DRBL optimized for the CAE Center.
    This program is capable of imaging one or two labs at the same time.
    It is only capable of pushing an image to a lab, not pulling.
    If you only want to image one lab, pass NONE as the second lab.

    $(basename "$0") [-h|-l|-s|-v|-g|-w|-p] [-a LAB1] [-b LAB2] [-i IMAGE] [-t n] [-m n] [-d s] [-f s] [-o s]

    where:
        Non-Pushing Commands
            These commands will execute and then the program will exit without setting up DRBL or Clonezilla.

        -h          Show this help text.
        -l          List images available to push.
        -s          Stop Clonezilla and turn off imaging ports.
        -v          List the versions of DRBL, Clonezilla, and Partclone.
        -g          Tail the log files associated with DRBL and CLonezilla.
        -w   LAB    Wake computers in specified lab. Pass -a, -b, or -o for target MAC addresses.
        -p   int    Control imaging ports. 0 - Disable both ports. 1 - Enable one port. 2 - Enable two ports.

        Pushing Commands
            These commands will allow you to setup DRBL and Clonezilla on the server.

        -a   LAB1   The name of the first lab to image. e.g. C-224
        -b   LAB2   The name of the second lab to image. Omit if pushing to one lab.
        -i   IMAGE  The name of the image to push.

        Pushing Options
            These commands are optional and can only be used when pushing commands are present.

        -t   int    Time to wait until automatically starting the push in seconds. Default $time_to_wait seconds.
        -m   int    Number of clients to wait to connect before starting Clonezilla. Default is all clients.
        -d   DIR    Set the image directory path. Default: $image_dir
        -f   DIR    Set the mac address files directory path. Default: $mac_dir
        -o   FILE   Instead of pushing to lab, use a specified mac address file. -a and -b can be omitted. Use full path.
    "

    # print help if no parameters are passed
    if [[ -z $1 ]]; then
        echo "$usage"
        exit 0
    fi

    while getopts ':hlsvgw:p:a:b:i:t:m:f:d:o:' option; do
      case "$option" in
        h)
            echo "$usage"
            exit 0
            ;;
        l)
            ls "$image_dir"
            exit 0
            ;;
        s)
            dcs -nl clonezilla-stop
            drbl-all-service stop
            control_ports 0
            echo "Clonezilla has been stopped and image ports turned off."
            exit 0
            ;;
        v)
            dpkg -l drbl clonezilla partclone
            exit 0
            ;;
        g)
            tail -f ${log_watch_files}
            exit 0
            ;;
        w)
            wake_computers "${mac_dir}/${OPTARG}.txt"
            exit 0
            ;;
        p)
            control_ports "$OPTARG"
            exit 0
            ;;
        a)
            lab_1=$OPTARG
            mac_path_1="${mac_dir}/${lab_1}.txt"
            ;;
        b)
            lab_2=$OPTARG
            mac_path_2="${mac_dir}/${lab_2}.txt"
            ;;
        i)
            image_name=$OPTARG
            ;;
        t)
            time_to_wait=$OPTARG
            ;;
        m)
            clients_to_wait=$OPTARG
            ;;
        f)
            image_dir=$OPTARG
            ;;
        d)
            mac_dir=$OPTARG
            ;;
        o)
            mac_path_1=$OPTARG
            lab_1="NONE"
            ;;
        :)
            printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
       \?) printf "illegal option: -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
      esac
    done
    shift $((OPTIND - 1))

    # set full path for image
    image_path="${image_dir}/${image_name}"
}

#######################################
# Controls bringing up and down the
# networking ports used for imaging
# Globals: None
# Arguments:
#   0 - Both down
#   1 - One port up
#   2 - Both ports up
# Returns: None
#######################################
control_ports() {
    case $1 in
        0)
            ifconfig ${image_port_1} down
            ifconfig ${image_port_2} down
            ;;
        1)
            ifconfig ${image_port_1} up -broadcast 192.168.100.254
            ;;
        2)
            ifconfig ${image_port_1} up -broadcast 192.168.100.254
            ifconfig ${image_port_2} up -broadcast 192.168.101.254
            ;;
        *)
            ifconfig ${image_port_1} down
            ifconfig ${image_port_2} down
            ;;
    esac
    ifconfig ${image_port_1}
    ifconfig ${image_port_2}
}

#######################################
# Send wake on lan packets to a list of
# mac addresses defined in a file
# Globals: None
# Arguments: path to file
# Returns: None
#######################################
wake_computers() {
    while IFS='' read -r line || [[ -n "$line" ]]; do
        echo "Waking up: $line"
        etherwake -i ${multicast_port} ${line}
        sleep 1
    done < "$1"
}

#######################################
# Start clonezilla in disk restore mode
# Globals: clients_to_wait
# Arguments: None
# Returns: None
#######################################
clonezilla_start() {
    local disk_name=$(cat "$image_path/disk")
    if [[ -z "$clients_to_wait" ]]; then
        clients_to_wait=${machine_count}
    fi
    drbl-ocs -g auto -e1 auto -e2 -x -r -e -icds -j2 -a -k1 -scr -srel -sc0 -p poweroff --clients-to-wait ${clients_to_wait} --time-to-wait ${time_to_wait} -l en_US.UTF-8 --mcast-iface ${multicast_port} startdisk multicast_restore ${image_name} ${disk_name}
}

#######################################
# Setup drbl for pxe boot
# Globals: None
# Arguments: None
# Returns: None
#######################################
drbl_start() {
    local drbl_config_header="#Setup for general
[general]
domain=wmich.edu
nisdomain=morty
localswapfile=no
client_init=text
login_gdm_opt=
timed_login_time=
maxswapsize=
ocs_img_repo_dir=$image_dir
total_client_no=$machine_count
create_account=
account_passwd_length=8
hostname=morty-
purge_client=no
client_autologin_passwd=
client_root_passwd=
client_pxelinux_passwd=
set_client_system_select=no
use_graphic_pxelinux_menu=yes
set_DBN_client_audio_plugdev=no
open_thin_client_option=no
client_system_boot_timeout=
language=en_US.UTF-8
set_client_public_ip_opt=no
config_file=drblpush.conf
collect_mac=no
run_drbl_ocs_live_prep=yes
drbl_ocs_live_server=
clonezilla_mode=clonezilla_box_mode
live_client_branch=alternative
live_client_cpu_mode=i386
drbl_mode=none
drbl_server_as_NAT_server=yes
add_start_drbl_services_after_cfg=yes
continue_with_one_port=

#Setup for $image_port_1
[$image_port_1]
interface=$image_port_1
mac=$mac_path_1
ip_start=1
"

    local drbl_config_second_interface="#Setup for $image_port_2
[$image_port_2]
interface=$image_port_2
mac=$mac_path_2
ip_start=1
"

    echo "Generating config file: $drbl_config_file"
    echo "$drbl_config_header" > "$drbl_config_file"

    if [[ ! -z ${lab_2} ]]; then
        echo "$drbl_config_second_interface" >> "$drbl_config_file"
    fi

    drblpush -c ${drbl_config_file}
}

#######################################
# Get user confirmation on a prompt.
# If the user response is not 'y',
# then the program is exited.
# Globals: None
# Arguments: prompt
# Returns: None
#######################################
user_confirmation() {
    echo "$1 [y|n]"
    read user_input
    if [[ "$user_input" != "y" ]]; then
        echo "I'll stop here then."
        exit 0
    fi
}

#######################################
# Checks if the user running the script
# matches the argument passed.
# Globals: None
# Arguments: username
# Returns: None
#######################################
check_user() {
    # make sure we are root
    if [[ "$USER" != "$1" ]]; then
        err "This script must be run as $1."
        exit 0
    fi
}

#######################################
# Checks to make sure the mac address
# file for a given lab exists.
# Globals: None
# Arguments: lab
# Returns: None
#######################################
check_lab_name() {
    local lab_mac_file="$mac_dir"/"$1".txt
    echo "Checking if $lab_mac_file exists..."
    if [[ -f "$lab_mac_file" ]]; then
        echo "File found."
    else
        err "Lab mac file not found: $lab_mac_file"
        exit 1
    fi
}

#######################################
# Logs an error message with time stamp
# to STDERR
# Globals: None
# Arguments: error message
# Returns: None
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

#######################################
# Main function
# Globals: machine_count
# Arguments: all
# Returns: None
#######################################
main() {
    # check user is root
    check_user "root"

    # get command line arguments
    get_args "$@"

    # check if labs are the same
    if [[ ${lab_1} == ${lab_2} ]]; then
        err "You must pass two different labs as parameters."
        exit 1
    fi

    # check if lab mac files exits
    if [[ "$lab_1" != "NONE" ]]; then
        check_lab_name ${lab_1}
        if [[ ! -z ${lab_2} ]]; then
            check_lab_name ${lab_2}
        fi
     fi

    # check if image directory exits
    if [[ -z ${image_name} ]]; then
        err "Image name must be specified with -i. See -h help menu."
        exit 1
    fi
    if [[ -d ${image_path} ]]; then
        err "Image path $image_path found."
    else
        err "Image path $image_path not found. Double check spelling of image name."
        exit 1
    fi

    # calc number of computers
    machine_count=$(wc -l < ${mac_path_1})
    if [[ ! -z ${lab_2} ]]; then
        machine_count=$((${machine_count} + $(wc -l < ${mac_path_2})))
    fi
    echo "Total machines to image: $machine_count"

    # enable image ports
    user_confirmation "Ready to enable imaging ports?"
    if [[ ! -z ${lab_2} ]]; then
        control_ports 2
    else
        control_ports 1
    fi

    user_confirmation "Ready to setup DRBL?"
    drbl_start

    user_confirmation "Ready to start Clonezilla?"
    clonezilla_start

    user_confirmation "Ready to wakeup computers in ${lab_1}?"
    wake_computers ${mac_path_1}

    if [[ ! -z ${lab_2} ]]; then
        user_confirmation "Ready to wakeup computers in ${lab_2}?"
        wake_computers ${mac_path_2}
    fi

    echo "Beginning to tail log files. Press CTRL + C to return to command line"
    tail -f ${log_watch_files}
}

main "$@"
exit 0
