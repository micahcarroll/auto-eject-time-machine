#!/bin/bash

backupVolumeName="BACKUP DISK NAME"

# # Check if the disk is mounted
# if ! mount | grep -q "/Volumes/$backupVolumeName"; then
#     echo "Backup disk '$backupVolumeName' is not mounted"
#     exit 0
# fi
# echo "Backup disk '$backupVolumeName' is mounted"

# Check if a backup is in progress
if tmutil currentphase | grep -qv "BackupNotRunning"; then
    echo "Backup is in progress"
    exit 0
fi
echo "Backup is not in progress"

# Check if a backup was completed within the hour
latestBackupFileName=$(tmutil latestbackup | xargs -I {} basename -s .backup {} | cut -d '-' -f 1-4)
latestBackupTimestamp=$(date -j -f "%Y-%m-%d-%H%M%S" $latestBackupFileName "+%s") # -j is for parsing the input date
currentTimestamp=$(date "+%s")

# Calculate the absolute difference in seconds
secondsSinceLastBackup=$((currentTimestamp - latestBackupTimestamp))

if [ "$secondsSinceLastBackup" -le 3600 ]; then
    echo "A backup was completed less than 1 hour ago."
    diskutil eject "/Volumes/$backupVolumeName"
else
    echo "No backup completed since an hour. Starting now."
    echo "Need to mount the encrypted disk"
    tmutil startbackup
fi
