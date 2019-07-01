#!/usr/bin/env bash
image_dir="/images"
mac_dir="/alva/LabInfo/mac"
drbl_config_file="/etc/drbl/drblpush.conf"
image_port_1="bond0.142:1"
image_port_2="bond0.142:2"
multicast_port="bond0.142"
time_to_wait="1500"

declare lab_1 lab_2 image_name mac_path_1 mac_path_2 machine_count clients_to_wait image_path

function get_args () {
    local OPTIND
    local OPTARG

    usage="
    DRBL optimized for the CAE Center.
    This program is capable of imaging one or two labs at the same time.
    It is only capable of pushing an image to a lab, not pulling.
    If you only want to image one lab, pass NONE as the second lab.

    $(basename "$0") [-h|-l|-s|-w|-p] [-a LAB1] [-b LAB2] [-i IMAGE] [-t n] [-m n] [-d s] [-f s] [-o s]

    where:
        Non-Pushing Commands
            These commands will execute and then the program will exit without setting up DRBL or Clonezilla.

        -h          Show this help text.
        -l          List images available to push.
        -s          Stop Clonezilla and turn off imaging ports.
        -w   LAB    Wake computers in specified lab
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
        -o   FILE   Instead of pushing to lab, use a specified mac address file. -a and -b can be omitted.
    "

    # print help if no parameters are passed
    if [[ -z $1 ]]; then
        echo "$usage"
        exit 0
    fi

    while getopts ':hlsw:p:a:b:i:t:m:f:d:o:' option; do
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

function control_ports () {
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

function wake_computers () {
    while IFS='' read -r line || [[ -n "$line" ]]; do
        echo "Waking up: $line"
        etherwake -i ${multicast_port} ${line}
        sleep 1
    done < "$1"
}

function clonezilla_start () {
    local disk_name=$(cat "$image_path/disk")
    if [[ -z "$clients_to_wait" ]]; then
        clients_to_wait=${machine_count}
    fi
    echo "drbl-ocs -g auto -e1 auto -e2 -x -r -e -icds -j2 -a -srel -sc0 -p poweroff --clients-to-wait ${clients_to_wait} --time-to-wait ${time_to_wait} -l en_US.UTF-8 --mcast-iface ${multicast_port} startdisk multicast_restore ${image_name} ${disk_name}"
}

function drbl_start () {
    local drbl_config_header="#Setup for general
[general]
domain=wmich.edu
nisdomain=morty
localswapfile=no
client_init=text
login_gdm_opt=
timed_login_time=
maxswapsize=
ocs_img_repo_dir=$image_path
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

    # drblpush -c ${drbl_config_file}
}

function user_confirmation () {
    echo "$1 [y|n]"
    read user_input
    if [[ "$user_input" != "y" ]]; then
        echo "I'll stop here then."
        exit 0
    fi
}

function check_user () {
    # make sure we are root
    if [[ "$USER" != "$1" ]]; then
        echo "This script must be run as $1."
        exit 0
    fi
}

function check_lab_name () {
    lab_mac_file="$mac_dir"/"$1".txt
    echo "Checking if $lab_mac_file exists..."
    if [[ -f "$lab_mac_file" ]]; then
        echo "File found."
    else
        echo "Lab mac file not found: $lab_mac_file"
        exit 1
    fi
}

function main () {
    # check user is root
    check_user "root"

    # get command line arguments
    get_args "$@"

    # check if labs are the same
    if [[ ${lab_1} == ${lab_2} ]]; then
        echo "You must pass two different labs as parameters."
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
        echo "Image name must be specified with -i. See -h help menu."
        exit 1
    fi
    if [[ -d ${image_path} ]]; then
        echo "Image path $image_path found."
    else
        echo "Image path $image_path not found. Double check spelling of image name."
        exit 1
    fi

    # calc number of computers
    machine_count=$(wc -l < ${mac_path_1})
    if [[ ! -z ${lab_2} ]]; then
        machine_count=$((${machine_count} + $(wc -l < ${mac_path_2})))
    fi
    echo "Total machines to image: $machine_count"

    # enable image ports
#    user_confirmation "Ready to enable imaging ports?"
#    if [[ ! -z ${lab_2} ]]; then
#        control_ports 2
#    else
#        control_ports 1
#    fi

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

}

main "$@"
exit 0
