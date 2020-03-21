#!/bin/bash

# This script will get a list of all RClone configs in the machine, and mount them inside the
# root directory. All the configs regardless of their type will be mounted by this script.

# Location of the root directory. A separate directory will be created to use as a mount point
# for each RClone config inside the root directory. A valid path can be hard-coded as the value
# of the variable if required.
root_dir=""

# The flag that should be used while passing the root directory argument to use
# the directory as the root directory.
DIR_FLAG="--root="

# Force flag, will be used to indicate that the value is forced.
FORCE_ARGUMENT="--force"

# Will be used to determine if the process of mounting drives to directories should be forced.
# Should contain a boolean value, can be hard-coded with a default value if required. Initially
# setting the value of this variable to be an empty string.
FORCE=""

# The name of the text file that will contain the ID of the background processes running RClone,
# and the directories that have been mounted.
MOUNT_FILE="mount.txt"

# The signing signature, will be present at the top of the mount-file.
FILE_SIGNATURE=("RClone-Mount v0.3" "Do not make any modifications to this file")

# String that will contain the flags that are to be use while mounting directories with RClone.
MOUNT_FLAGS="--cache-db-purge --buffer-size 256M --drive-chunk-size 32M --vfs-cache-mode minimal 
			--vfs-read-chunk-size 128M --vfs-read-chunk-size-limit 1G"
#
# Brief usage for these flags:
# 	--cache-db-purge	 		: Will purge the previous cache.
# 	--buffer-size		 		: The amount of memory used to buffer data in advance.
#	--drive-chunk-size			: The minimum size of a chunk while uploading files.
# 	--vfs-cache-mode			: Balances upload/download with regards to resource consumption.
#	--vfs-read-chunk-size		: The size of chunks while reading.
#

# Iterating over all arguments supplied, and using them if the argument is valid.
for argument in "${@}"; do
	if [[ $argument == $DIR_FLAG* && -z "${root_dir}" ]]; then
		# If the root directory is not set already and the argument starts with the flag for root
		# directory, replacing the flag from the string and taking the rest as the root directory.
		root_dir=$(echo "${argument}" | sed "s/${DIR_FLAG}//g")
	elif [[ -z $FORCE && ("${argument,,}" == "${FORCE_ARGUMENT,,}" || "${argument}" == "-F") ]]; then
		# If value of `force` is a blank string (same as default), and if the force argument is
		# supplied, setting the value of the variable to be true.
		FORCE=true

		# If the `force` argument is supplied, adding flag to allow mounting of a non-empty directory.
		MOUNT_FLAGS=$MOUNT_FLAGS" --allow-non-empty"
	fi
done

if [[ -z "${FORCE}" ]]; then
	# If the value of force is still an empty string, setting it to be false.
	FORCE=false
fi

# Ensuring that the directory being used as root actually exists.
while true; do
	if [[ -z "${root_dir}" ]]; then
		# If root directory is not set (the value has neither been hard-coded nor been supplied
		# as an argument), getting the value from the user.
		read -p "Path for root directory: " root_dir
	fi

	# Validating if the path supplied as the root directory is valid or not.
	if [[ ! -d "${root_dir}" ]]; then
		# Flow of control reaches here only if the path is not valid.
		printf "\nPath supplied as the root directory '${root_dir}' is invalid \n\n"

		# Empty the value of `root_dir` to ask the user is to re-enter this value in the next iteration.
		root_dir=""
	else
		# Converting relative path to absolute path, if the path supplied is the absolute path,
		# it remains unchanged.
		root_dir=$(realpath "${root_dir}")

		# Again, validating that the absolute path exists.
		if [[ -d "${root_dir}" ]]; then
			# If the path is still valid, breaking out of the infinite loop.
			break
		fi
	fi
done

# Getting the path of the RClone config file.
config=$(rclone config file | grep -o '/.*')

# Validating the path of the config file.
while true; do
	if [[ -z "${config}" || ! -f "${config}" ]]; then
		# If the config variable is empty, or if the path present inside the variable is
		# invalid, asking the user to enter path for the same.

		printf "\nCould not locate the RClone config file\n"
		read -p "Enter full path for the RClone config file: " config
	fi

	# If the path is a valid to a file, converting the relative path to absolute.
	if [[ -f "${config}" ]]; then
		config=$(realpath "${config}")

		# If the converted path points to a file, breaking out of the infinite loop.
		if [[ -f "${config}" ]]; then
			break
		else
			echo "Problems while converting into absolute path. Enter the absolute path."
			echo # Blank line to avoid cluttering the screen.
		fi
	fi
done

# Creating the mount file. This file will be used to contain the paths of the directories
# to which these RClone configs are mounted.
# Starting by adding a blank character to the file, this will create the file or wipe all
# the file if it already exists.
printf "" >"${MOUNT_FILE}"
for string in "${FILE_SIGNATURE[@]}"; do
	# Adding the file signature to the top of the file.
	echo "${string}" >>"${MOUNT_FILE}"
done

# Reading the contents of the config file line-by-line.
cut -f2 "${config}" | while read line; do

	# Reading the line and extracting the part that is present inside the box-braces.
	# The regex-string is selected such that the line should start with box bracket and
	# end with a box bracket. Anything between these brackets will be read and treated as
	# the name of the config. And if the line does not contain the name of the config,
	# then `config_name` will be an empty variable.
	config_name=$(echo "${line}" | grep -o '\[.*\]$')

	if [[ -z "${config_name}" ]]; then
		# If the name of the config is empty (indicating that the value in the particular
		# line is not the name of a config), jumping to the next line in the file.
		continue
	fi

	# If the line contains the name of a valid config, removing the box brackets at the
	# beginning and ending of the string by replacing them.
	config_name=$(echo "${config_name}" | sed "s/[][]//g")

	# Converting the name of the config to the name of directory inside the root directory.
	# Since the name of the directory is to be made using the name of the config, replacing
	# all characters that are not allowed for directory names in Windows.
	dir_name=$(echo "${config_name}" | sed 's.\\. .g; s./. .g; s.:. .g; s.". .g; s.|. .g')
	# For Linux, the a directory name can't contain forward-slash, however, as I'm on
	# Dual Boot currently (with the other OS being Windows), so I've veto-ed the decision to
	# forbid any characters that are not allowed in Windows.
	# Anyone who doesn't want this can make the changes to a fork or to their local copy.

	# Creating a directory for the config inside the root directory, and suppressing any
	# error(s) by redirecting STDERR to '/dev/null'. Also, the verbose flag is important
	# and will be used to verify that the directory was created successfully.
	output=$(mkdir "${root_dir}/${dir_name}" -v 2>/dev/null)

	if [[ -z "${output}" && "${output}" != *"created directory"* ]]; then
		# Since the error is being redirected to '/dev/null', in case of any error, the output
		# will be an empty string or if the output does not contain the string 'created directory',
		# the directory could not be created.

		if [[ $FORCE != true ]]; then
			# If the mount process is not to be forced, printing an error message and skipping
			# the mounting of the current config.
			echo "Failed to create directory ${dir_name}"
			continue
		fi

		# If the mount process is to be forced, printing a message indicating that the mounting of
		# the current config is forced.
		printf "\tForce mounting the directory '${root_dir}/${dir_name}'\n"
	fi

	# Mounting the directory if it exists.
	if [[ -d "${root_dir}/${dir_name}" ]]; then
		# Mounting the config to the created directory in a background process.
		rclone mount "${config_name}": "${root_dir}/${dir_name}" $MOUNT_FLAGS &
		# The '&' part at the end of the command, starts a background process instead of
		# blocking the terminal window.

		# Adding the mount path as a string to the mount file.
		echo "${root_dir}/${dir_name}" >>"./${MOUNT_FILE}"

		# Printing a message to inform that the config was mounted successfully.
		echo "Mounted config [${config_name}]"
	else
		# Printing an error message in case the directory could not be found.
		echo "Could not locate the directory '${root_dir}'"
	fi

done
