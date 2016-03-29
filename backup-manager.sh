#!/bin/bash

source /etc/backup.env

function get { wget -qO - "http://169.254.169.250/latest/$1"; }
function getList { get "$1" |awk -F= '{print $2}'; }

MYSTACK=$(get self/container/stack_name)
MYUUID=$(get self/container/uuid)

function searchHostDockerProxy {
    host_uuid="$1"
    containers="stacks/$MYSTACK/services/docker-proxy/containers/"
    getList "$containers" | while read ct
    do
        if [ "$(get "$containers/$ct/host_uuid")" = "$host_uuid" ] 
        then
            get "$containers/$ct/primary_ip"
        fi
    done
}

function searchContainerId {
    proxy="$1"
    ctuuid="$2"
    ctname="$3"
    docker -H $proxy:2375 ps -a |grep -E "($ctuuid|r-$ctname)$"| awk '{print $1}'
}

function actionContainer {
    container="$1"
    action="$2"
    s3path="$3"
    
    name="$container"
    uri="containers/$container"
    
    ctuuid=$(get "$uri/uuid")
    host_uuid=$(get "$uri/host_uuid")
    
    [ "$ctuuid" = "$MYUUID" ] && return 0
    
    proxy=$(searchHostDockerProxy $host_uuid)
    
    if [ "$proxy" = "" ]
    then
        echo "Error: cannot find docker proxy for $name (host $host_uuid)" >&2
        return 1
    fi
    
    ctid=$(searchContainerId "$proxy" "$ctuuid" "$container")
    
    if [ "$ctid" = "" ]
    then
        echo "Error: cannot find docker run id $name (proxy $proxy)" >&2
        return 1
    fi
    
    # Appending s3 path
    s3url="$(echo "$AWS_S3_URL"| sed 's:/$::')/$(echo "$s3path"| sed 's:/$::')"
    
    # Executing task
    echo "[INFO] Container $container (id $ctid)"
    docker -H $proxy:2375 run -it --rm --volumes-from $ctid \
        mdns/rancher-backup /bin/backup-task.sh "$action" "$s3url" "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" "$AWS_DEFAULT_REGION"
}

function backupService {
    stack="$1"
    service="$2"
    
    [ "$stack" = "$MYSTACK" ] && return 0
    
    getList "stacks/$stack/services/$service/containers"| while read container
    do
        backupContainer "$stack" "$service" "$container"
    done
}

function backupStack {
    stack="$1"
    
    [ "$stack" = "$MYSTACK" ] && return 0
    
    getList "stacks/$stack/services"| while read service
    do
        backupService "$stack" "$service"
    done
}


function usage {
    echo "Usage: "
    echo "  Container: "
    echo "      $0 list-containers"
    echo "      $0 backup-container <container> <s3path>"
    echo "      $0 restore-container <container> <s3path>"
    
    # echo "  $0 list-services <stack>"
    # echo "  $0 backup-service <stack> <service>"
    # echo "  $0 list-stacks"
    # echo "  $0 backup-stack <stack>"
    exit 0
}

case $1 in 
    list-containers)
        getList containers | while read container
        do
            echo $container
        done
        ;;
    backup-container)
        [ "$3" = "" ] && usage
        actionContainer "$2" backup "$3"
        ;;
    restore-container)
        [ "$3" = "" ] && usage
        actionContainer "$2" restore "$3"
        ;;
    # list-services)
    #     [ "$2" = "" ] && usage
    #     getList stacks/$2/services | while read service
    #     do
    #         echo $service
    #     done
    #     ;;
    # backup-service)
    #     [ "$3" = "" ] && usage
    #     backupService "$2" "$3"
    #     ;;
    # list-stacks)
    #     getList stacks | while read stack
    #     do
    #         echo $stack
    #     done
    #     ;;
    # backup-stack)
    #     [ "$2" = "" ] && usage
    #     backupStack "$2"
    #     ;;
    # backup-full)
    #     getList stacks | while read stack
    #     do
    #         backupStack $stack
    #     done
    #     ;;
    *)
        usage
        ;;
esac
