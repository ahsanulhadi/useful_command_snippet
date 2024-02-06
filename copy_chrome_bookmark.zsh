#!/bin/zsh

# USAGE: A zsh script to copy Google Chrome Bookmark file to a backup location. For Mac OS.
# COMPATIBILITY: Tested on MacOS: 14.2, 14.1  

chrome_bookmark_file="${HOME}/Library/Application Support/Google/Chrome/Default/Bookmarks" 
backup_path="${HOME}/Library/CloudStorage/OneDrive/chrome_bookmark_backup"
current_date=$(date +%y%m%d_%H%M%S)
target_path="${backup_path}/${current_date}"


# Copy the bookmarks file to backup location 

mkdir -p ${target_path}
cp ${chrome_bookmark_file} ${target_path}

# Delete directory/files older than 7 days
find ${backup_path}/* -type d -ctime +7 | xargs rm -rf

exit 0

