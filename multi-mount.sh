#!/bin/bash

# This script will get a list of all RClone configs in the device, and mount them inside the
# root directory. All the configs regardless of their type will be mounted by this script.

# Location of the root directory. A separate directory will be created to use as a mount point
# for each RClone config inside the root directory. A valid path can be hard-coded as the value
# of the variable if required.
root_dir=""

# The flag that should be used while passing the root directory argument to use
# the directory as the root directory.
DIR_FLAG="--root="

# Force flag, will be used to indicate that the value is forced. Alternatively, "-F" can also
# be supplied as an arguement to have the same impact.
FORCE_ARGUMENT="--force"

# Will be used to determine if the process of mounting drives to directories should be forced.
# Should contain a boolean value, can be hard-coded with a default value if required. Initially
# setting the value of this variable to be an empty string.
FORCE=""

# The name of the text file that will contain the ID of the background processes running RClone,
# and the directories that have been mounted.
# NOTE: If the value of this string is changed, the corresponding value in `unmount.sh` should
# also be changed.
MOUNT_FILE="mount.txt"

# String containing the name of the ignore file.
IGNORE_FILE="ignore.conf"

# String containing the name of the rename file.
RENAME_FILE="rename.conf"

# The amount of seconds the script should sleep once a config is mounted. This is done to get
# accurate result as to whether a config is mounted sucessfully or not.
# Recommended sleep time is 2 seconds. Anything above 4 seconds would be an overkill.
SLEEP=2

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

# Array containing the configs that are to be ignored. The name of any config present inside this
# array won't be mounted while auto-mounting all the configs. Can be hard-coded (not recommended).
IGNORED_FILES=()

# An array that will contain the configs that are to be renamed. Order inside the array is extremely
# important. Should not be hard-coded.
RENAME_OLD=()

# An array that will contain the new names that are to be used while mounting the configs to directories.
# The names for directories will be created using names from this list. Should not be hard-coded.
RENAME_NEW=()

#
# Logic explanation:
#	Both the arrays, `RENAME_OLD` and `RENAME_NEW` are to be used together. They are designed to be
#	used as a hacky alternate for dictionary.
#
#	The value in `RENAME_OLD` will contain the names of the configs that are to be renamed.
# 	The corresponding value in `RENAME_NEW` will be the name that is to be used instead of the orignal name.
#
#	For example, the following values in the two array
#		RENAME_OLD=("DemonRem" "Test")
#		RENAME_NEW=("RemDemonic", "P:")
#
# 	Will ensure that the config "DemonRem" is mounted to the directory "RemDemonic" inside the root directory,
#	and similarly, the config "Test" is mounted to the directory "P:" inside the root directory.
#
# And yep, I know that this is a very hack-y approach and should never be used for anything crucial.
# In my defence, welp, it works well enough in this scenario and I see no need to change it
#
#	¯\_(ツ)_/¯
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

# Getting a list of all the configs that are to be ignored from the ignore file.
# Starting by checking if the config file actually exists.
if [[ -e $IGNORE_FILE ]]; then
	while IFS= read -r line; do
		# Stripping leading and ending whitespaces from the line
		line=$(echo -e "${line}")

		# If the new length of the line is 0, skipping it or if the first character of the
		# line is a hash symbol (#), skipping the line.
		if [[ "${#line}" -eq 0 || $(echo -e "${line}" | cut -c1-1) == "#" ]]; then
			continue
		fi

		# Adding the line to the array containing configs to be ignored.
		IGNORED_FILES+=("${line}")
	done <"${IGNORE_FILE}"
fi

# Validating the path of the rename file, and parsing it if it exists.
if [[ -e "${RENAME_FILE}" ]]; then
	while IFS= read -r line; do
		# Stripping the leading and trailing white spaces.
		line=$(echo -e "${line}")

		# If the new length of the line is zero, or if the first character is
		# hash symbol (#), skipping it
		if [[ "${#line}" -eq 0 || $(echo "${line}" | cut -c1-1) == "#" ]]; then
			continue
		fi

		# Getting the name of the config by getting everything before "->" and then trimming spaces.
		# The grep query below will also include "->", using sed to remove that.
		original=$(echo -e $(echo "${line}" | grep -o '.*\->' | sed "s.->..g"))

		# Getting the new name using the same process, extracting everything after "->"
		new=$(echo -e $(echo "${line}" | grep -o '\->.*' | sed "s.->..g"))

		# If neither of these variables is empty and nor a blank string, adding the value to the arrays.
		if [[ ! -z "${original}" && ! -z "${new}" ]]; then
			RENAME_OLD+=("${original}")
			RENAME_NEW+=("${new}")
		fi

	done <"${RENAME_FILE}"
fi

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

	# Checking if config is to be ignored. If the name matches a value in the ignore list,
	# then skipping the process of mounting the current config.
	found=false
	for ignore_config in "${IGNORED_FILES[@]}"; do
		if [[ "${ignore_config}" == "${config_name}" ]]; then
			found=true
			break
		fi
	done

	if [[ $found == true ]]; then
		continue
	fi

	# Resetting the value of the variable. Without this step, often the variable retains
	# the values from some previous iterations of the loop and causes problems with the rest
	# of the script.
	dir_name=""

	# Checking if the config is to be renamed.
	for i in "${!RENAME_OLD[@]}"; do
		if [[ "${config_name}" == "${RENAME_OLD[$i]}" ]]; then
			# If the name of the config is present in the array of configs to be renamed, then
			# using the value provided as the directory name. Selecting the value at the
			# corresponding index of `RENAME_NEW` array. Illegal characters from this value
			# will be removed separately.
			dir_name="${RENAME_NEW[$i]}"
			break
		fi
	done

	# Setting the name of the directory to be the same as the config if the vairable has no
	# value (illegal variables will be removed separately)
	if [[ -z "${dir_name}" ]]; then
		dir_name="${config_name}"
	fi

	# Replacing all characters that are not allowed in directory names with spaces.
	dir_name=$(echo "${dir_name}" | sed 's.\\. .g; s./. .g; s.:. .g; s.". .g; s.|. .g')
	# For Linux, the a directory name can't contain forward-slash, however, as I'm on
	# Dual Boot currently (with the other OS being Windows), so I've veto-ed the decision to
	# forbid any characters that are not allowed in Windows.
	# Anyone who doesn't want this can make the changes to a fork or to their local copy.
	#
	# (O_O;)

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
		rclone mount "${config_name}": "${root_dir}/${dir_name}" $MOUNT_FLAGS 2>/dev/null &
		# The '&' part at the end of the command, starts a background process instead of
		# blocking the terminal window.

		if [[ $SLEEP -ge 0 ]]; then
			# Sleeping for the given time. This is done to give time to RClone to throw an
			# error if the config could not be mounted.
			sleep $SLEEP
		fi

		# Once a background process is started, it is assigned an ID, even if the result
		# of the process was an error, it would still have an ID. Also, if the mount command
		# above caused an error, the process will be dead by now (hopefully).
		# Thus checking to see if the process is still running.

		# Incase a process with the ID is still running, simply assuming that it is the same
		# process and the config is mounted successfully.
		process=$! # Getting the ID of the last process run in background.

		# Getting the total number of processes running (at the moment) that have the same ID
		# as the most recent background process. Since there are 32K available PID's (by default),
		# the chances of another process having the same PID are negligible.
		running_count=$(ps -A | grep $process | wc -l)
		# Above command will get a list of the currently running processes, grep will take only
		# those lines that contain the PID, and then count the total number of lines (with each
		# line indicating one process).

		# If the config was mounted successfully, it should still be running, and thus, the value
		# of the vairable should be `1`.

		if [[ $running_count -eq 1 ]]; then
			# Adding the mount path as a string to the mount file.
			echo "${root_dir}/${dir_name}" >>"./${MOUNT_FILE}"

			# Printing a message to inform that the config was mounted successfully.
			echo "Mounted config [${config_name}]"
		else
			echo "Failed to mount the config [${config_name}]"
		fi
	else
		# Printing an error message in case the directory could not be found.
		echo "Could not locate the directory '${root_dir}'"
	fi

done
