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

# Iterating over each argument supplied, and using the argument if it is valid.
for argument in "${@}"; do
	if [[ $argument == $DIR_FLAG* && -z $root_dir ]]; then
		# If the root directory is not set already and the argument starts with the flag for root
		# directory, replacing the flag from the string and taking the rest as the root directory.
		root_dir=$(echo ${argument} | sed "s/${DIR_FLAG}//g")
	elif [[ -z $FORCE && ("${argument,,}" == "${FORCE_ARGUMENT,,}" || "${argument}" == "-F") ]]; then
		# If the value of force is blank string (same as default), and if the force argument is
		# supplied, setting the value of the variable to be true.
		FORCE=true
	fi
done

if [[ -z $FORCE ]]; then
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
	if [[ ! -d $root_dir ]]; then
		# Flow of control reaches here only if the path is not valid.
		printf "\nPath supplied as the root directory '${root_dir}' is invalid \n\n"

		# Empty the value of `root_dir` to ask the user is to re-enter this value in the next iteration.
		root_dir=""
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
		if [[ -f $config ]]; then
			break
		else
			echo "Problems while converting into absolute path. Enter the absolute path."
			echo
		fi
	fi
done

# Reading the contents of the config file line-by-line.
cut -f2 "${config}" | while read line; do

	# Reading the line and extracting the part that is present inside the box-braces.
	# The regex-string is selected such that the line should start with box bracket and
	# end with a box bracket. Anything between these brackets will be read and treated as
	# the name of the config. And if the line does not contain the name of the config,
	# then `config_name` will be an empty variable.
	config_name=$(echo "${line}" | grep -o '\[.*\]$')

	if [[ ! -z "${config_name}" ]]; then
		# If the name of the config is not empty (indicating that the value in the particular
		# line is the name of the config), then extracting the actual name of the config.
		# Removing the brackets by replacing them with nothing.
		config_name=$(echo "${config_name}" | sed "s/[][]//g")

		# Converting the name of the config to the name of directory inside the root directory.
		# Since the name of the directory is to be made using the name of the config, replacing
		# all characters that are not allowed for directory names in Windows.
		dir_name=$(echo "${config_name}" | sed 's.\\. .g; s./. .g; s.:. .g; s.". .g; s.|. .g')
		# For Linux, the a directory name can't contain forward-slash, however, as I'm on
		# Dual Boot currently (with the other OS being Windows), so I've veto-ed the decision to
		# forbid any characters that are not allowed in Windows.
		# Anyone who doesn't want this can make the changes to a fork or to their local copy.

		# Changing the directory to the root directory.
		cd "${root_dir}"

		# Creating a directory for the config, and suppressing any error(s) by redirecting
		# STDERR to '/dev/null'
		output=$(mkdir "${dir_name}" -v 2>/dev/null)

		if [[ ! -z "${output}" && "${output}" == *"created directory"* ]]; then
			# If the output contains the string 'created directory', this indicates that the directory
			# was created successfully.
			echo "Created directory ${dir_name}"
		else
			# Since the error is being redirected to '/dev/null', in case of any error, the output
			# will be an empty string.
			echo "Failed to create directory ${dir_name}"
		fi
	fi
done
