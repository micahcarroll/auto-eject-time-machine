# auto-eject-time-machine
A simple set of steps to create a simple script that is run every hour to automatically eject your TimeMachine disk after backup. 

*Why?* I hate having to remember doing it manually, and have corrupted a hard-drive by removing it physically without ejecting it first.

## Setup Instructions

`timeMachineScript.sh`:
1. Change line 3: use name of your backup harddisk (as it appears when its mounted)
2. Move the file to a location of your choice (e.g. `Documents` or `Developer`)

`com.username.timeMachineScript.plist`:
1. Change the name of this file: use your Mac username (e.g. `com.micah.timeMachineScript.plist`)
2. Change line 6: use your Mac username (e.g. `com.micah.timeMachineScript`)
3. Change line 9: use the path to the bash script chosen for `timeMachineScript.sh`
4. Move the file to `/Users/username/Library/LaunchAgents` (where `username` is replaced with your Mac username)
5. Run `launchctl load ~/Library/LaunchAgents/com.username.timeMachineScript.plist` (where `username` is replaced with your Mac username)