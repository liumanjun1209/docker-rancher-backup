#!/bin/bash

CONTINUE=1
function error { echo "Error : $@"; CONTINUE=0; }
function die { echo "$@" ; exit 1; }
function checkpoint { [ "$CONTINUE" = "0" ] && echo "Unrecoverable errors found, exiting ..." && exit 1; }



# Checking mandatory variables
for i in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_S3_URL
do
    [ "${!i}" = "" ] && error "empty value for variable '$i'"
done

checkpoint

# Saving environment variables
[ -e "/etc/backup.env" ] && rm "/etc/backup.env"
env | grep "AWS_" | while read i
do
    var=$(echo "$i" | awk -F= '{print $1}')
    var_data=$( echo "${!var}" | sed "s/'/\\'/g" )
    echo "export $var='$var_data'" >> /etc/backup.env
done

echo "Just starting bash ro keep dock running"
bash