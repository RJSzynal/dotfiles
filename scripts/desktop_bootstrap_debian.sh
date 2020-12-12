#!/bin/bash
set -e
set -o pipefail

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root."
	exit
fi

export DEBIAN_FRONTEND=noninteractive

# Choose a user account to use for this installation
if [ -z "${TARGET_USER-}" ]; then
	mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
	# if there is only one option just use that user
	if [ "${#options[@]}" -eq "1" ]; then
		readonly TARGET_USER="${options[0]}"
		echo "Using user account: ${TARGET_USER}"
		return
	fi

	# iterate through the user options and print them
	PS3='command -v user account should be used? '

	select opt in "${options[@]}"; do
		readonly TARGET_USER=$opt
		break
	done
fi

SERVICE_LIST=( "i3lock@${TARGET_USER}" )
STORAGE_DIR='/mnt/storage'
NORDELLE_DIR='/mnt/nordelle'

install_fonts() {
	# Ubuntu
	wget https://assets.ubuntu.com/v1/0cef8205-ubuntu-font-family-0.83.zip -qO /tmp/ubuntu-font.zip
	mkdir -p /home/${TARGET_USER}/.local/share/fonts/Ubuntu
	unzip /tmp/ubuntu-font.zip -d /home/${TARGET_USER}/.local/share/fonts/Ubuntu/
	rm -f /tmp/ubuntu-font.zip
	# NerdFont Ubuntu Mono
	wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/UbuntuMono.zip -qO /tmp/UbuntuMono.zip
	mkdir -p /home/${TARGET_USER}/.local/share/fonts/NerdFonts
	unzip /tmp/UbuntuMono.zip -d /home/${TARGET_USER}/.local/share/fonts/NerdFonts/
	rm -f /tmp/UbuntuMono.zip
}

install_zsh() {
	apt-get install -y --no-install-recommends zsh
}

install_oh_my_zsh() {
	install_zsh
	wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -qO /tmp/oh-my-zsh_install.sh
	KEEP_ZSHRC=yes RUNZSH=no sh /tmp/oh-my-zsh_install.sh
	rm -f /tmp/oh-my-zsh_install.sh
	# Install zsh theme
	git clone https://github.com/bhilburn/powerlevel9k.git "/home/${TARGET_USER}/.oh-my-zsh/custom/themes/powerlevel9k"
}

install_autofs() {
	apt-get install -y --no-install-recommends autofs
	mkdir -p /etc/auto.master.d
	read -rp "Enter mount password: " mount_pass
	echo "user=administrator" > /root/.storage.creds
	echo "pass=${mount_pass}" >> /root/.storage.creds
	SERVICE_LIST+=( autofs )
}

install_chrome() {
	curl https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
	echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome.list
	apt-get update -y
	apt-get install -y --no-install-recommends google-chrome-stable
}

install_docker() {
	wget -qO - https://download.docker.com/linux/debian/gpg | apt-key add -
	echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
	apt-get update -y
	apt-get install -y --no-install-recommends docker-ce
	systemctl enable docker
	systemctl start docker
	usermod -aG docker "${TARGET_USER}"
	# Run the Docker daemon as a non-root user
	sysctl --system
	modprobe overlay permit_mounts_in_userns=1
}

install_google_drive() {
	mkdir "/home/${TARGET_USER}/googledrive-home"
	#mkdir "/home/${TARGET_USER}/googledrive-work"
	chown "${TARGET_USER}": "/home/${TARGET_USER}/googledrive-home"
	#chown "${TARGET_USER}": "/home/${TARGET_USER}/googledrive-work"

	apt-get install -y \
		--no-install-recommends \
		fuse \
		dirmngr
	cat > /etc/apt/sources.list.d/alessandro-strada-ubuntu-ppa-bionic.list <<-"EOF"
		deb http://ppa.launchpad.net/alessandro-strada/ppa/ubuntu xenial main
		deb-src http://ppa.launchpad.net/alessandro-strada/ppa/ubuntu xenial main
	EOF
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AD5F235DF639B041
	apt-get update -y
	apt-get install -y --no-install-recommends google-drive-ocamlfuse

	google-drive-ocamlfuse "/home/${TARGET_USER}/googledrive-home"
	#google-drive-ocamlfuse -label work "/home/${TARGET_USER}/googledrive-work"
}

install_lmms() {
	download_url=$(curl --silent "https://api.github.com/repos/LMMS/lmms/releases/latest" | grep -Po '"browser_download_url": "\K.*?(?=")' | grep linux)
	wget "${download_url}" -o "/home/${TARGET_USER}/Downloads/lmms.AppImage"
	chown "${TARGET_USER}": "/home/${TARGET_USER}/Downloads/lmms.AppImage"
	cat > "/home/${TARGET_USER}/lmms.sh" <<-EOF
		#!/bin/bash

		for directory in 'samples' 'soundfonts' 'lmms/projects'; do
			rsync -av --delete ${STORAGE_DIR}/music/\${directory} \/home/${TARGET_USER}/lmms/
		done

		QT_SCALE_FACTOR=1.2 "\/home/${TARGET_USER}/Downloads/lmms.AppImage"

		rsync -av --delete \/home/${TARGET_USER}/lmms/projects ${STORAGE_DIR}/music/lmms/
		for directory in 'samples' 'soundfonts'; do
			rsync -av --delete \/home/${TARGET_USER}/lmms/\${directory} ${STORAGE_DIR}/music/
		done
	EOF
}

install_spotify() {
	curl -sSL https://download.spotify.com/debian/pubkey.gpg | apt-key add -
	echo 'deb http://repository.spotify.com stable non-free' > /etc/apt/sources.list.d/spotify.list
	apt-get update -y
	apt-get install -y --no-install-recommends spotify-client
}

install_vscodium() {
	curl -sSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | apt-key add -
	echo 'deb https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/repos/debs/ vscodium main' > /etc/apt/sources.list.d/vscodium.list
	apt-get update -y
	apt-get install -y --no-install-recommends codium
}

install_traefik() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/traefik.service.notls /etc/systemd/system/traefik.service
	SERVICE_LIST+=( traefik )
}

install_folding() {
	curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | \
	sudo apt-key add -
	distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
	curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | \
	sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
	apt-get update -y
	apt-get install -y nvidia-container-runtime libcuda1
	mkdir -p /etc/systemd/system/docker.service.d
	cat > /etc/systemd/system/docker.service.d/override.conf <<-EOF
		[Service]
		ExecStart=
		ExecStart=/usr/bin/dockerd --host=fd:// --add-runtime=nvidia=/usr/bin/nvidia-container-runtime
	EOF
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/folding.service.local /etc/systemd/system/folding.service
	SERVICE_LIST+=( folding )
}

install_i3() {
	apt-get install -y \
		--no-install-recommends \
		feh \
		i3 \
		i3lock \
		maim \
		xclip \
		xorg
}

install_awesome() {
	apt-get install -y \
		--no-install-recommends \
		awesome \
		i3lock \
		maim \
		xclip \
		xorg
}

# Base
apt-get update -y
apt-get install -y \
	--no-install-recommends \
	apt-transport-https \
	ca-certificates \
	firmware-realtek \
	gnupg2 \
	jq \
	neovim \
	nvidia-driver \
	rsync \
	silversearcher-ag \
	software-properties-common \
	thunar \
	thunar-archive-plugin \
	unzip \
	wget
install_docker
install_google_drive

# Window manager
install_awesome
apt-get install -y \
	--no-install-recommends \
	gnome-keyring

# Desktop applications
apt-get install -y \
	--no-install-recommends \
	firefox-esr \
	gnome-terminal \
	keepassxc \
	terminator
install_vscodium
install_spotify
# install_lmms

# Set up dev repos
for repo in dotfiles dockerfiles; do
	if [[ ! -d "/home/${TARGET_USER}/development/github.com/rjszynal/${repo}" ]]; then
		mkdir -p "/home/${TARGET_USER}/development/github.com/rjszynal/"
		git clone https://github.com/RJSzynal/${repo}.git "/home/${TARGET_USER}/development/github.com/rjszynal/${repo}/"
	fi
	if ! git --git-dir="/home/${TARGET_USER}/development/github.com/rjszynal/${repo}/.git" remote -v | grep bitbucket; then 
		git --git-dir="/home/${TARGET_USER}/development/github.com/rjszynal/${repo}/.git" remote set-url --add --push origin git@bitbucket.org:RJSzynal/${repo}.git
	fi
done

# Enable services
systemctl daemon-reload
for service in ${SERVICE_LIST}; do
	sudo systemctl enable ${service}
	sudo systemctl start ${service}
done

# Cleanup
apt autoremove
apt autoclean
apt clean
