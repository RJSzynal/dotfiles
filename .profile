# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "/home/robert/.bashrc" ]; then
	. "/home/robert/.bashrc"
    fi
fi

# if running zsh
if [ -n "$ZSH_VERSION" ]; then
    # include .zshrc if it exists
    if [ -f "/home/robert/.zshrc" ]; then
	. "/home/robert/.zshrc"
    fi
fi

## Disable screen blanking/screensaver
command -v xset > /dev/null && {
	xset s off
	xset -dpms
	xset s noblank
}

## Containerised PulseAudio
#bash -c "source /home/robert/.dockerfunc; pulseaudio"
#export PULSE_SERVER=$(docker inspect --format '{{.NetworkSettings.Networks.trusted.IPAddress}}' pulseaudio)

## Video sync
(
	# Wait for the remote machine to be available
	until ping -c1 pi2.szynal.co.uk >/dev/null 2>&1
		do sleep 1
	done
	rsync -a --protect-args --prune-empty-dirs --include='*.mkv' --include='*.mp4' --exclude='*' pi2.szynal.co.uk:/home/pi/torrent/download/ /home/robert/Videos/
	rsync -a --protect-args --prune-empty-dirs --include='*.mkv' --include='*.mp4' --exclude='*' pi2.szynal.co.uk:/home/pi/torrent/download/*/ /home/robert/Videos/
) &

## Keepass
(
	# Wait for the internet connection to be operational
	until ping -c1 www.google.com >/dev/null 2>&1
		do sleep 1
	done
	mount | grep "/home/robert/googledrive-home" >/dev/null || /usr/bin/google-drive-ocamlfuse -o allow_root "/home/robert/googledrive-home"
	#mount | grep "/home/robert/googledrive-work" >/dev/null || /usr/bin/google-drive-ocamlfuse -label work "/home/robert/googledrive-work"

	# Wait for the google drive mount to be available
	until [ -f /home/robert/googledrive-home/backup/keepass/home.kdbx ]
		do sleep 1
	done
	/usr/bin/keepassxc &
) &

## Firefox
if [ "${XDG_CURRENT_DESKTOP}" != "i3" ]; then
	(
		# Wait for the internet connection to be operational
		until ping -c1 www.google.com >/dev/null 2>&1
			do sleep 1
		done
		firefox
	) &
fi

## Spotifyd
bash -c "source /home/robert/.dockerfunc; relies_on pulseaudio; spotifyd" &