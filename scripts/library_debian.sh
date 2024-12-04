#!/bin/bash

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

install_autofs() {
	apt-get install -y --no-install-recommends autofs
	mkdir -p /etc/auto.master.d
	if [[ ! -f /root/.storage.creds ]]; then
		read -rp "Enter mount password: " mount_pass
		echo "user=administrator" > /root/.storage.creds
		echo "pass=${mount_pass}" >> /root/.storage.creds
	fi
	SERVICE_LIST+=( autofs )
}

install_chrome() {
	curl -s https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /usr/share/keyrings/chrome.gpg
	echo "deb [signed-by=/usr/share/keyrings/chrome.gpg arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
		> /etc/apt/sources.list.d/google-chrome.list
	
	apt-get update -y
	apt-get install -y --no-install-recommends google-chrome-stable
}

install_firefox() {
	curl -s https://packages.mozilla.org/apt/repo-signing-key.gpg | gpg --dearmor --yes -o /usr/share/keyrings/mozilla.gpg
	echo "deb [signed-by=/usr/share/keyrings/mozilla.gpg arch=amd64] https://packages.mozilla.org/apt mozilla main" \
		> /etc/apt/sources.list.d/mozilla.list
	cat > /etc/apt/preferences.d/mozilla.pref <<-PREF
		Package: *
		Pin: origin packages.mozilla.org
		Pin-Priority: 1000
	PREF
	apt-get update -y
	apt-get install -y --no-install-recommends firefox
}

install_docker() {
	# Enable buildkit
	if [ -f /etc/docker/daemon.json ]; then
		cat /etc/docker/daemon.json | jq '.features.buildkit = true' > /etc/docker/daemon.json.tmp && mv /etc/docker/daemon.json{.tmp,}
	else
		jq --null-input '.features.buildkit = true' > /etc/docker/daemon.json
	fi
	# Setup APT repository
	curl -s https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /usr/share/keyrings/docker.gpg
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
	# Created "trusted" user-defined bridge network
	docker network create trusted
	# Run the Docker daemon as a non-root user
	if [ -z "$(uname -a | grep -i 'wsl')" ]; then
		systemctl disable --now docker.service docker.socket
		rm /var/run/docker.sock || true
		apt-get install -y \
				dbus-user-session \
				docker-ce-rootless-extras \
				slirp4netns \
				uidmap \
			--no-install-recommends
		sudo -u ${1} dockerd-rootless-setuptool.sh install
	fi
}

install_folding() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/folding.service.local /etc/systemd/system/folding.service
	SERVICE_LIST+=( folding )
}

install_fonts() {
	# Ubuntu
	if [[ ! -d "/home/${1}/.local/share/fonts/Ubuntu" ]]; then
		wget https://assets.ubuntu.com/v1/0cef8205-ubuntu-font-family-0.83.zip -qO /tmp/ubuntu-font.zip
		mkdir -p "/home/${1}/.local/share/fonts/Ubuntu"
		unzip /tmp/ubuntu-font.zip -d "/home/${1}/.local/share/fonts/Ubuntu/"
		rm -f /tmp/ubuntu-font.zip
	fi
	# NerdFont Ubuntu Mono
	if [[ ! -d "/home/${1}/.local/share/fonts/NerdFonts" ]]; then
		wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/UbuntuMono.zip -qO /tmp/UbuntuMono.zip
		mkdir -p "/home/${1}/.local/share/fonts/NerdFonts"
		unzip /tmp/UbuntuMono.zip -d "/home/${1}/.local/share/fonts/NerdFonts/"
		rm -f /tmp/UbuntuMono.zip
	fi
}

install_ckb-next() {
	curl -s 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0A27146C4BA99E385BA62766BA84DB44A908C515' | gpg --dearmor --yes -o /usr/share/keyrings/tatokis.gpg
	echo 'deb [signed-by=/usr/share/keyrings/tatokis.gpg arch=amd64] https://ppa.launchpadcontent.net/tatokis/ckb-next/ubuntu noble main ' \
		> /etc/apt/sources.list.d/tatokis-ubuntu-ppa-noble.list
	apt-get update
	apt-get install -y --no-install-recommends ckb-next
}

install_google_drive() {
	mkdir -p "/home/${1}/googledrive-home"
	#mkdir -p "/home/${1}/googledrive-work"
	chown "${1}": "/home/${1}/googledrive-home"
	#chown "${1}": "/home/${1}/googledrive-work"

	apt-get install -y \
		--no-install-recommends \
		fuse \
		dirmngr
	curl -s 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xA7AFF39895544C77C124BB46FEAC8456AF83AFEB' | gpg --dearmor --yes -o /usr/share/keyrings/alessandro-strada.gpg
	echo 'deb [signed-by=/usr/share/keyrings/alessandro-strada.gpg arch=amd64] http://ppa.launchpad.net/alessandro-strada/ppa/ubuntu jammy main' \
		> /etc/apt/sources.list.d/alessandro-strada-ubuntu-ppa-jammy.list
	apt-get update
	apt-get install -y --no-install-recommends google-drive-ocamlfuse

	#google-drive-ocamlfuse "/home/${1}/googledrive-home"
	#google-drive-ocamlfuse -label work "/home/${1}/googledrive-work"
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

install_keepassxc() {
	apt-get update
	apt-get install -y \
			keepassxc-full \
			g++ \
			linux-headers-amd64 \
			libsystemd-dev \
			libsystemd-dev \
			libxkbcommon-dev \
			mono-complete \
		--no-install-recommends
	TMP_DIR=$(mktemp -d)
	wget https://keepass.info/extensions/v2/kpuinput/KPUInput-1.4.zip -qO ${TMP_DIR}/kpuinput.zip
	unzip ${TMP_DIR}/kpuinput.zip -d "${TMP_DIR}"
	chmod +x ${TMP_DIR}/KPUInputN.sh
	(cd ${TMP_DIR}; ./KPUInputN.sh)
	mv ${TMP_DIR}/KPUInput{.*,N.so} /usr/lib/x86_64-linux-gnu/keepassxc/
	rm -rf ${TMP_DIR}
	apt-get remove -y \
			g++ \
			linux-headers-amd64 \
			libsystemd-dev \
			libsystemd-dev \
			libxkbcommon-dev \
			mono-complete
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

install_oh_my_zsh() {
	install_zsh
	if [[ ! -d "/home/${1}/.oh-my-zsh" ]]; then
		sudo -u ${1} sh -c "KEEP_ZSHRC=yes RUNZSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi
	# Install zsh theme
	if [[ ! -d "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
		sudo -u ${1} git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k"
	fi
}

install_spotify() {
	curl -s https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes -o /usr/share/keyrings/spotify.gpg
	echo 'deb [signed-by=/usr/share/keyrings/spotify.gpg arch=amd64] http://repository.spotify.com stable non-free' \
		> /etc/apt/sources.list.d/spotify.list
	apt-get update -y
	apt-get install -y --no-install-recommends spotify-client
}

install_steam() {
	dpkg --add-architecture i386
	apt-get update
	apt-get install -y \
			mesa-vulkan-drivers \
			libglx-mesa0:i386 \
			mesa-vulkan-drivers:i386 \
			libgl1-mesa-dri:i386 \
			steam-installer
}

install_traefik() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/traefik.service.notls /etc/systemd/system/traefik.service
	SERVICE_LIST+=( traefik )
}

install_vscodium() {
	curl -s https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor --yes -o /usr/share/keyrings/vscodium.gpg
	echo 'deb [signed-by=/usr/share/keyrings/vscodium.gpg arch=amd64] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs vscodium main' \
		> /etc/apt/sources.list.d/vscodium.list
	apt-get update -y
	apt-get install -y --no-install-recommends codium
}

install_zsh() {
	apt-get install -y --no-install-recommends zsh
}
