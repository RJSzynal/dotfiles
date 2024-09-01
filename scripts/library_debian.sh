#!/bin/bash

install_fonts() {
	# Ubuntu
	wget https://assets.ubuntu.com/v1/0cef8205-ubuntu-font-family-0.83.zip -qO /tmp/ubuntu-font.zip
	mkdir -p /home/${1}/.local/share/fonts/Ubuntu
	unzip /tmp/ubuntu-font.zip -d /home/${1}/.local/share/fonts/Ubuntu/
	rm -f /tmp/ubuntu-font.zip
	# NerdFont Ubuntu Mono
	wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/UbuntuMono.zip -qO /tmp/UbuntuMono.zip
	mkdir -p /home/${1}/.local/share/fonts/NerdFonts
	unzip /tmp/UbuntuMono.zip -d /home/${1}/.local/share/fonts/NerdFonts/
	rm -f /tmp/UbuntuMono.zip
}

install_zsh() {
	apt-get install -y --no-install-recommends zsh
}

install_oh_my_zsh() {
	install_zsh
	KEEP_ZSHRC=yes RUNZSH=no sudo -u ${1} sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	# Install zsh theme
	sudo -u ${1} git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k"
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
	sudo bash -c 'curl -s https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/chrome.gpg'
	echo "deb [signed-by=/usr/share/keyrings/chrome.gpg arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
		> /etc/apt/sources.list.d/google-chrome.list
	apt-get update -y
	apt-get install -y --no-install-recommends google-chrome-stable
}

install_docker() {
	# Enable buildkit
	if [ -f /etc/docker/daemon.json ]; then
		cat /etc/docker/daemon.json | jq '.features.buildkit = true' > /etc/docker/daemon.json.tmp && mv /etc/docker/daemon.json{.tmp,}
	else
		jq --null-input '.features.buildkit = true' > /etc/docker/daemon.json
	fi
	# Setup APT repository
	sudo bash -c 'curl -s https://download.docker.com/linux/debian/gpg | gpg --dearmor > /usr/share/keyrings/docker.gpg'
	echo "deb [signed-by=/usr/share/keyrings/docker.gpg arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
		> /etc/apt/sources.list.d/docker.list
	# [ -z "$(uname -a | grep -i 'wsl')" ] || update-alternatives --set iptables /usr/sbin/iptables-legacy
	# Install Docker
	apt-get update -y
	apt-get install -y \
			containerd.io \
			docker-buildx-plugin \
			docker-ce \
			docker-ce-cli \
			docker-compose-plugin \
		--no-install-recommends
	usermod -aG docker "${1}"
	# Run the Docker daemon as a non-root user
	if [ -z "$(uname -a | grep -i 'wsl')" ]; then
		systemctl disable --now docker.service docker.socket
		rm /var/run/docker.sock
		apt-get install -y \
				dbus-user-session \
				docker-ce-rootless-extras \
				slirp4netns \
			--no-install-recommends
		sudo -u ${1} dockerd-rootless-setuptool.sh install
	fi
}

install_google_drive() {
	mkdir "/home/${1}/googledrive-home"
	#mkdir "/home/${1}/googledrive-work"
	chown "${1}": "/home/${1}/googledrive-home"
	#chown "${1}": "/home/${1}/googledrive-work"

	apt-get install -y \
		--no-install-recommends \
		fuse \
		dirmngr
	cat > /etc/apt/sources.list.d/alessandro-strada-ubuntu-ppa-jammy.list <<-"EOF"
		deb http://ppa.launchpad.net/alessandro-strada/ppa/ubuntu jammy main
		deb-src http://ppa.launchpad.net/alessandro-strada/ppa/ubuntu jammy main
	EOF
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AD5F235DF639B041
	apt-get update -y
	apt-get install -y --no-install-recommends google-drive-ocamlfuse

	google-drive-ocamlfuse "/home/${1}/googledrive-home"
	#google-drive-ocamlfuse -label work "/home/${1}/googledrive-work"
}

install_lmms() {
	download_url=$(curl --silent "https://api.github.com/repos/LMMS/lmms/releases/latest" | grep -Po '"browser_download_url": "\K.*?(?=")' | grep linux)
	wget "${download_url}" -o "/home/${1}/Downloads/lmms.AppImage"
	chown "${1}": "/home/${1}/Downloads/lmms.AppImage"
	cat > "/home/${1}/lmms.sh" <<-EOF
		#!/bin/bash

		for directory in 'samples' 'soundfonts' 'lmms/projects'; do
			rsync -av --delete ${2}/music/\${directory} \/home/${1}/lmms/
		done

		QT_SCALE_FACTOR=1.2 "\/home/${1}/Downloads/lmms.AppImage"

		rsync -av --delete \/home/${1}/lmms/projects ${2}/music/lmms/
		for directory in 'samples' 'soundfonts'; do
			rsync -av --delete \/home/${1}/lmms/\${directory} ${2}/music/
		done
	EOF
}

install_spotify() {
	sudo bash -c 'curl -s https://download.spotify.com/debian/pubkey.gpg | gpg --dearmor > /usr/share/keyrings/spotify.gpg'
	echo 'deb [signed-by=/usr/share/keyrings/spotify.gpg arch=amd64] http://repository.spotify.com stable non-free' \
		> /etc/apt/sources.list.d/spotify.list
	apt-get update -y
	apt-get install -y --no-install-recommends spotify-client
}

install_vscodium() {
	sudo bash -c 'curl -s https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor > /usr/share/keyrings/vscodium.gpg'
	echo 'deb [signed-by=/usr/share/keyrings/vscodium.gpg arch=amd64] https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/repos/debs/ vscodium main' \
		> /etc/apt/sources.list.d/vscodium.list
	apt-get update -y
	apt-get install -y --no-install-recommends codium
}

install_traefik() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/traefik.service.notls /etc/systemd/system/traefik.service
	SERVICE_LIST+=( traefik )
}

install_folding() {
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
	SERVICE_LIST+=( i3lock@${1} )
}

install_awesome() {
	apt-get install -y \
		--no-install-recommends \
		awesome \
		i3lock \
		maim \
		xclip \
		xorg
	SERVICE_LIST+=( i3lock@${1} )
}
