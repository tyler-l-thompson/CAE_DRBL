#!/usr/bin/env bash
image_dir=/images
Lab_1=$1
Lab_2=$2
image_name=$3

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
    If you only want to image one lab, pass NONE as the second lab.

    $(basename "$0") [-h] [-l] LAB1 LAB2 IMAGE

    where:
        -h      Show this help text.
        -l      List images available to push.
        LAB1    The name of the first lab to image. e.g. C-224
        LAB2    The name of the second lab to image. Pass NONE for only one lab. e.g. C-226
        IMAGE   The name of the image to push.
    "

    while getopts ':hl' option; do
      case "$option" in
        h) echo "$usage"
           exit
           ;;
        l) ls "$image_dir"
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

function main () {
    echo "$image_name"
}

check_user "root"
get_args $*
main
exit 0
