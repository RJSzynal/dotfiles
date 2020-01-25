#!/bin/bash
set -e
set -o pipefail

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root."
	exit
fi

STORAGE_DIR='/mnt/storage'
NORDELLE_DIR='/mnt/nordelle'

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

install_zsh() {
	apt-get install -y --no-install-recommends zsh
	# Install zsh theme
	git clone https://github.com/bhilburn/powerlevel9k.git "${HOME}/.oh-my-zsh/custom/themes/powerlevel9k"
}

install_oh_my_zsh() {
	install_zsh
	wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -qO oh-my-zsh_install.sh
	RUNZSH=no sh oh-my-zsh_install.sh
	rm -f oh-my-zsh_install.sh
}

install_autofs() {
	apt-get install -y --no-install-recommends autofs
	mkdir -p /etc/auto.master.d
	echo '/mnt	/etc/auto.mnt' > /etc/auto.master.d/storage.autofs
	cat > /etc/auto.mnt <<-EOF
		storage	 -rw,soft,intr,rsize=8192,wsize=8192 storage.szynal.co.uk:${STORAGE_DIR}
		torrent  -rw,soft,intr,rsize=8192,wsize=8192 storage.szynal.co.uk:/home/${TARGET_USER}/torrent
		nordelle -rw,soft,intr,rsize=8192,wsize=8192 nordelle.szynal.co.uk:${NORDELLE_DIR}
	EOF
	service autofs start
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
	echo 'kernel.unprivileged_userns_clone=1' > /etc/sysctl.d/00-local-userns.conf
	service procps restart
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
	sed -i '/#user_allow_other/ s/^#//' /etc/fuse.conf

	google-drive-ocamlfuse "/home/${TARGET_USER}/googledrive-home"
	#google-drive-ocamlfuse -label work "/home/${TARGET_USER}/googledrive-work"
}

install_lmms() {
	download_url=$(curl --silent "https://api.github.com/repos/LMMS/lmms/releases/latest" | grep -Po '"browser_download_url": "\K.*?(?=")' | grep linux)
	wget "${download_url}" -o "${HOME}/Downloads/lmms.AppImage"
	chown "${TARGET_USER}": "${HOME}/Downloads/lmms.AppImage"
	cat > "${HOME}/lmms.sh" <<-EOF
		#!/bin/bash

		for directory in 'samples' 'soundfonts' 'lmms/projects'; do
			rsync -av --delete ${STORAGE_DIR}/music/\${directory} \${HOME}/lmms/
		done

		QT_SCALE_FACTOR=1.2 "\${HOME}/Downloads/lmms.AppImage"

		rsync -av --delete \${HOME}/lmms/projects ${STORAGE_DIR}/music/lmms/
		for directory in 'samples' 'soundfonts'; do
			rsync -av --delete \${HOME}/lmms/\${directory} ${STORAGE_DIR}/music/
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
	rsync \
	silversearcher-ag \
	software-properties-common \
	unzip \
	wget
install_docker
install_google_drive

# Window manager
apt-get install -y \
	--no-install-recommends \
	feh \
	i3 \
	i3lock \
	maim \
	suckless-tools \
	xclip \
	xorg

# Desktop applications
apt-get install -y \
	--no-install-recommends \
	firefox-esr \
	keepassxc \
	terminator
install_vscodium
install_spotify
install_lmms

# Set up dev repos
for repo in dotfiles dockerfiles; do
	if [[ ! -d "${HOME}/development/github.com/rjszynal/${repo}" ]]; then
		git clone https://github.com/RJSzynal/${repo}.git "${HOME}/development/github.com/rjszynal/${repo}/"
	fi
	if ! git --git-dir="${HOME}/development/github.com/rjszynal/${repo}/.git" remote -v | grep bitbucket; then 
		git --git-dir="${HOME}/development/github.com/rjszynal/${repo}/.git" remote set-url --add --push origin git@bitbucket.org:RJSzynal/${repo}.git
	fi
done

# Enable services
sudo systemctl enable "i3lock@${TARGET_USER}"

# Cleanup
apt autoremove
apt autoclean
apt clean
