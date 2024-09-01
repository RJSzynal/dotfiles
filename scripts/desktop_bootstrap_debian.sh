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

SERVICE_LIST=()
STORAGE_DIR='/mnt/storage'
NORDELLE_DIR='/mnt/nordelle'

source ./library_debian.sh

# Base
apt-get update -y
apt-get install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dnsutils \
		firmware-amd-graphics \
		git \
		gnupg2 \
		jq \
		libgl1-mesa-dri \
		libglx-mesa0 \
		make \
		mesa-vulkan-drivers \
		neovim \
		rsync \
		silversearcher-ag \
		software-properties-common \
		ssh \
		thunar \
		thunar-archive-plugin \
		tig \
		unzip \
		wget \
		xserver-xorg-video-amdgpu \
	--no-install-recommends
install_docker "${TARGET_USER}"
install_google_drive "${TARGET_USER}"
install_oh_my_zsh "${TARGET_USER}"
install_fonts "${TARGET_USER}"

# Window manager
install_awesome "${TARGET_USER}"
apt-get install -y \
		gnome-keyring \
	--no-install-recommends

# Set up locale
sed -i -e 's|^# \(en_GB.UTF-8\)|\1|' -e 's|^\(en_US.UTF-8\)|# \1|' /etc/locale.gen
locale-gen

# Set Neovim as global editor
update-alternatives --set editor /usr/bin/nvim

# Desktop applications
apt-get install -y \
	--no-install-recommends \
	firefox-esr \
	gnome-terminal \
	keepassxc \
	terminator
install_vscodium
install_spotify
# install_lmms "${TARGET_USER}" "${STORAGE_DIR}"

# Set up dev repos
sudo -u ${TARGET_USER} git config --global pull.ff only
for repo in dotfiles dockerfiles; do
	if [[ ! -d "/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}" ]]; then
		sudo -u ${TARGET_USER} mkdir -p "/home/${TARGET_USER}/development/src/github.com/rjszynal/"
		sudo -u ${TARGET_USER} git clone git@github.com:RJSzynal/${repo}.git "/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/"
	fi
	if ! sudo -u ${TARGET_USER} git --git-dir="/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/.git" remote -v | grep bitbucket; then
		sudo -u ${TARGET_USER} git --git-dir="/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/.git" remote set-url --add --push origin git@bitbucket.org:RJSzynal/${repo}.git
		sudo -u ${TARGET_USER} git --git-dir="/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/.git" remote set-url --add --push origin git@github.com:RJSzynal/${repo}.git
	fi
done

# Enable services
if [ ${#SERVICE_LIST[@]} -gt 0 }; then
	systemctl daemon-reload
fi
for service in ${SERVICE_LIST}; do
	sudo systemctl enable ${service}
	sudo systemctl start ${service}
done

(cd /home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles && make all)

# Cleanup
apt autoremove
apt autoclean
apt clean
