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

## Video sync
(
	# Wait for the remote machine to be available
	#until ping -c1 pi4.szynal.co.uk >/dev/null 2>&1
	until ping -c1 nordelle.szynal.co.uk >/dev/null 2>&1
		do sleep 1
	done
	rsync -a --protect-args --prune-empty-dirs --include='*.mkv' --include='*.mp4' --exclude='*' nordelle.szynal.co.uk:/home/robert/torrent/download/ /home/robert/Videos/
	rsync -a --protect-args --prune-empty-dirs --include='*.mkv' --include='*.mp4' --exclude='*' nordelle.szynal.co.uk:/home/robert/torrent/download/*/ /home/robert/Videos/
	#rsync -a --protect-args --prune-empty-dirs --include='*.mkv' --include='*.mp4' --exclude='*' pi4.szynal.co.uk:/home/pi/torrent/download/ /home/robert/Videos/
	#rsync -a --protect-args --prune-empty-dirs --include='*.mkv' --include='*.mp4' --exclude='*' pi4.szynal.co.uk:/home/pi/torrent/download/*/ /home/robert/Videos/
) &

## Spotifyd
# dockerfunc spotifyd
