#!/bin/bash

install_autofs() {
	dnf install -y autofs

	mkdir -p /etc/auto.master.d
	if [[ ! -f /root/.storage.creds ]]; then
		read -rp "Enter mount password: " mount_pass
		echo "user=administrator" > /root/.storage.creds
		echo "pass=${mount_pass}" >> /root/.storage.creds
	fi
	SERVICE_LIST+=( autofs )
}

install_docker_compose() {
	dnf install -y \
			dnf-plugins-core

	dnf config-manager addrepo --overwrite --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
	dnf install -y \
			docker-compose-plugin
	ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
}

install_terraform() {
	dnf install -y \
			dnf-plugins-core

	dnf config-manager addrepo --overwrite --from-repofile https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
	dnf install -y \
			terraform
}

install_vagrant() {
	dnf install -y \
			dnf-plugins-core

	dnf config-manager addrepo --overwrite --from-repofile https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
	dnf install -y \
			vagrant
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

install_dawn_of_the_tiberium_age() {
	local wineprefix=/home/${1}/Games/dawn-of-the-tiberium-age
	if [ ! -d "${wineprefix}" ]; then
		sudo -u ${1} mkdir  -p  $(dirname "${wineprefix}")
		sudo -u ${1} WINEARCH=win64 WINEPREFIX=${wineprefix} wineboot -u
	fi
	if [ ! -d "${wineprefix}/drive_c/Program Files/Dawn of the Tiberium Age" ]; then
		echo "You must manually download the file from the moddb website (https://www.moddb.com/mods/the-dawn-of-the-tiberium-age/downloads/dta135m). Type the location to continue. Leave blank to use default: /home/${1}/Downloads/DTA_13.5.3_Movies.zip"
		read -r archive_path
		archive_path=${archive_path:-/home/${1}/Downloads/DTA_13.5.3_Movies.zip}
		sudo -u ${1} unzip "${archive_path}" -d "${wineprefix}/drive_c/Program Files/"
	fi
	if [ ! -d "${wineprefix}/drive_c/Program Files (x86)/Microsoft.NET" ]; then
		sudo -u ${1} WINEPREFIX=${wineprefix} winetricks -q dotnet48
	fi
	cat > "/tmp/ddraw_override.reg" <<-EOF
	Windows Registry Editor Version 5.00
	
	[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
	"ddraw"="native,builtin"
	EOF
	sudo -u ${1} WINEPREFIX=${wineprefix} regedit /tmp/ddraw_override.reg
	rm /tmp/ddraw_override.reg

	# cat > "/tmp/dawn_of_the_tiberium_age.yaml" <<-EOF
	# name: Dawn of the Tiberium Age
	# game_slug: dawn-of-the-tiberium-age
	# launcher: wine
	# script:
	#   game:
	#     arch: win64
	#     exe: drive_c/Program Files/Files/Dawn of the Tiberium Age/DTA.exe
	#     prefix: ${wineprefix}
	#     working_dir: ${wineprefix}/drive_c/Program Files/Dawn of the Tiberium Age
	#   system:
	#     prefer_system_libs: true
	#   wine:
	#     battleye: false
	#     eac: false
	#     esync: false
	#     fsync: false
	#     version: ge-proton
	# EOF
	# sudo -u ${1} lutris --import /tmp/dawn_of_the_tiberium_age.yaml
	# rm /tmp/dawn_of_the_tiberium_age.yaml
}

install_tiberian_sun_client() {
	local wineprefix=/home/${1}/Games/tibsun-client

	if [ ! -d "${wineprefix}" ]; then
		sudo -u ${1} mkdir  -p  $(dirname "${wineprefix}")
		sudo -u ${1} WINEARCH=win64 WINEPREFIX=${wineprefix} wineboot -u
	fi

	if [ ! -d "${wineprefix}/drive_c/Program Files/cncnet-ts-client-package" ]; then
		sudo -u ${1} git clone git@github.com:CnCNet/cncnet-ts-client-package.git "${wineprefix}/drive_c/Program Files/cncnet-ts-client-package"
	fi

	if [ ! -d "${wineprefix}/drive_c/Program Files \(x86\)/Microsoft.NET" ]; then
		sudo -u ${1} WINEPREFIX=${wineprefix} winetricks -q dotnet48
	fi

	cat > "/tmp/ddraw_override.reg" <<-EOF
	[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
	"ddraw"="native,builtin"
	EOF
	sudo -u ${1} WINEPREFIX=${wineprefix} regedit /tmp/ddraw_override.reg
	rm /tmp/ddraw_override.reg

	cat > "/tmp/tiberian_sun_client.yaml" <<-EOF
	game:
	  arch: win64
	  exe: ${wineprefix}/drive_c/Program Files/cncnet-ts-client-package/TiberianSun.exe
	  prefix: ${wineprefix}
	  working_dir: ${wineprefix}/drive_c/Program Files/cncnet-ts-client-package
	system:
	  prefer_system_libs: true
	wine:
	  battleye: false
	  eac: false
	  esync: false
	  fsync: false
	  version: ge-proton
	EOF
	sudo -u ${1} lutris -i /tmp/tiberian_sun_client.yaml
	rm /tmp/tiberian_sun_client.yaml
}

install_tiberian_sun_twisted_insurrection() {
	local wineprefix=/home/${1}/Games/twisted-insurrection

	if [ ! -d "${wineprefix}" ]; then
		sudo -u ${1} mkdir -p $(dirname "${wineprefix}")
		sudo -u ${1} WINEARCH=win64 WINEPREFIX=${wineprefix} wineboot -u
	fi

	if [ ! -d "${wineprefix}/drive_c/Program Files/Twisted Insurrection" ]; then
		echo "You must manually download the file from the moddb website (https://www.moddb.com/mods/twisted-insurrection/downloads/twisted-insurrection-09-full-version) and place it in /tmp directory before continuing. Type the location to continue. Leave blank to use default: /home/${1}/Downloads/Twisted_Insurrection.zip"
		read -r archive_path
		archive_path=${archive_path:-/home/${1}/Downloads/Twisted_Insurrection.zip}
		sudo -u ${1} unzip "${archive_path}" -d "${wineprefix}/drive_c/Program Files/"
	fi

	cat > "/tmp/ddraw_override.reg" <<-EOF
	[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
	"ddraw"="native,builtin"
	EOF
	sudo -u ${1} WINEPREFIX=${wineprefix} regedit /tmp/ddraw_override.reg
	rm /tmp/ddraw_override.reg

	cat > "/tmp/twisted-insurrection.yaml" <<-EOF
	game:
	  arch: win64
	  exe: ${wineprefix}/drive_c/Program Files/Twisted Insurrection/TwistedInsurrection.exe
	  prefix: ${wineprefix}
	  working_dir: ${wineprefix}/drive_c/Program Files/Twisted Insurrection
	system:
	  prefer_system_libs: true
	wine:
	  battleye: false
	  eac: false
	  esync: false
	  fsync: false
	  version: ge-proton
	EOF
	sudo -u ${1} lutris -i /tmp/twisted-insurrection.yaml
	rm /tmp/twisted-insurrection.yaml
}

install_google_drive() {
	mkdir -p "/home/${1}/googledrive-home"
	chown "${1}": "/home/${1}/googledrive-home"

	if [ ! -d "/home/${1}/.gdfuse" ]; then
		rsync -av "${1}@nordelle.szynal.co.uk:/home/${1}/.gdfuse" "/home/${1}/.gdfuse"
	fi

	docker run -d \
		--name googledrive-home \
		--security-opt apparmor:unconfined \
		--cap-add mknod \
		--cap-add sys_admin \
		--device=/dev/fuse \
		-e MOUNT_OPTS="nonempty,allow_other" \
		-e PUID="$(id -u ${1})" \
		-e PGID="$(id -g ${1})" \
		-v /home/${1}/googledrive-home:/mnt/gdrive:shared \
		-v /home/${1}/.gdfuse/home:/config/.gdfuse/default:shared \
		maltokyo/docker-google-drive-ocamlfuse
}

install_keepassxc() {
	echo '==Installing KeepassXC=='
	temp_pkgs=()
	for pkg in gcc libstdc++-static kernel-headers systemd-libs libxkbcommon unzip; do
		if [ -z "$(dnf list installed | grep ${pkg})" ]; then
			temp_pkgs+=( ${pkg} )
		fi
	done
	dnf install -y \
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
	usermod -aG uinputg ${1}
	echo 'KERNEL=="uinput", GROUP="uinputg", MODE="0660", OPTIONS+="static_node=uinput"' > /etc/udev/rules.d/89-uinput-u.rules

	if [ "${#temp_pkgs[@]}" -gt 0 ]; then
		dnf remove -y ${temp_pkgs[@]}
	fi
}

install_oh_my_zsh() {
	dnf install -y zsh
	if [[ ! -d "/home/${1}/.oh-my-zsh" ]]; then
		sudo -u "${1}" sh -c "KEEP_ZSHRC=yes RUNZSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi
	# Install zsh theme
	if [[ ! -d "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
		sudo -u "${1}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${1}/.oh-my-zsh/custom/themes/powerlevel10k"
	fi
}

install_onedrive() {
	dnf copr -y enable jstaf/onedriver
	dnf install -y onedriver

	# Apparently the GUI is the easiest way to set up onedrive
	sudo -u "${1}" onedriver-launcher
}

install_traefik() {
	scp nordelle.szynal.co.uk:/mnt/nordelle/backup/services/traefik.service.notls /etc/systemd/system/traefik.service
	SERVICE_LIST+=( traefik )
}
