#!/bin/bash

ACTION="$1"
AWS_S3_URL=$(echo "$2"| sed 's:/$::')
export AWS_ACCESS_KEY_ID="$3"
export AWS_SECRET_ACCESS_KEY="$4"
export AWS_DEFAULT_REGION="$5"

function die { echo "$@"; exit 1;  }

function getVolumes {
    mount | grep "^/dev"| awk '{print $3}'| grep -vE "^(/etc/resolv.conf|/etc/hostname|/etc/hosts)"
}
function volumeToId {
    echo "$1" | sed -e 's:^/::' -e  's:/:-:g'
}
function doBackup {
    volume="$1"
    cd /
    volid=$(volumeToId "$volume")
    backupname="$volid.tar.gz"
    echo "[INFO] Archiving $volume in $backupname"
    tar --numeric-owner -cpvzf $TMPDIR/$backupname $volume 
    echo "[INFO] Uploading archive to $AWS_S3_URL/$backupname"
    aws s3 cp $TMPDIR/$backupname $AWS_S3_URL/$backupname
    echo "[INFO] Deleting local archive $backupname"
    rm $TMPDIR/$backupname
}

function downloadBackups {
    volume="$1"
    cd /
    volid=$(volumeToId "$volume")
    backupname="$volid.tar.gz"
    echo "[INFO] Downloading  $AWS_S3_URL/$backupname"
    aws s3 cp  $AWS_S3_URL/$backupname $TMPDIR/$backupname
    [ -r "$TMPDIR/$backupname" ] || die "[ERROR] Cannot download $AWS_S3_URL/$backupname for volume $volume"
}

function doRestore {
    volume="$1"
    cd /
    volid=$(volumeToId "$volume")
    backupname="$volid.tar.gz"
    echo "[INFO] Restoring volume $volume ..."
    tar -xzvf "$TMPDIR/$backupname"
}

date=$(date +"%Y%m%d-%H%M%S")
TMPDIR="/tmp/$date"
mkdir -p $TMPDIR

case $ACTION in
    backup)
        echo "[INFO] Starting backup to $AWS_S3_URL"
        getVolumes | while read vol
        do
            doBackup "$vol"
        done
        ;;
    restore)
        echo "[INFO] Starting restoration from $AWS_S3_URL"
        # Must download all archives before to overwrite existing files 
        getVolumes | while read vol
        do
            downloadBackups "$vol"
        done
        
        # and then restore backups
        getVolumes | while read vol
        do
            doRestore "$vol" 
        done
        ;;
esac

echo "[INFO] No more work ..."
