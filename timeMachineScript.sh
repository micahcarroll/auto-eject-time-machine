#!/bin/bash

backupVolumeName=""
backupVolumeUUID=""
backupVolumeIdentifier=""


# Check if a backup is in progress
if tmutil currentphase | grep -qv "BackupNotRunning"; then
    echo "Backup is in progress, will try again later."
    exit 0
fi

# Check if a backup was completed within the hour
latestBackupFileName=$(tmutil latestbackup | xargs -I {} basename -s .backup {} | cut -d '-' -f 1-4)
latestBackupTimestamp=$(date -j -f "%Y-%m-%d-%H%M%S" $latestBackupFileName "+%s") # -j is for parsing the input date
currentTimestamp=$(date "+%s")

# Calculate the absolute difference in seconds
secondsSinceLastBackup=$((currentTimestamp - latestBackupTimestamp))

if [ "$secondsSinceLastBackup" -le 3600 ]; then
    echo "A backup was completed less than 1 hour ago."
    if ! mount | grep -q "/Volumes/$backupVolumeName"; then
        echo "Backup disk '$backupVolumeName' is not mounted. Nothing to see here, move along."
        exit 0
    fi
else
    echo "No backup completed since an hour."
    if ! mount | grep -q "/Volumes/$backupVolumeName"; then
        echo "Backup disk '$backupVolumeName' is not mounted. Need to mount the encrypted disk."
        backupVolumePassword=security find-generic-password -a $backupVolumeUUID -w | xxd -p -r | rev | cut -c 1- | rev
        diskutil apfs unlockVolume $backupVolumeIdentifier -user $backupVolumeUUID -passphrase $backupVolumePassword -verify
    fi
    echo "Starting backup now."
    tmutil startbackup --auto --block # wait for the backup to finish
    echo "Backup finished."
fi

echo "Ejecting backup disk."
diskutil eject "/Volumes/$backupVolumeName"
