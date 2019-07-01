#!/bin/bash
if [ -z $1 ]
then
	echo "Usage: $0 /path/to/macs.txt"
	exit 0
fi

while IFS='' read -r line || [[ -n "$line" ]]; do
    echo "Wakingup: $line"
    etherwake -i bond0.142 $line
    sleep 3
done < "$1"
