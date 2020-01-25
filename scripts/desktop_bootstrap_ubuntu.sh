#!/bin/bash

STORAGE_DIR='/mnt/storage'
NORDELLE_DIR='/mnt/nordelle'

cp -r robert/* ${HOME}/

# Other
apt-get update -y
apt-get install -y \
	software-properties-common \
	wget \
	unzip \
	keepass2 \
	vim \
	zsh \
	terminator

# Set up user account
git clone https://github.com/RJSzynal/dotfiles.git ~/development/github.com/rjszynal/dotfiles/
git clone https://github.com/RJSzynal/dockerfiles.git ~/development/github.com/rjszynal/dockerfiles/

# Install oh-my-zsh
curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh > oh-my-zsh_install.sh
RUNZSH=no sh oh-my-zsh_install.sh
rm -f oh-my-zsh_install.sh

# Configure zsh
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/UbuntuMono.zip > UbuntuMono.zip
mkdir -p ~/.local/share/fonts/NerdFonts
unzip UbuntuMono.zip -d ~/.local/share/fonts/NerdFonts/
rm -f UbuntuMono.zip
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
ln -sfn ~/{development/github.com/rjszynal/dotfiles/,}.zsh_theme
ln -sfn ~/{development/github.com/rjszynal/dotfiles/,}.dockerfunc
ln -sfn ~/{development/github.com/rjszynal/dotfiles/,}.mpd.conf
ln -sfn ~/{development/github.com/rjszynal/dotfiles/,}.exports
sed -i -e '/# DISABLE_UPDATE_PROMPT=/ s/^# //' \
        -e '/# COMPLETION_WAITING_DOTS=/ s/^# //' \
        -e '/^ZSH_THEME=/ s/^/# /' \
        -e '/# ZSH_THEME=/ a \
\
if [[ -r "${HOME}/.zsh_theme" ]] && [[ -f "${HOME}/.zsh_theme" ]]; then\
        source "${HOME}/.zsh_theme"\
else\
         ZSH_THEME="robbyrussell"\
fi' ~/.zshrc

# Autofs
apt-get install -y autofs
mkdir -p /etc/auto.master.d
echo "/mnt	/etc/auto.mnt" > /etc/auto.master.d/storage.autofs
echo "storage	 -rw,soft,intr,rsize=8192,wsize=8192 storage.szynal.co.uk:${STORAGE_DIR}" > /etc/auto.mnt
echo "torrent  -rw,soft,intr,rsize=8192,wsize=8192 storage.szynal.co.uk:${HOME}/torrent" >> /etc/auto.mnt
echo "nordelle -rw,soft,intr,rsize=8192,wsize=8192 nordelle.szynal.co.uk:${NORDELLE_DIR}" >> /etc/auto.mnt
cp autofs/.storage.creds /root/.storage.creds
service autofs start

# Docker
apt-get install -y \
	apt-transport-https \
	ca-certificates
wget -qO - https://download.docker.com/linux/debian/gpg | apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce
systemctl enable docker
systemctl start docker
usermod -aG docker ${USER}

#VSCodium
#wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | sudo apt-key add -
#echo 'deb https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/repos/debs/ vscodium main' > /etc/apt/sources.list.d/vscodium.list
#apt-get update -y
#apt-get install -y vscodium

# Google Drive
mkdir ${HOME}/googledrive-home
#mkdir ${HOME}/googledrive-work
chown ${USER}: ${HOME}/googledrive-home
#chown ${USER}: ${HOME}/googledrive-work

apt-get install -y \
	opam \
	ocaml \
	make \
	fuse \
	camlp4-extra \
	build-essential \
	pkg-config
groupadd fuse
usermod -aG fuse ${USER}
opam init
opam update
opam install depext
eval $(opam config env)
opam depext google-drive-ocamlfuse
opam install google-drive-ocamlfuse
. /root/.opam/opam-init/init.sh

google-drive-ocamlfuse ${HOME}/googledrive-home
#google-drive-ocamlfuse -label work ${HOME}/googledrive-work

echo 'mount | grep "${HOME}/googledrive-home" >/dev/null || /usr/bin/google-drive-ocamlfuse "${HOME}/googledrive-home"' >> ${HOME}/.profile
#echo 'mount | grep "${HOME}/googledrive-work" >/dev/null || /usr/bin/google-drive-ocamlfuse -label work "${HOME}/googledrive-work"' >> ${HOME}/.profile

# LMMS
wget https://github.com/LMMS/lmms/releases/download/v1.2.1/lmms-1.2.1-linux-x86_64.AppImage -o ~/Downloads/lmms.AppImage
cat > ~/lmms.sh <-"EOF"
#!/bin/bash

for directory in 'samples' 'soundfonts' 'lmms/projects'; do
	rsync -av --delete ${STORAGE_DIR}/music/${directory} ${HOME}/lmms/
done

QT_SCALE_FACTOR=1.2 ${HOME}/Downloads/lmms.AppImage

rsync -av --delete ${HOME}/lmms/projects ${STORAGE_DIR}/music/lmms/
for directory in 'samples' 'soundfonts'; do
	rsync -av --delete ${HOME}/lmms/${directory} ${STORAGE_DIR}/music/
done
EOF

