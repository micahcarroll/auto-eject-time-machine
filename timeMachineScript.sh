#!/bin/bash

# Enable the "exit on error" option (this is needed for handling cases where backup disk cannot be mounted).
set -e

echo "================================================================================"
echo "timeMachineScript.sh is launched."

backupVolumeUUID="****"

backupVolumeIdentifier=$(diskutil info $backupVolumeUUID | awk 'BEGIN{FS=":";}/Device Identifier:/{printf $NF}END{printf "\n"};' | xargs)
backupVolumeName=$(diskutil info $backupVolumeUUID | awk 'BEGIN{FS=":";}/Volume Name:/{print $NF}END{printf "\n"};' | xargs)
echo "    Backup Volume UUID: $backupVolumeUUID"
echo "    Backup Volume Identifier: $backupVolumeIdentifier"
echo "    Backup Volume Name: $backupVolumeName"

# Check if backup Volume is mounted, mount it if not
if ! mount | grep -q "/Volumes/$backupVolumeName"; then
    echo "Backup Volume '$backupVolumeName' is not mounted. Need to mount the backup volume."
    if diskutil info $backupVolumeIdentifier | grep 'Locked:\s*Yes'; then
        echo "    Backup Volume '$backupVolumeName' is locked. Unlocking the volume."
        backupVolumePassword=$(security find-generic-password -a $backupVolumeUUID -w | xxd -p -r | rev | cut -c 1- | rev)
        diskutil apfs unlockVolume $backupVolumeIdentifier -user $backupVolumeUUID -passphrase $backupVolumePassword
    else
        # Disk is either not encrypted or it is unlocked at the moment, mount it directly
        diskutil mount $backupVolumeIdentifier
    fi
else
    echo "Backup Volume '$backupVolumeName' is already mounted."
fi
echo "Wait 5 seconds to make sure the disk is accessible."
sleep 5 # it takes some time for the disk to be accessible after a restart or a mount

# Get current time
currentTimestamp=$(date "+%s")
echo "    Current time (timestamp): $(date "+%Y-%m-%d %H:%M:%S") ($currentTimestamp)"

# Get the latest backup time
latestBackupTime=$(tmutil latestbackup | xargs -I {} basename -s .backup {} | cut -d '-' -f 1-4)
latestBackupTime=$(date -j -f "%Y-%m-%d-%H%M%S" $latestBackupTime "+%Y-%m-%d %H:%M:%S")
latestBackupTimestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$latestBackupTime" "+%s") # -j is for parsing the input date
echo "    Latest backup time (timestamp): $latestBackupTime ($latestBackupTimestamp)"

# Calculate the difference in seconds
secondsSinceLastBackup=$((currentTimestamp - latestBackupTimestamp))
echo "    Seconds since last backup: $secondsSinceLastBackup"

# Backup takes around 5 minutes to complete, so check if the last backup was completed within the last 50 minutes
if [ "$secondsSinceLastBackup" -le 3000 ]; then
    echo "A backup was completed less than 1 hour ago."
else
    echo "No backup has been completed since $secondsSinceLastBackup seconds."
    if [ "$(tmutil currentphase)" = "BackupNotRunning" ]; then
        echo "  No backup is in progress. Starting backup now."
        tmutil startbackup --auto # auto runs the backup in a mode similar to system-scheduled backups.
        while [ "$(tmutil currentphase)" = "BackupNotRunning" ]; do
            echo "    Waiting for backup to start." # it takes a few seconds for currentphase to change
            sleep 1
        done
    fi
fi

# Wait for backup to complete if there is any backup in progress
while [ "$(tmutil currentphase)" != "BackupNotRunning" ]; do
    percentCompleted=$(tmutil status | grep _raw_Percent | xargs | sed -e 's/[^0-9.]*//g')
    timeRemaining=$(tmutil status | grep TimeRemaining | xargs | sed -e 's/[^0-9.]*//g')

    percentCompleted=${percentCompleted:-0}
    timeRemaining=${timeRemaining:-10}

    # timeRemaining is not very accurate at the end of the backup
    # multiply it with a factor to make it more accurate
    sleepDuration=$(awk "BEGIN {print (1-($percentCompleted*$percentCompleted))*$timeRemaining}")
    # Don't let the sleep duration be greater than 30 seconds (time machine time estimation is very unreliable)
    sleepDuration=$(awk -v n1="$sleepDuration" -v limit="30" 'BEGIN {print (n1<limit)?n1:limit}')

    echo "    A backup is in progress ($percentCompleted completed), will check again in $sleepDuration seconds."
    sleep $sleepDuration
done

# diskutil eject "$backupVolumeIdentifier" # somehow this command fails sometimes while hdiutil is more reliable
hdiutil detach "/dev/$backupVolumeIdentifier" -force
echo "    Backup disk '$backupVolumeName' is ejected."
echo "================================================================================"
