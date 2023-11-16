# auto-eject-time-machine
A simple set of steps to create a simple script that is run every hour to automatically eject your TimeMachine disk after backup. Specifically, the script as written will eject the disk if a backup was completed today.

*Why?* I hate having to remember doing it manually, and have corrupted a hard-drive by removing it physically without ejecting it first.

## Setup Instructions

`timeMachineScript.sh`:
1. Change line 9: use name the UUID of your backup harddisk (Assuming the back up disk is mounted and named as "Backups of ..." -- `diskutil list | grep "Backups of" | awk '{print $NF}' | xargs  diskutil info | grep "Volume UUID:"` command can be used to display the UUID of the backup disk)
2. Run `chmod +x timeMachineScript.sh`
3. Move the file to a location of your choice (e.g. `~/bin/timeMachineScript.sh`)
4. (tmutil: latestbackup requires Full Disk Access privileges) Give `timeMachineScript.sh` Full Disk Access rights by openning the System Settings > Privacy & Security > Full Disk Access window and dragging & dropping the `timeMachineScript.sh` file into it.
5. This modification assumes that the disk is encyrpted and its password is registered in the master keychain. `security` binary will ask permission to access this login item (which can be find by searching the UUID in Keychain Access.app). Basically the script will query the password of the backup disk everytime it runs so that it can mount the disk.

`com.username.timeMachineScript.plist`:
1. Change the name of this file: use your Mac username (e.g. `com.micah.timeMachineScript.plist`)
2. Change line 6: use your Mac username (e.g. `com.micah.timeMachineScript`)
3. Change line 9: use the path to the bash script chosen for `timeMachineScript.sh`
4. Modify lines 16 and 18 to your liking or remove lines 15 through 18 altogether if you don't want logging
5. Move the file to `/Users/username/Library/LaunchAgents` (where `username` is replaced with your Mac username)
6. Run `launchctl load ~/Library/LaunchAgents/com.username.timeMachineScript.plist` (where `username` is replaced with your Mac username)

Use it at your own risk.
