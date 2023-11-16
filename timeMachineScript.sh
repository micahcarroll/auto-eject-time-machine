#!/bin/bash

# Enable the "exit on error" option (this is needed for handling cases where backup disk cannot be mounted).
set -e

backupVolumeUUID="###################."

backupVolumeIdentifier=$(diskutil info $backupVolumeUUID | awk 'BEGIN{FS=":";}/Device Identifier:/{printf $NF}END{printf "\n"};' | xargs)
backupVolumeName=$(diskutil info $backupVolumeUUID | awk 'BEGIN{FS=":";}/Volume Name:/{print $NF}END{printf "\n"};' | xargs)

# Get the latest backup timestamp and calculate the difference in seconds
latestBackupFileName=$(tmutil latestbackup | xargs -I {} basename -s .backup {} | cut -d '-' -f 1-4)
latestBackupTimestamp=$(date -j -f "%Y-%m-%d-%H%M%S" $latestBackupFileName "+%s") # -j is for parsing the input date
currentTimestamp=$(date "+%s")
secondsSinceLastBackup=$((currentTimestamp - latestBackupTimestamp))

# Backup takes around 5 minutes to complete, so check if the last backup was completed within the last 50 minutes
if [ "$secondsSinceLastBackup" -le 3000 ]; then
    echo "A backup was completed less than 1 hour ago."
    if ! mount | grep -q "/Volumes/$backupVolumeName"; then
        echo "Backup disk '$backupVolumeName' is not mounted. Nothing to see here, move along."
        exit 0
    fi
else
    echo "No backup completed since an hour."
    if [ "$(tmutil currentphase)" = "BackupNotRunning" ]; then
        echo "No backup is in progress. Starting backup now."
        # Check if backup disk is mounted
        if ! mount | grep -q "/Volumes/$backupVolumeName"; then
            echo "Backup disk '$backupVolumeName' is not mounted. Need to mount the encrypted disk."
            backupVolumePassword=security find-generic-password -a $backupVolumeUUID -w | xxd -p -r | rev | cut -c 1- | rev
            diskutil apfs unlockVolume $backupVolumeIdentifier -user $backupVolumeUUID -passphrase $backupVolumePassword # unlockVolume automatically mounts the disk
            # This command will fail if the backup disk is not available and script will exit with set -e
        fi
        tmutil startbackup --auto --block # wait for the backup to finish
    else
        echo "Backup is in progress, need to wait before ejecting the disk."
        while [ "$(tmutil currentphase)" != "BackupNotRunning" ]; do
            percentCompleted=$(tmutil status | grep _raw_Percent | xargs | sed -e 's/[^0-9.]*//g')
            timeRemaining=$(tmutil status | grep TimeRemaining | xargs | sed -e 's/[^0-9.]*//g')

            percentCompleted=${percentCompleted:-0}
            timeRemaining=${timeRemaining:-10}

            sleepDuration=$(awk "BEGIN {print (1-$percentCompleted)*$timeRemaining}")
            echo "Backup is still in progress, will check again in $sleepDuration seconds."
            sleep $sleepDuration
        done
    fi
    echo "Backup is finished."
fi

echo "Ejecting the backup disk."
diskutil eject "$backupVolumeIdentifier"
