#!/usr/bin/env bash
image_dir=/images
mac_dir=/alva/LabInfo/mac
image_port_1="bond0.142:1"
image_port_2="bond0.142:2"
multicast_port="bond0.142"
time_to_wait="1500"

Lab_1=$1
Lab_2=$2
image_name=$3
image_path=${image_dir}/${image_name}
install_dir=$(dirname $(pwd -P))
drbl_config_file="/etc/drbl/drblpush.conf"
mac_path_1="${mac_dir}/${Lab_1}.txt"
mac_path_2="${mac_dir}/${Lab_2}.txt"

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
    local machine_count=$1
    local disk_name=$(cat "${image_path}/disk")
    drbl-ocs -g auto -e1 auto -e2 -x -r -e -icds -j2 -a -srel -sc0 -p poweroff --clients-to-wait ${machine_count} --time-to-wait ${time_to_wait} -l en_US.UTF-8 --mcast-iface ${multicast_port} startdisk multicast_restore ${image_name} ${disk_name}
}

function drbl_start () {
    local machine_count=$1
    echo "Generating config file: ${drbl_config_file}"

    # prep the drbl config header
    echo "#Setup for general" > ${drbl_config_file}
    echo "[general]" >> ${drbl_config_file}
    echo "domain=wmich.edu" >> ${drbl_config_file}
    echo "nisdomain=morty" >> ${drbl_config_file}
    echo "localswapfile=no" >> ${drbl_config_file}
    echo "client_init=text" >> ${drbl_config_file}
    echo "login_gdm_opt=" >> ${drbl_config_file}
    echo "timed_login_time=" >> ${drbl_config_file}
    echo "maxswapsize=" >> ${drbl_config_file}
    echo "ocs_img_repo_dir=${image_dir}" >> ${drbl_config_file}
    echo "total_client_no=${machine_count}" >> ${drbl_config_file}
    echo "create_account=" >> ${drbl_config_file}
    echo "account_passwd_length=8" >> ${drbl_config_file}
    echo "hostname=morty-" >> ${drbl_config_file}
    echo "purge_client=no" >> ${drbl_config_file}
    echo "client_autologin_passwd=" >> ${drbl_config_file}
    echo "client_root_passwd=" >> ${drbl_config_file}
    echo "client_pxelinux_passwd=" >> ${drbl_config_file}
    echo "set_client_system_select=no" >> ${drbl_config_file}
    echo "use_graphic_pxelinux_menu=yes" >> ${drbl_config_file}
    echo "set_DBN_client_audio_plugdev=no" >> ${drbl_config_file}
    echo "open_thin_client_option=no" >> ${drbl_config_file}
    echo "client_system_boot_timeout=" >> ${drbl_config_file}
    echo "language=en_US.UTF-8" >> ${drbl_config_file}
    echo "set_client_public_ip_opt=no" >> ${drbl_config_file}
    echo "config_file=drblpush.conf" >> ${drbl_config_file}
    echo "collect_mac=no" >> ${drbl_config_file}
    echo "run_drbl_ocs_live_prep=yes" >> ${drbl_config_file}
    echo "drbl_ocs_live_server=" >> ${drbl_config_file}
    echo "clonezilla_mode=clonezilla_box_mode" >> ${drbl_config_file}
    echo "live_client_branch=alternative" >> ${drbl_config_file}
    echo "live_client_cpu_mode=i386" >> ${drbl_config_file}
    echo "drbl_mode=none" >> ${drbl_config_file}
    echo "drbl_server_as_NAT_server=yes" >> ${drbl_config_file}
    echo "add_start_drbl_services_after_cfg=yes" >> ${drbl_config_file}
    echo "continue_with_one_port=" >> ${drbl_config_file}

    # prep the drbl config interfaces
    echo "" >> ${drbl_config_file}
    echo "#Setup for ${image_port_1}" >> ${drbl_config_file}
    echo "[${image_port_1}]" >> ${drbl_config_file}
    echo "interface=${image_port_1}" >> ${drbl_config_file}
    echo "mac=${mac_path_1}" >> ${drbl_config_file}
    echo "ip_start=1" >> ${drbl_config_file}
    echo ""  >> ${drbl_config_file}

    if [[ ${Lab_2} != "NONE" ]]
    then
        echo "#Setup for ${image_port_2}" >> ${drbl_config_file}
        echo "[${image_port_2}]" >> ${drbl_config_file}
        echo "interface=${image_port_2}" >> ${drbl_config_file}
        echo "mac=${mac_path_2}" >> ${drbl_config_file}
        echo "ip_start=1" >> ${drbl_config_file}
        echo ""  >> ${drbl_config_file}
    fi

    drblpush -c ${drbl_config_file}
}

function user_confirmation () {
    echo "$1 [ yes | no ]"
    read user_input
    if [[ "$user_input" == "no" ]]
    then
        echo "I'll stop here then."
        exit 0
    fi
}

function read_file_lines () {
    while read line
    do
        echo " ${line}"
    done < "$1"
}

function get_args () {
    local OPTIND
    local OPTARG

    usage="
    DRBL optimized for the CAE Center.
    This program is capable of imaging one or two labs at the same time.
    It is only capable of pushing an image to a lab, not pulling.
    If you only want to image one lab, pass NONE as the second lab.

    $(basename "$0") [-h] [-l] [-s] [-t n] LAB1 LAB2 IMAGE

    where:
        -h          Show this help text.
        -l          List images available to push.
        -s          Stop Clonezilla and turn off imaging ports.
        -t    int   Time to wait until automatically starting the push in seconds. Default 1200 seconds.
        LAB1        The name of the first lab to image. e.g. C-224
        LAB2        The name of the second lab to image. Pass NONE for only one lab. e.g. C-226
        IMAGE       The name of the image to push.
    "

    # print help if no parameters are passed
    if [[ -z $1 ]]
    then
        echo "$usage"
        exit 0
    fi

    while getopts ':hlst:' option; do
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
        t)
            time_to_wait=$OPTARG
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

}

function check_user () {
    # make sure we are root
    if [[ "$USER" != "$1" ]]
    then
        echo "This script must be run as $1."
        exit 0
    fi
}

function check_lab_name () {
    lab_mac_file="$mac_dir"/"$1".txt
    echo "Checking if $lab_mac_file exists..."
    if [[ -f "$lab_mac_file" ]]
    then
        echo "File found."
    else
        echo "Lab mac file not found: $lab_mac_file"
        exit 1
    fi
}

function main () {

    # check if labs are the same
    if [[ ${Lab_1} == ${Lab_2} ]]
    then
        echo "You must pass two different labs as parameters."
        exit 1
    fi

    # check if lab mac files exits
    check_lab_name ${Lab_1}
    if [[ ${Lab_2} != "NONE" ]]
    then
        check_lab_name ${Lab_2}
    fi

    # check if image directory exits
    if [[ -d ${image_path} ]]
    then
        echo "Image path found."
    else
        echo "Image path not found. Double check spelling of image name."
        exit 1
    fi

    # enable image ports
    if [[ ${Lab_2} == "NONE" ]]
    then
        control_ports 1
    else
        control_ports 2
    fi

    # calc number of computers
    if [[ ${Lab_2} == "NONE" ]]
    then
        machine_count=$(wc -l < ${mac_path_1})
    else
        machine_count=$(($(wc -l < ${mac_path_1}) + $(wc -l < ${mac_path_2})))
    fi

    user_confirmation "Ready to setup DRBL?"
    drbl_start ${machine_count}

    user_confirmation "Ready to start Clonezilla?"
    clonezilla_start ${machine_count}

    user_confirmation "Ready to wakeup computers in ${Lab_1}?"
    wake_computers ${mac_path_1}

    if [[ ${Lab_2} != "NONE" ]]
    then
        user_confirmation "Ready to wakeup computers in ${Lab_2}?"
        wake_computers ${mac_path_2}
    fi

}

check_user "root"
get_args $*
echo "$Lab_1 $Lab_2 $image_name"
#main
exit 0
