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
	fi

	if [[ -z "${root_dir}" ]]; then
		# If root directory is not set (the value has neither been hard-coded nor been supplied
		# as an argument), getting the value from the user.
		read -p "Path for root directory: " root_dir
	fi

	# Validating if the path supplied as the root directory is valid or not.
	if [[ ! -d $root_dir ]]; then
		# Flow of control reaches here only if the path is invalid.
		printf "\nPath supplied as the root directory '${root_dir}' is invalid \n\n"

		# Empty the value of `root_dir` to ensure that the user is made to re-enter this value in
		# the next iteration of the loop.
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

	# If the path is valid, converting relative path to absolute.
	if [[ -f "${config}" ]]; then
		config=$(realpath "${config}")

		# If the converted path is valid, breaking out of the infinite loop.
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
	# end at box bracket. Anything between these brackets will be read and treated as
	# the name of the config. And if the line does not contain the name of the config,
	# then `config_name` will be an empty variable.
	config_name=$(echo "${line}" | grep -o '\[.*\]$')

	if [[ ! -z "${config_name}" ]]; then
		# If the name of the config is not empty (indicating that the value in the particular
		# line is the name of the config), then extracting the actual name of the config.
		# Replacing the starting and ending box-bracket with nothing.
		config_name=$(echo "${config_name}" | sed "s/[][]//g")

		# Converting the name of the config to the name of directory inside the root directory.
		# Since the name of the directory is to be made using the name of the config, replacing
		# colon, back-slash and forward-slashes (if any) with a space(s).
		dir_name=$(echo "${config_name}" | sed 's.\\. .g; s./. .g; s.:. .g')
		# For Linux, the name of a directory can't contain forward-slash, however, as I'm on
		# Dual Boot currently (with the other OS being Windows),so I've veto-ed the decision to
		# forbid backslash and colons from the directory name too :p
		# Anyone who wants to remove this restriction is free to make a fork without these restrictions.

		# Changing the directory to the root directory.
		cd "${root_dir}"

		# Creating a directory for the config inside root directory, and suppressing any error(s)
		# by redirecting STDERR to '/dev/null'
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
