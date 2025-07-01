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

source ./library_fedora.sh

# Base
dnf install -y \
	awscli2 \
	bind-utils \
	ca-certificates \
	curl \
	flatpak \
	git \
	glab \
	gnupg2 \
	i2c-tools \
	jq \
	lastpass-cli \
	make \
	neovim \
	podman \
	podman-compose \
	podman-docker \
	python3 \
	redis \
	rsync \
	ssh \
	the_silver_searcher \
	tig \
	unzip \
	wget
SERVICE_LIST+=( podman.socket )

podman login docker.io

git clone  https://github.com/DemonChocolatine/tas2781.git ~/development/src/github.com/DemonChocolatine/tas2781
(cd ~/development/src/github.com/DemonChocolatine/tas2781 && ./tas2781-fix.sh --install)

# Created "trusted" user-defined bridge network
docker network create trusted || true
install_google_drive "${TARGET_USER}"
install_onedrive "${TARGET_USER}"
install_oh_my_zsh "${TARGET_USER}"
install_terraform "${TARGET_USER}"
install_vagrant "${TARGET_USER}"
install_vscode "${TARGET_USER}"
install_lastpass ${TARGET_USER}"
# install_fonts "${TARGET_USER}" # These are already comitted in the .fonts dir

# # Set up locale
# sed -i -e 's|^# \(en_GB.UTF-8\)|\1|' -e 's|^\(en_US.UTF-8\)|# \1|' /etc/locale.gen
# locale-gen

# Set Neovim as global editor
update-alternatives --set editor /usr/bin/nvim

# Desktop applications
dnf install -y \
		firefox \
		chromium \
		keepassxc \
		terminator \
		vlc

# Set Terminator as global terminal
update-alternatives --set x-terminal-emulator /usr/bin/terminator

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
for flat in \
	com.getpostman.Postman \
	com.jetbrains.DataGrip \
	com.jetbrains.PhpStorm \
	com.jetbrains.PyCharm-Community \
	com.mongodb.Compass \
	com.spotify.Client \
	com.thincast.client \
	com.valvesoftware.Steam
do
	flatpak install --noninteractive flathub ${flat}
done

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

# Enable services
if [ ${#SERVICE_LIST[@]} -gt 0 ]; then
	systemctl daemon-reload
fi
for service in ${SERVICE_LIST}; do
	systemctl enable ${service}
done

# Cleanup
dnf autoremove
