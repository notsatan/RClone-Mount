#!/bin/bash

# This script will fetch a list of all the drives/teamdrives that are connected to a
# Google Account and will add them as Configs to RClone and is intended to be
# run once.

# The name of the output file that will contain the output data once the python
# script finishes fetching all the Drives and their IDs.
FILENAME="output.txt"

# Getting the path for the RClone config file, extracting just the path from the output.
res=$(rclone config file | grep -o '/.*')

# If the script could not get the location of RClone config file, asking the user to enter the same.
while true; do
    if [[ -z "${res}" && ! -e $res ]]; then
        printf "\nThe path '${res}' points to an invalid location.\n\n  "
    else
        # Breaking out of the infinite loop if a file exists at the defined path.
        break
    fi

    read -p "Enter full path for RClone Config File: " res
done

# Getting the Client ID and Client Secret. Will be asked only once, the same ID
# and secret will be reused for all drives.
printf 'Enter details for Google Project\n\n'

# Getting the values for client id, secret and token. Getting each of these values in
# infinite loops. The loops will be broken only if a non-null value is supplied.

while true; do
    read -p "Client ID: " client_id
    if [ ! -z "${client_id}" ]; then
        break
    else
        printf '\nClient ID cannot be a blank string\n'
    fi
done

while true; do
    read -p "Client Secret: " client_secret
    if [ ! -z "${client_secret}" ]; then
        break
    else
        printf '\nClient Secret cannot be a blank string\n'
    fi
done

while true; do
    read -p 'Enter token to be used to generate configs: ' token
    if [ ! -z "${token}" ]; then
        break
    else
        printf '\nThe token cannot be a blank string\n'
    fi
done

echo -n 'Getting a list of all the drives. This process can take some time'
# Running the python script to get all the drives that are connected to the main account.
# The output of the previous script will be a string containing the number of drive's
# found attached to the account, extracting this number using `sed` module.
drives=$(python list_generator.py | grep -o '[0-9]*')

# NOTE: Leave all this blank space on the right untouched. Else the prevoius message will
# be partially overwritten by the new string with some of the old message still visible.
echo -e '\rFound' ${drives} 'team drives                                                 '
echo

# String containing the basic settings that will be applied to any drive that is being
# added to configs. All team drives will have common configs applied and this string
# will be used to define the base configs.
CONFIG="
type = drive
client_id = ${client_id}
client_secret = ${client_secret}
list_chunk = 1000
upload_cutoff = 32M
chunk_size = 32M
token = {${token}}
"

while true; do
    # Checking if the argument supplied to script is '-y', if not then asking the user
    # to enter an input.
    if [[ "${1,,}" != "-y" ]]; then
        echo "Are you sure you want to add the configurations for RClone?"
        read -p "This process cannot be reversed (y/n): " input
    else
        input=$1
    fi

    if [[ "${input,,}" = "y" || "${input,,}" = "-y" ]]; then
        break
    elif [ "${input,,}" = "n" ]; then
        printf "Force stopping the script\n\n"
        exit -4
    else
        printf "\nUnexpected input\n\n"
    fi
done

# Reading data from the Python file two lines at a time.
cut -f2 $FILENAME | while read driveName; do
    read driveId

    # Generating a config for the current drive.
    tempConf="[${driveName}]"
    tempConf="${tempConf} ${CONFIG}" # Adding the rest of the configs for each drive.

    # Finally, adding the drive ID to create a config specific to the teamdrive.
    tempConf="${tempConf}team_drive = ${driveId}"

    # Appending the data for the config at the end of the file. Appending with sudo privilege
    # as a precaution (and there is a possibility that configs might be stored in root).
    sudo printf "${tempConf}\n\n" >>$res
done

printf "\n\nAdded configs to the token file\n\n"
