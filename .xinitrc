#!/bin/sh

## Disable screen blanking/screensaver
command -v xset > /dev/null && {
	xset s off
	xset s noblank
}

## Keepass
(
	# Give X time to set DPI
	sleep 1
	# Wait for the google drive mount to be available
	until [ -f /home/robert/googledrive-home/backup/keepass/home.kdbx ]
		do sleep 1
	done
	exec keepassxc
) &

## Firefox
(
	# Wait for the internet connection to be operational
	until ping -c1 google.com >/dev/null 2>&1
		do sleep 1
	done
	exec firefox
) &

if [ "${XDG_CURRENT_DESKTOP}" == "i3" ]; then
    feh --bg-fill ~/Pictures/Wallpapers/disney_me_lidia.jpg
fi

if [ "${DESKTOP_SESSION}" == "awesome" ]; then
	gnome-terminal
	i3lock -ui ~/Pictures/Wallpapers/Disney/disney-wooden-383301-dual.png
fi
