#!/bin/bash

install_awesome() {
	pacman --noconfirm -S \
		awesome \
		gnome-keyring \
		i3lock \
		maim \
		xclip \
		xorg
	SERVICE_LIST+=( i3lock@${1} )
}

install_autofs() {
	pacman --noconfirm -S autofs

	mkdir -p /etc/auto.master.d
	if [[ ! -f /root/.storage.creds ]]; then
		read -rp "Enter mount password: " mount_pass
		echo "user=administrator" > /root/.storage.creds
		echo "pass=${mount_pass}" >> /root/.storage.creds
	fi
	SERVICE_LIST+=( autofs )
}

install_docker() {
	# Enable buildkit
	if [ -f /etc/docker/daemon.json ]; then
		cat /etc/docker/daemon.json | jq '.features.buildkit = true' > /etc/docker/daemon.json.tmp && mv /etc/docker/daemon.json{.tmp,}
	else
		jq --null-input '.features.buildkit = true' > /etc/docker/daemon.json
	fi
	# [ -z "$(uname -a | grep -i 'wsl')" ] || update-alternatives --set iptables /usr/sbin/iptables-legacy

	# Install Docker
	pacman --noconfirm -S \
			docker \
			docker-buildx
	usermod -aG docker "${1}"
	SERVICE_LIST+=( docker.socket )

	# Created "trusted" user-defined bridge network
	docker network create trusted

	# # Run the Docker daemon as a non-root user
	# if [ -z "$(uname -a | grep -i 'wsl')" ]; then
	# 	systemctl disable --now docker.service docker.socket
	# 	rm /var/run/docker.sock || true
	# 	apt-get install -y \
	# 			dbus-user-session \
	# 			docker-ce-rootless-extras \
	# 			slirp4netns \
	# 			uidmap \
	# 		--no-install-recommends
	# 	sudo -u ${1} dockerd-rootless-setuptool.sh install
	# fi
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

install_gnome() {
	pacman -Sgq gnome \
	| grep -v \
		epiphany \
		gnome-contacts \
		gnome-music \
		gnome-remote-desktop \
		gnome-weather \
	| pacman --noconfirm -S -

	pacman --noconfirm -S \
		spectacle
}

install_google_drive() {
	mkdir -p "/home/${1}/googledrive-home"
	chown "${1}": "/home/${1}/googledrive-home"
	# mkdir -p "/home/${1}/googledrive-work"
	# chown "${1}": "/home/${1}/googledrive-work"

	aur_install google-drive-ocamlfuse

	rsync -av "${1}@nordelle.szynal.co.uk:/home/${1}/.gdfuse" "/home/${1}/.gdfuse"

	/usr/bin/google-drive-ocamlfuse -o allow_root -label home "/home/${1}/googledrive-home"
	# /usr/bin/google-drive-ocamlfuse -o allow_root -label work "/home/${1}/googledrive-work"
}

install_i3() {
	pacman --noconfirm -S \
		feh \
		i3-wm \
		i3lock \
		maim \
		xclip
	SERVICE_LIST+=( i3lock@${1} )
}

install_kde() {
	pacman -Sgq plasma \
	| grep -v \
		plasma-welcome \
	| pacman --noconfirm -S -

	pacman --noconfirm -S \
		spectacle
}

install_keepassxc() {
	temp_pkgs=()
	for pkg in gcc linux-headers libsystemd libxkbcommon; do
		if [ -z "$(pacman -Q | grep ${pkg})" ]; then
			temp_pkgs+=( ${pkg} )
	done
	pacman --noconfirm -S \
			keepassxc \
			mono-tools \
			${temp_pkgs}

	TMP_DIR=$(mktemp -d)
	wget https://keepass.info/extensions/v2/kpuinput/KPUInput-1.4.zip -qO ${TMP_DIR}/kpuinput.zip
	unzip ${TMP_DIR}/kpuinput.zip -d "${TMP_DIR}"
	chmod +x ${TMP_DIR}/KPUInputN.sh
	(cd ${TMP_DIR}; ./KPUInputN.sh)
	mv ${TMP_DIR}/KPUInput{.*,N.so} /usr/lib/keepassxc/
	cp -f /usr/lib/{keepassxc/,}KPUInputN.so
	rm -rf ${TMP_DIR}

	groupadd uinputg
	usermod -a -G uinputg ${TARGET_USER}
	echo 'KERNEL=="uinput", GROUP="uinputg", MODE="0660", OPTIONS+="static_node=uinput"' > /etc/udev/rules.d/89-uinput-u.rules

	pacman --noconfirm -R ${temp_pkgs}
}

install_lmms() {
	pacman --noconfirm -R lmms

	cat > "/home/${1}/lmms.sh" <<-EOF
		#!/bin/bash

		for directory in 'samples' 'soundfonts' 'lmms/projects'; do
			rsync -av --delete ${2}/music/\${directory} \/home/${1}/lmms/
		done

		QT_SCALE_FACTOR=1.2 /usr/bin/lmms

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

install_steam() {
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	pacman -Syu \
		lib32-mesa \
		lib32-vulkan-radeon \
		steam
}

install_traefik() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/traefik.service.notls /etc/systemd/system/traefik.service
	SERVICE_LIST+=( traefik )
}

install_vscodium() {
	aur_install vscodium
}

aur_install() {
	(
		cd /tmp
		git clone https://aur.archlinux.org/${1}.git
		cd ${1}
		makepkg -si
	)
	rm -rf /tmp/${1}
}

install_zsh() {
	pacman --noconfirm -S zsh
}
