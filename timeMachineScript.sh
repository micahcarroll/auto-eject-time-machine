#!/bin/bash

backupVolumeName="BACKUP DISK NAME"

# Check if the disk is mounted
if ! mount | grep -q "/Volumes/$backupVolumeName"; then
    echo "Backup disk '$backupVolumeName' is not mounted"
    exit 0
fi

# Check if a backup is in progress
if tmutil currentphase | grep -qv "BackupNotRunning"; then
    echo "Backup is in progress"
    exit 0
fi

# Check if a backup was completed today
latestBackupDate=$(tmutil latestbackup | xargs -I {} basename {} | cut -d '-' -f 1-3)
currentDate=$(date "+%Y-%m-%d")

if [ "$latestBackupDate" == "$currentDate" ]; then
    echo "A backup was completed today"
    diskutil eject "/Volumes/$backupVolumeName"
else
    echo "No backup completed today. Starting now."
    tmutil startbackup
fi