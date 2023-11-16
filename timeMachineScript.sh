#!/bin/bash

# Enable the "exit on error" option (this is needed for handling cases where backup disk cannot be mounted).
set -e

echo "================================================================================"
echo "timeMachineScript.sh is launched."

backupVolumeUUID="****"

backupVolumeIdentifier=$(diskutil info $backupVolumeUUID | awk 'BEGIN{FS=":";}/Device Identifier:/{printf $NF}END{printf "\n"};' | xargs)
backupVolumeName=$(diskutil info $backupVolumeUUID | awk 'BEGIN{FS=":";}/Volume Name:/{print $NF}END{printf "\n"};' | xargs)

# Check if backup disk is mounted, mount it if not
if ! mount | grep -q "/Volumes/$backupVolumeName"; then
    echo "Backup disk '$backupVolumeName' is not mounted. Need to mount the encrypted disk."
    backupVolumePassword=$(security find-generic-password -a $backupVolumeUUID -w | xxd -p -r | rev | cut -c 1- | rev)
    diskutil apfs unlockVolume $backupVolumeIdentifier -user $backupVolumeUUID -passphrase $backupVolumePassword # unlockVolume automatically mounts the disk
    # This command will fail if the backup disk is not available and script will exit with set -e
fi

# Get the latest backup timestamp and calculate the difference in seconds
latestBackupFileDate=$(tmutil latestbackup | xargs -I {} basename -s .backup {} | cut -d '-' -f 1-4)
echo "Latest backup file date: $latestBackupFileDate"
latestBackupTimestamp=$(date -j -f "%Y-%m-%d-%H%M%S" $latestBackupFileDate "+%s") # -j is for parsing the input date
echo "Latest backup timestamp: $latestBackupTimestamp"
currentTimestamp=$(date "+%s")
echo "Current time: $(date "+%Y-%m-%d %H:%M:%S")"
echo "Current timestamp: $currentTimestamp"
secondsSinceLastBackup=$((currentTimestamp - latestBackupTimestamp))
echo "Difference in seconds: $secondsSinceLastBackup"

# Backup takes around 5 minutes to complete, so check if the last backup was completed within the last 50 minutes
if [ "$secondsSinceLastBackup" -le 3000 ]; then
    echo "A backup was completed less than 1 hour ago, will eject the disk."
else
    echo "No backup has been completed since an hour."
    if [ "$(tmutil currentphase)" = "BackupNotRunning" ]; then
        echo "No backup is in progress. Starting backup now."
        tmutil startbackup --auto # wait for the backup to finish
    fi
fi

while [ "$(tmutil currentphase)" != "BackupNotRunning" ]; do
    percentCompleted=$(tmutil status | grep _raw_Percent | xargs | sed -e 's/[^0-9.]*//g')
    timeRemaining=$(tmutil status | grep TimeRemaining | xargs | sed -e 's/[^0-9.]*//g')

    percentCompleted=${percentCompleted:-0}
    timeRemaining=${timeRemaining:-10}

    # timeRemaining is not very accurate at the end of the backup
    # multiply it with a factor to make it more accurate
    sleepDuration=$(awk "BEGIN {print (1-($percentCompleted*$percentCompleted))*$timeRemaining}")

    echo "Backup is in progress ($percentCompleted), will check again in $sleepDuration seconds."
    sleep $sleepDuration
done

diskutil eject "$backupVolumeIdentifier"
echo "Backup disk '$backupVolumeName' is ejected."
echo "================================================================================"
