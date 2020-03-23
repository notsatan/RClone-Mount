#!/bin/bash

# This script will be used to unmount all the directories that were mounted by the shell
# script. Once the directories are unmounted, this script will also delete the directories
# if required.

# The delete flag, if supplied to the script, will also delete the directories which were
# mounted. Alternatively, "-D" can also be used as an argument for the same result.
DELETE_FLAG="--delete"
# NOTE: This flag will not delete anything outside of the directory that is mounted. Meaning
# that any other content inside the root directory won't be affected. However, anything present
# inside the mounted directory will be removed.

# Setting a blank string as the initial value. Its value should be either `true` or `false`. Can
# be hard-coded if required.
DELETE=""

# The flag for silent mode, if supplied to the script will suppress all the output (including errors),
# making the script silent. Alternatively, "-S" can also be used to get the same result.
SILENT_FLAG="--silent"

# Setting a blank string as the initial value of the variable. Can be hard-coded if required.
# Value should be either `true` or `false`.
SILENT=""

# The name of the text file in which the path of mounted directories is stored.
# NOTE: If the value of this string is changed, the corresponding value in `multi-mount.sh` should
# also be changed.
MOUNT_FILE="mount.txt"

# Iterating through all arguments supplied while running the script.
for argument in "${@}"; do
    if [[ $argument == "${DELETE_FLAG}" || $argument == "-D" ]]; then
        # If either version of the delete argument is supplied, setting the delete flag as true.
        DELETE=true
    elif [[ $argument == "${SILENT_FLAG}" || $argument == "-S" ]]; then
        # If either verion of the silent flag is supplied, setting the value of the variable as true.
        SILENT=true
    fi
done

if [[ -z "${DELETE}" ]]; then
    # If the delete flag still has its default value, using false as the default value.
    DELETE=false
fi

if [[ -z "${SILENT}" ]]; then
    echo="Not silent"
    # If the silent flag still has its default value, using false as the default value.
    SILENT=false
fi

# Reading the contents of the mount file.
while IFS= read -r line; do
    if [[ "${line}" == "/"* ]]; then
        # If the line starts with forward-slash [/], assuming that the line is the path to a directory
        # that is to be un-mounted.

        # Checking if the path is valid or not. If the path is invalid, simply ignoring it.
        if [[ ! -d $line ]]; then
            continue
        fi

        # Unmounting the directory with `fusermount`.
        if [[ $SILENT == true ]]; then
            fusermount -u "${line}" 2>/dev/null
        else
            fusermount -u "${line}"
        fi

        if [[ $DELETE == true ]]; then
            # Deleting the directory if the delete flag is supplied.
            if [[ $SILENT == true ]]; then
                rm -r "${line}" 2>/dev/null
            else
                rm -r "${line}"
            fi

            # If the script is not in silent mode, checking to see if the directory still exists or not.
            # No need to perform this check in silent mode, even if the directory is not removed,
            # the script will not print any output...
            if [[ $SILENT == false ]]; then
                # Making the script sleep to give enough time for the directory to be deleted in the background.
                sleep 2

                if [[ -d "${line}" ]]; then
                    # If the path is not invalid, then the directory could not be removed.
                    echo "Failed to remove directory '${line}'"
                fi
            fi
        fi
    fi

done <"${MOUNT_FILE}"

# Finally, wiping the contents of the mount file.
echo "" >"${MOUNT_FILE}"

# Printing a simple message to indicate that the execution of the script is now complete.
if [[ $SILENT == false ]]; then
    echo "Done"
fi
