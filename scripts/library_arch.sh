#!/bin/bash

install_awesome() {
	yay --needed --noconfirm -S \
		awesome \
		gnome-keyring \
		i3lock \
		maim \
		xclip \
		xorg
	SERVICE_LIST+=( i3lock@${1} )
}

install_autofs() {
	sudo -u ${1} yay --needed --noconfirm -S autofs

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
		mkdir -p /etc/docker
		jq --null-input '.features.buildkit = true' > /etc/docker/daemon.json
	fi
	# [ -z "$(uname -a | grep -i 'wsl')" ] || update-alternatives --set iptables /usr/sbin/iptables-legacy

	# Install Docker
	yay --needed --noconfirm -S \
			docker \
			docker-buildx
	usermod -aG docker "${1}"
	systemctl start docker.socket
	SERVICE_LIST+=( docker.socket )

	# Created "trusted" user-defined bridge network
	docker network create trusted || true

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
	| grep -Ev \
		'(epiphany|gnome-contacts|gnome-music|gnome-remote-desktop|gnome-weather)' \
	| yay --needed --noconfirm -S -
	
	yay --needed --noconfirm -S \
		gnome-tweaks \
		spectacle

	# Set Windows style buttons
	gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
	# Allow fractional scaling
	gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
	# Extend "not responding" timeout to 10 seconds
	gsettings set org.gnome.mutter check-alive-timeout 15000
	# Can't do the following as it just makes poweroff do nothing at all
	#gsettings set org.gnome.SessionManager logout-prompt false
}

install_google_drive() {
	mkdir -p "/home/${1}/googledrive-home"
	chown "${1}": "/home/${1}/googledrive-home"
	# mkdir -p "/home/${1}/googledrive-work"
	# chown "${1}": "/home/${1}/googledrive-work"

	sudo -u ${1} yay --needed --noconfirm -S google-drive-ocamlfuse

	if [ ! -d "/home/${1}/.gdfuse" ]; then
		rsync -av "${1}@nordelle.szynal.co.uk:/home/${1}/.gdfuse" "/home/${1}/.gdfuse"
	fi

	/usr/bin/google-drive-ocamlfuse -o allow_root -label home "/home/${1}/googledrive-home"
	# /usr/bin/google-drive-ocamlfuse -o allow_root -label work "/home/${1}/googledrive-work"
}

install_i3() {
	yay --needed --noconfirm -S \
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
	| yay --needed --noconfirm -S -

	yay --needed --noconfirm -S \
		spectacle
}

install_keepassxc() {
	echo '==Installing KeepassXC=='
	temp_pkgs=()
	for pkg in gcc linux-headers systemd-libs libxkbcommon unzip; do
		if [ -z "$(pacman -Q | grep ${pkg})" ]; then
			temp_pkgs+=( ${pkg} )
		fi
	done
	yay --needed --noconfirm -S \
			keepassxc \
			mono-tools \
			${temp_pkgs[@]}

	TMP_DIR=$(mktemp -d)
	wget https://keepass.info/extensions/v2/kpuinput/KPUInput-1.4.zip -qO ${TMP_DIR}/kpuinput.zip
	unzip ${TMP_DIR}/kpuinput.zip -d "${TMP_DIR}"
	chmod +x ${TMP_DIR}/KPUInputN.sh
	(cd ${TMP_DIR}; ./KPUInputN.sh)
	mv ${TMP_DIR}/KPUInput{.*,N.so} /usr/lib/keepassxc/
	cp -f /usr/lib/{keepassxc/,}KPUInputN.so
	rm -rf ${TMP_DIR}

	getent group uinputg || groupadd uinputg
	usermod -aG uinputg ${TARGET_USER}
	echo 'KERNEL=="uinput", GROUP="uinputg", MODE="0660", OPTIONS+="static_node=uinput"' > /etc/udev/rules.d/89-uinput-u.rules

	if [ "${#temp_pkgs[@]}" -gt 0 ]; then
		yay --noconfirm -R ${temp_pkgs[@]}
	fi
}

install_lmms() {
	echo '==Installing LMMS=='
	yay --noconfirm -S lmms

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
	yay --needed --noconfirm -S zsh
	if [[ ! -d "/home/${1}/.oh-my-zsh" ]]; then
		sudo -u "${1}" sh -c "KEEP_ZSHRC=yes RUNZSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi
	# Install zsh theme
	if [[ ! -d "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
		sudo -u "${1}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k"
	fi
}

install_steam() {
	echo '==Installing Steam=='
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	yay --needed --noconfirm -Syu \
		lib32-mesa \
		lib32-vulkan-radeon \
		steam
}

install_traefik() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/traefik.service.notls /etc/systemd/system/traefik.service
	SERVICE_LIST+=( traefik )
}

aur_install() {
	rm -rf /tmp/${1}
	(
		cd /tmp
		sudo -u "${2}" git clone https://aur.archlinux.org/${1}.git
		cd ${1}
		sudo -u "${2}" makepkg -si
	)
	rm -rf /tmp/${1}
}
