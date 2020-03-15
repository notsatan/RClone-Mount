#!/bin/bash

# This script will get a list of all RClone configs in the machine, and mount them inside the
# root directory. All the configs regardless of their type will be mounted by this script.

# Location of the root directory. A separate directory will be created to use as a mount point
# for each RClone config inside the root directory. If you want to hard-code the location of
# the root directory, add its location as the value of the variable below.
root_dir=""

# The flag that should be used while passing the root directory argument to use
# the directory as the root directory.
DIR_FLAG="--root="

# Ensuring that the script has root privilege
if [[ $(id -u) -ne 0 ]]; then
    printf "\nThis script requires root privileges to run\n\n"
    exit -4
fi

# Ensuring that the directory being used as root actually exists.
while true; do
    # Checking if an argument has been supplied while running the command, and if an input
    # has been supplied, checking if the flag is the same as the root. If the flag is not
    # the same, then the path supplied will not be treated as the root directory.
    if [[ ! -z $1 && $1 == *$DIR_FLAG* ]]; then
        # If input is supplied, getting the value by replacing the flag with an empty string
        # and taking the rest of the value as the value supplied for the root directory.
        root_dir=$(echo ${1} | sed "s/${DIR_FLAG}//g")

        # Once the argument is read, changing it to be an empty string. This ensures if the
        # path supplied as argument is invalid, the script does not enter into an infinite
        # loop where it will read the argument every time and print that the path is invalid.
        set -- "" # This statement is equivalent to $1="" and works :p
        echo "Arguemnt: " $1
        exit
    fi

    if [[ -z $root_dir ]]; then
        # If root directory is not set (the value has neither been hard-coded nor been supplied
        # as an argument), getting the value from the user.
        read -p "Path for root directory: " root_dir
    fi

    # Validating if the path supplied as the root directory is valid or not.
    if [[ ! -d $root_dir ]]; then
        # Flow of control reaches here only if the path is invalid.
        printf "\nPath supplied as the root directory '${root_dir}' is invalid \n\n"
    else
        # Converting relative path to absolute path, if the path supplied is the absolute path,
        # it remains unchanged.
        root_dir=$(realpath "${root_dir}")

        # Again, validating that the absolute path exists.
        if [[ -d $root_dir ]]; then
            # If the path is still valid, breaking out of the infinite loop.
            break
        fi
    fi
done
