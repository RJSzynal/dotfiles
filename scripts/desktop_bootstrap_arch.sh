#!/bin/bash
set -e
set -o pipefail

if [ "${EUID}" -ne 0 ]; then
	echo "Please run as root."
	exit
fi

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

source ./library_arch.sh

# Base
pacman --noconfirm -Syu \
		base-devel \
		ca-certificates \
		curl \
		git \
		gnupg \
		jq \
		linux-headers \
		make \
		neovim \
		rsync \
		the_silver_searcher \
		tig \
		unzip \
		wget
aur_install autofs
install_docker "${TARGET_USER}"
install_google_drive "${TARGET_USER}"
install_oh_my_zsh "${TARGET_USER}"
# install_fonts "${TARGET_USER}" # These are already comitted in the .fonts dir

# # Wayland
# pacman --noconfirm -S \
# 		wayland \
# 		xorg-xwayland

# # File Browser
# pacman --noconfirm -S \
# 		thunar \
# 		thunar-archive-plugin

# Audio
pacman --noconfirm -S \
		alsa-utils \
		pipewire \
		pipewire-audio \
		pipewire-alsa \
		pipewire-jack \
		pipewire-pulse \
		wireplumber
aur_install dcaenc

# Graphics drivers
pacman --noconfirm -S \
		mesa \
		vulkan-radeon \
		xf86-video-amdgpu

# Window manager
# install_awesome "${TARGET_USER}"
install_gnome "${TARGET_USER}"
# install_kde "${TARGET_USER}"

# Set up locale
sed -i -e 's|^# \(en_GB.UTF-8\)|\1|' /etc/locale.gen
locale-gen

# Set Neovim as global editor
update-alternatives --set editor /usr/bin/nvim

# Desktop applications
pacman --noconfirm -S \
		firefox \
		gnome-terminal \
		spotify-launcher \
		terminator \
		vlc
install_keepassxc
install_vscodium
install_steam
# install_lmms "${TARGET_USER}" "${STORAGE_DIR}"

# Set Terminator as global terminal
update-alternatives --set x-terminal-emulator /usr/bin/terminator

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
	(cd "/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/" \
	&& git submodule update --init --recursive)
done

# Install XBox One Controller driver and firmware
aur_install xone-dlundqvist-dkms-git
aur_install xone-dongle-firmware

# Install Logitech MX Master driver
pacman --noconfirm -S solaar

# Install Corsair keyboard driver
aur_install ckb-next

# Enable services
if [ ${#SERVICE_LIST[@]} -gt 0 ]; then
	systemctl daemon-reload
fi
for service in ${SERVICE_LIST}; do
	systemctl enable ${service}
done

# Cleanup
pacman --noconfirm -Sucy
