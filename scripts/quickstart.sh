#!/bin/bash
set -e
set -o pipefail

if [ "${EUID}" -ne 0 ]; then
	echo "Please run as root."
	exit
fi

export DEBIAN_FRONTEND=noninteractive

# Choose a user account to use for this installation
if [ -z "${TARGET_USER-}" ]; then
	mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
	# if there is only one option just use that user
	if [ "${#options[@]}" -eq "1" ]; then
		TARGET_USER="${options[0]}"
		echo "Using user account: ${TARGET_USER}"
	else
		# iterate through the user options and print them
		PS3='Which user account should be used? '

		select opt in "${options[@]}"; do
			TARGET_USER=$opt
			break
		done
	fi
fi

# Base
apt-get update -y
apt-get install -y \
		git \
		make

# Clone dotfiles repo
if [[ ! -d "/home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles" ]]; then
	sudo -u ${TARGET_USER} mkdir -p "/home/${TARGET_USER}/development/src/github.com/rjszynal/"
	sudo -u ${TARGET_USER} git clone git@github.com:RJSzynal/dotfiles.git "/home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles/"
fi

(cd /home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles && make desktop)
