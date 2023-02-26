#!/bin/bash
# A script remove the "home" share from 
# samba's smb.share.conf.
#
# By default, synology allows you to remove
# the "homes" share, but not your own home.
# Annoying. I use "guest" at home, with no
# desire to give this user a homedir. So,
# our NAS has an unusable folder exported.
#
# This removes that problem. Thanks Linux!
#
# v.02 - Jim Bair
#
# NOTE: Maybe add this?
# synoservice --disable pkgctl-SynoFinder

# Our config and init scripts
ourConf='/etc/samba/smb.share.conf'
if [ ! -s "${ourConf}" ]; then
  echo "ERROR: Our share config $ourConf is missing - exiting."
  exit 1
fi

# We need to be root to do much of anything
if [ $UID -ne 0 ]; then
  echo "ERROR: This script must be run as root - exiting."
  exit 1
fi

# Store our new config into temp then move it into place later.
ourTemp=$(mktemp)
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to create temp file. Exiting."
    rm -f $lockfile
    exit 1
fi

# Main

echo -n "Creating new config..."

# Let's preserve indentation in the config file
OLDIFS="$IFS"
IFS=''

# Walk line by line, either passing lines or editing lines.
# We are looking for the line [homes] to start, then
# either adding a # or exiting out.
HOMESBLOCK=no
while read -r line
do
    # Looking for the homes block.
    if [ "$HOMESBLOCK" == 'no' ]; then
        # Found the block!
        if [ -n "$(echo $line | egrep '\[homes\]')" ]; then
            # Verify if it's already commented out
            if [ -z "$(echo $line | egrep '^\[homes\]$')" ]; then
                echo "INFO: Already commented out. Exiting."
                exit 0
            fi
            # Let's start the process of removing the share.
            # We remove the header line first, then the loop
            # will kick us to the "else" section for the rest.
            HOMESBLOCK=yes
            echo "#${line}" >> $ourTemp
        else
            # Not the home block so just pass it through
            echo "$line" >> $ourTemp
            continue
        fi
    else
        # Let's check for the next share section and if we hit it, reset and keep passing through
        if [ -n "$(echo ${line} | egrep '^\[')" ] && [ -z "$(echo ${line} | grep homes)" ]; then
            HOMESBLOCK=no
            echo ${line} >> ${ourTemp}
            continue
        fi

        # If here, you are in the homes block AND commenting it out! 
        # Comment out lines (easy enough)
        echo "#${line}" >> $ourTemp

    fi


done < "${ourConf}"

# Restore the old IFS even though it probably doesn't matter
IFS="$OLDIFS"

echo 'done!'

# overwrite our config and remove our temp files
cat $ourTemp > $ourConf
rm -f $ourTemp $lockfile

# Restart samba
synopkg restart SMBService

# All done
if [ $? -eq 0 ]; then
    echo "SUCCESS: $ourConf has been fixed!"
    exit 0
# TODO: I need to add config restore logic here.
# Create a backup that's deleted above if we hit success, 
# and rollback if it explodes and restart again (and verify)
else
    echo "ERROR: Samba not able to restart. Please troubleshoot."
	exit 1
fi
