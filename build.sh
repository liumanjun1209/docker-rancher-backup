#!/bin/bash

if [ "$1" = "" ]
then
	echo "Usage : $0 tag"
	exit 1
fi

[ ! -e "Dockerfile" ] && echo "Missing Dockerfile" && exit 2

docker build -t mdns/rancher-backup:$1 .
docker push mdns/rancher-backup