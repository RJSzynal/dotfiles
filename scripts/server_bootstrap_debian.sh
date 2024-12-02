#!/bin/bash

if [ "${EUID}" -ne 0 ]; then
    echo 'Please run as root'
    exit
fi

export DEBIAN_FRONTEND=noninteractive

# Choose a user account to use for this installation
if [ -z "${TARGET_USER}" ]; then
	mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
	# if there is only one option just use that user
	if [ "${#options[@]}" -eq "1" ]; then
		TARGET_USER="${options[0]}"
		echo "Using user account: ${TARGET_USER}"
	else
		# iterate through the user options and print them
		PS3='Which user account should be used? '

		select opt in "${options[@]}"; do
			TARGET_USER=$opt
			break
		done
	fi
fi

PUBLIC_KEY='ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAqcpCNp9MEYa+Sd5qr/c93uvV0sxqo78bm177itA7HdIUFi5IFSznQcQUAxllR3jS5r+/AJ5JVB0fP4yKDLjKnTRK4ShCWSHyg2XuVJPIfbpXYnnMhgF4ZbQKWbxTWKXWJz+6BH94i6R2+M3qXCOYx/imeiseMpa5hWY98y6I70DihiF+UaY7t07EYK6SagyYqXjBro7fUJsO11KhX3wo2nUNlwYHM/0AufxsibbWiXaz4oAjw1IUPMNTAaAUlhfiDV1zFKmqfppxDYqQkYVBv6MeHzR5O+XSU8ikUHPq21eJ9fEFQhO+fzZkuOJHBu0o6Q9eSqxk3w08QcRVq6BcYQ== Personal'
EMAIL='robert@szynal.co.uk'
nightly_backup_cmd=('#!/bin/sh')

## SSH access
runuser -u ${TARGET_USER} mkdir -p /home/${TARGET_USER}/.ssh
chmod 700 /home/${TARGET_USER}/.ssh
echo "${PUBLIC_KEY}" >> /home/${TARGET_USER}/.ssh/authorized_keys
chown "${TARGET_USER}": /home/${TARGET_USER}/.ssh/authorized_keys
chmod 600 /home/${TARGET_USER}/.ssh/authorized_keys

## Ensure everything is up to date and install some general packages
apt-config dump | grep -we Recommends -e Suggests | sed s/1/0/ > /etc/apt/apt.conf.d/99norecommend
cat > /etc/apt/sources.list <<-SOURCES
	deb http://deb.debian.org/debian bookworm main contrib
	deb http://deb.debian.org/debian bookworm-updates main contrib
	deb http://deb.debian.org/debian-security/ bookworm-security main contrib
	deb http://deb.debian.org/debian bookworm-backports main contrib
SOURCES
apt-get update
apt-get full-upgrade --autoremove -y
apt-get install -y \
	apt-transport-https \
	ca-certificates \
	curl \
	dnsutils \
	firewalld \
	git \
	jq \
	lsof \
	make \
	neovim \
	rsync \
	silversearcher-ag \
	ssh \
	systemd-sysv \
	telnet \
	tig \
	time \
	unar \
	unzip \
	wget

# Only keep 2 kernels
# sudo sed -i '/^installonly_limit=/ s/5/2/' /etc/yum.conf

## Set up user account
# Set up dev repos
runuser -u ${TARGET_USER} git config --global pull.ff only
for repo in dotfiles dockerfiles; do
	if [[ ! -d "/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}" ]]; then
		runuser -u ${TARGET_USER} mkdir -p "/home/${TARGET_USER}/development/src/github.com/rjszynal/"
		runuser -u ${TARGET_USER} git clone git@github.com:RJSzynal/${repo}.git "/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/"
	fi
	if ! git --git-dir="/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/.git" remote -v | grep bitbucket; then
		git --git-dir="/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/.git" remote set-url --add --push origin git@bitbucket.org:RJSzynal/${repo}.git
		git --git-dir="/home/${TARGET_USER}/development/src/github.com/rjszynal/${repo}/.git" remote set-url --add --push origin git@github.com:RJSzynal/${repo}.git
	fi
done
(crontab -l -u ${TARGET_USER}; echo "0 4 * * * git --git-dir=/home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles/.git --work-tree=/home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles pull") | crontab -u ${TARGET_USER} -
(crontab -l -u ${TARGET_USER}; echo "0 4 * * Mon bash -c 'cd /home/${TARGET_USER}/development/src/github.com/rjszynal/dockerfiles && git pull && make'") | crontab -u ${TARGET_USER} -
runuser -u ${TARGET_USER} ln -sfn /home/${TARGET_USER}/{development/src/github.com/rjszynal/dotfiles/,}.dockerfunc
runuser -u ${TARGET_USER} ln -sfn /home/${TARGET_USER}/{development/src/github.com/rjszynal/dotfiles/,}.exports
runuser -u ${TARGET_USER} ln -sfn /home/${TARGET_USER}/{development/src/github.com/rjszynal/dotfiles/,}.aliases

source /home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles/scripts/library_debian.sh

cat >> /home/${TARGET_USER}/.bashrc <<-BASHRC
	for file in /home/${TARGET_USER}/.{bash_prompt,aliases,functions,path,dockerfunc,extra,exports}; do
	    if [[ -r "\${file}" ]] && [[ -f "\${file}" ]]; then
	        # shellcheck source=/dev/null
	        source "\${file}"
	    fi
	done
	unset file
BASHRC

# # Set up apt-cron
# sudo sed -i -e '/^apply_updates =/ s/no/yes/' \
# 	-e "/^email_to =/ s/root/${EMAIL}/" \
# 	-e '/^emit_via =/ s/stdio/email/' /etc/apt/apt-cron.conf
# sudo systemctl restart apt-cron
# sudo systemctl enable apt-cron

read -rn1 -p "Is this server running disk services? Y/n: " disk_services
if [ "${disk_services}" = "Y" ] || [ "${disk_services}" = "y" ] ; then
	## ZFS set up
	# Install
	cat > /etc/apt/preferences.d/90_zfs <<-PREFERENCE
		Package: src:zfs-linux
		Pin: release n=bookworm-backports
		Pin-Priority: 990
	PREFERENCE
	apt update
	apt install -y \
		linux-headers-$(dpkg --print-architecture) \
		hdparm
	apt install -t $(lsb_release -cs)-backports -y \
		zfs-dkms \
		zfsutils-linux
	systemctl enable zfs.target

	# ZFS Creation
	read -rp 'What is the server name? (for naming the file share): ' share_name
	lsblk
	read -rp "Which devices should be in the raid? e.g. $(lsblk | grep 2.7T | grep disk | cut -d' ' -f1 | paste -sd ' ' -): " -a raid_drives
	zpool import "${share_name}" || zpool create -f "${share_name}" mirror "${raid_drives[@]}"
	read -rp "Where should the share be mounted locally? e.g. /mnt/${share_name}: " share_mount_dir
	zfs set mountpoint="${share_mount_dir}" "${share_name}"
	zfs set nbmand=on "${share_name}"

	## Set up smartd
	sed -i '/^DEVICESCAN/ s/^/#/' /etc/smartd.conf
	echo "DEVICESCAN -H -m ${EMAIL} -M test -M diminishing -M exec /usr/libexec/smartmontools/smartdnotify -n standby,48,q" >> /etc/smartd.conf
	systemctl enable smartd
	systemctl start smartd

	## Healthchecks
	cat > /root/zfs_check.sh <<-SCRIPT
		#!/bin/sh

		emailto="${EMAIL}"
		msgsubj="Filesystem issues on \$(hostname)"

		# Check zpool status
		pools=( \$( /usr/sbin/zpool list -H -o name ) )
		for pool in \${pools}
		do
		    pool_status=\$( /usr/sbin/zpool list -H -o health \${pool} )
		    if [ "\${pool_status}" != "ONLINE" ]; then
		        echo "Problems with ZFS \$( /usr/sbin/zpool status \${pool} )" | mail -s "\${msgsubj}" \${emailto}
		    fi
		done

		exit 0
	SCRIPT
	chmod +x /root/zfs_check.sh
	(crontab -l ; echo "*/15 * * * * /root/zfs_check.sh") | crontab -
	(crontab -l ; echo "0 5 1 * * /usr/sbin/zpool scrub nordelle") | crontab -
	
	## Reduce time spent spun up
	cat > /root/set_disk_spindown.sh <<-"SCRIPT"
		#!/bin/bash

		# This value will spin down the ZFS share disks after the following times:
		# 60 = 5 minutes
		# 120 = 10 minutes
		# 180 = 15 minutes
		# 241 = 30 minutes
		# 242 = 1 hour
		# 243 = 1.5 hours
		# 244 = 2 hours
		SPINDOWN_IDLE_TIME=60
		APM_LEVEL=255
		drives=($(lsblk | grep 2.7T | grep disk | cut -d' ' -f1 | paste -sd ' ' -))

		for drive in "${drives[@]}"; do
		  ( /usr/sbin/hdparm -S ${SPINDOWN_IDLE_TIME} /dev/${drive}
		    /usr/sbin/hdparm -B ${APM_LEVEL} /dev/${drive}
		    /usr/sbin/hdparm -y /dev/${drive} ) &
		done
		wait
	SCRIPT
	chmod +x /root/set_disk_spindown.sh


	## Set up the NFS share
	apt-get install -y \
		nfs-kernel-server \
		rpcbind
	echo "${share_mount_dir} *(rw,sync,no_root_squash,fsid=0)" >> /etc/exports
	groupadd storage-share-rw
	chown ${TARGET_USER}:storage-share-rw "${share_mount_dir}"
	chmod 755 "${share_mount_dir}"
	systemctl enable rpcbind
	systemctl enable nfs-server
	# systemctl enable nfs-lock
	# systemctl enable nfs-idmap
	firewall-cmd --permanent --zone=public --add-service={nfs,mountd,rpc-bind}
	firewall-cmd --reload
	systemctl start rpcbind
	systemctl start nfs-server
	
	
	## Set up the SMB share
	apt-get install -y samba
	cat > /etc/samba/smb.conf <<-SAMBA
		[global]
		    workgroup = WORKGROUP
		    server string = Samba Server %v
		    netbios name = $(hostname -s)
		    server signing = auto
		    security = user
		    passdb backend = tdbsam
		    username map = /etc/samba/smbusers
		[${share_name}]
		    path = ${share_mount_dir}
		    valid users = @storage-share-rw
		    browsable = yes
		    writable = yes
		    guest ok = no
		    read only = no
	SAMBA
	cat > /etc/samba/smbusers <<-SAMBAUSERS
		root = root administrator Administrator
		${TARGET_USER} = ${TARGET_USER}
	SAMBAUSERS
	echo "Please set the password for connecting to the samba shares as root"
	smbpasswd -a root
	echo "Please set the password for connecting to the samba shares as ${TARGET_USER}"
	smbpasswd -a  ${TARGET_USER}
	chcon -t samba_share_t "${share_mount_dir}"
	usermod -aG storage-share-rw root
	usermod -aG storage-share-rw "${TARGET_USER}"
	systemctl enable smbd
	firewall-cmd --permanent --zone=public --add-service=samba
	firewall-cmd --reload
	systemctl start smbd
fi


## Mount remote shares
read -rp 'What is the remote share host name? e.g. stoneholme.szynal.co.uk: ' remote_hostname
read -rp 'What is the remote share location? e.g. /mnt/stoneholme: ' remote_share_dir
read -rp "Where should the remote share be mounted locally? e.g. ${remote_share_dir}: " remote_share_local_mount_dir
#mkdir -p ${remote_share_local_mount_dir}
#echo "${remote_hostname}:${remote_share_dir}    ${remote_share_local_mount_dir}   nfs    defaults,noauto 0 0" >> /etc/fstab
#mount ${remote_share_local_mount_dir}


## Keep the domain IP address updated in godaddy nameservers
cat > /usr/bin/cloudflare-ddns-updater <<-"SCRIPT"
	#!/bin/bash

	# Modified to use Cloudflare instead by RJSzynal
	# GoDaddy.sh v1.3 by Nazar78 @ TeaNazaR.com
	###########################################
	# Simple DDNS script to update Cloudflare's DNS. Just schedule every 5mins in crontab.
	# With options to run scripts/programs/commands on update failure/success.
	#
	# Requirements:
	# - curl CLI - On Debian, apt-get install curl
	#
	# History:
	# v1.0 - 20160513 - 1st release.
	# v1.1 - 20170130 - Improved compatibility.
	# v1.2 - 20180416 - GoDaddy API changes - thanks Timson from Russia for notifying.
	# v1.3 - 20180419 - GoDaddy API changes - thanks Rene from Mexico for notifying.
	# v2.0 - 20241202 - Re-write to use Cloudflare - RJSzynal
	#
	# PS: Feel free to distribute but kindly retain the credits (-:
	###########################################

	if [ $# -lt 2 ] || [ $# -gt 5 ]
	then
	  echo "Usage: $0 credentials domain [sub-domain] [ttl] [record_type]"
	  echo "  credentials: Cloudflare API token with DNS:Edit permmission or"
	  echo "               location of file containing that value on the first line"
	  echo "  domain: The domain you're setting. e.g. mydomain.com"
	  echo "  sub-domain: Record name, as seen in the DNS setup page. Default: @ (apex domain)"
	  echo "  ttl: Time To Live in seconds. Default: 300 (5 minutes)"
	  echo "  record_type: Record type, as seen in the DNS setup page. Default: A"
	  exit 1
	fi

	## Set and validate the variables
	# Get the API token from https://dash.cloudflare.com/profile/api-tokens.
	# Ensure it has "Zone:DNS:Edit" and "Zone:Zone:Read" permissions.
	if [ -z "${1}" ]
	then
	  echo "Error: Requires API token value. Can be a file location containing the value."
	  exit 1
	else
	  if [ -f "${1}" ]
	  then
	      Token=$(head -n 1 ${1})
	  else
	      Token=${1}
	  fi
	fi
	if [ -z "${Token}" ] # Check this again in case the file had a blank line
	then
	  echo "Error: Requires API token value. Can be a file location containing the value."
	  exit 1
	fi

	# Domain to update.
	if [ -z "${2}" ]
	then
	  echo "Error: Requires 'Domain' value."
	  exit 1
	else
	  Domain=${2}
	fi

	# Advanced settings - change only if you know what you're doing :-)
	# Record name, as seen in the DNS setup page, default @.
	Name=${3-@}
	[ -z "${Name}" ] && Name=@ # To catch any bad value passed in as an argument

	# Time To Live in seconds, minimum 60 (1min), default 300 (5mins).
	# If your public IP regularly changes, set it to 60 (1min).
	TTL=${4-300}
	[ -z "${TTL}" ] && TTL=300
	[ "${TTL}" -lt 60 ] && TTL=60 # 60 is the minimum

	# Record type, as seen in the DNS setup page, default A.
	Type=${5-A}
	[ -z "${Type}" ] && Type=A

	# Writable path to last known Public IP record cached. Best to place in tmpfs.
	CacheFilename=${Domain}_${Type}_${Name}
	# This cleans up any illegal characters e.g. When setting the * record
	CachedIPFile=/tmp/${CacheFilename//[*\/]/_}
	echo -n>>${CachedIPFile} 2>/dev/null
	if [ $? -ne 0 ]
	then
	  echo "Error: Can't write to ${CachedIPFile}."
	  exit 1
	fi

	# External URL to check for current Public IP, must contain only a single plain text IP.
	# Default http://api.ipify.org.
	CheckURL=http://api.ipify.org

	# Optional scripts/programs/commands to execute on successful update. Leave blank to disable.
	# This variable will be evaluated at runtime but will not be parsed for errors nor execution guaranteed.
	# Take note of the single quotes. If it's a script, ensure it's executable i.e. chmod 755 ./script.
	# Example: SuccessExec='/bin/echo "$(date): My public IP changed to ${PublicIP}!">>/var/log/GoDaddy.sh.log'
	SuccessExec=''

	# Optional scripts/programs/commands to execute on update failure. Leave blank to disable.
	# This variable will be evaluated at runtime but will not be parsed for errors nor execution guaranteed.
	# Take note of the single quotes. If it's a script, ensure it's executable i.e. chmod 755 ./script.
	# Example: FailedExec='/some/path/something-went-wrong.sh ${Update} && /some/path/email-script.sh ${PublicIP}'
	FailedExec='/bin/echo "Fail!\nDomain: ${Domain}\nRecord: ${Name}\nType: ${Type}\nIP: ${PublicIP}\nERROR:${ErrorMsg}" | mail -s "DNS update failed" rjszynal@gmail.com'
	# End settings

	# Find the locally installed curl to use
	Curl=$(/usr/bin/which curl 2>/dev/null)
	if [ "${Curl}" = "" ]
	then
	  echo "Error: Unable to find 'curl CLI'."
	  exit 1
	fi


	## Get the current public IP
	echo -n "Checking current 'Public IP' from '${CheckURL}'..."
	# Get current public IP
	PublicIP=$(${Curl} -kLs ${CheckURL})
	if [ $? -eq 0 ] && [[ "${PublicIP}" =~ [0-9]{1,3}\.[0-9]{1,3} ]]
	then
	  echo "${PublicIP}"
	else
	  ErrorMsg="Failed to check current public IP.\nResponse: ${PublicIP}"
	  echo "${ErrorMsg}"
	  eval ${FailedExec}
	  exit 1
	fi


	## Compare the current public IP to the cached IP from the last run
	if [ "$(cat ${CachedIPFile} 2>/dev/null)" = "${PublicIP}" ]
	then
	  echo "Current 'Public IP' matches 'Cached IP' recorded. No update required!"
	  exit 0
	fi


	## Get the currently set IP from the Cloudflare record
	echo -n "Checking '${Domain}' IP records from 'Cloudflare'..."

	response=$(${Curl} -Ls \
	    -X GET \
	    -H "Authorization: Bearer ${Token}" \
	    -H "Content-type: application/json" \
	    https://api.cloudflare.com/client/v4/zones)
	if [ "$(echo ${response} | jq '.success' -r)" != "true" ]; then
	    ErrorMsg="Error getting Zone ID\n${response}"
		echo "Failed!\n${ErrorMsg}"
		eval ${failedExec}
	    exit 1
	fi
	ZoneID=$(echo ${response} | jq ".result[] | select(.name==\"${Domain}\") | .id" -r)
	RecordName="${Name}.${Domain}"
	if [ "${Name}" = "@" ]; then 
		RecordName="${Domain}"
	fi
	response=$(${Curl} -Ls \
	    -X GET \
	    -H "Authorization: Bearer ${Token}" \
	    -H "Content-type: application/json" \
	    https://api.cloudflare.com/client/v4/zones/${ZoneID}/dns_records)
	if [ "$(echo ${response} | jq '.success' -r)" != "true" ]; then
	    ErrorMsg="Error getting Record ID\n${response}"
		echo "Failed!\n${ErrorMsg}"
		eval ${failedExec}
	    exit 1
	fi
	RecordID=$(echo ${response} | jq ".result[] | select(.type==\"${Type}\" and .name==\"${RecordName}\") | .id" -r)
	if [ -z "${RecordID}" ]; then
	    ErrorMsg="Error getting Record ID. Record doesn't exist.\n${response}"
	    printf "${ErrorMsg}"
	    eval ${failedExec}
	    exit 1
	fi
	response=$(${Curl} -Ls \
	    -X GET \
	    -H "Authorization: Bearer ${Token}" \
	    -H "Content-type: application/json" \
	    https://api.cloudflare.com/client/v4/zones/${ZoneID}/dns_records/${RecordID})
	if [ "$(echo ${response} | jq '.success' -r)" != "true" ]; then
	    ErrorMsg="Error getting current IP\n${response}"
		echo "Failed!\n${ErrorMsg}"
		eval ${failedExec}
	    exit 1
	fi
	CurrentCFIP=$(echo ${response} | jq ".result.content" -r )


	## Compare the current public IP to the Cloudflare record
	if [ $? -eq 0 ] && [ "${CurrentCFIP}" = "${PublicIP}" ]
	then
	  echo -n "${CurrentCFIP}" > ${CachedIPFile} # Record the current public IP in the cache file
	  echo "unchanged"
	  echo "Current 'Public IP' matches 'Cloudflare' records. No update required."
	  exit 0
	fi


	## Update the Cloudflare record with the current IP
	echo "changed"
	echo -n "Updating '${Domain}'..."

	response=$(${Curl} -kLs \
	    -X PATCH \
	    -H "Authorization: Bearer ${Token}" \
	    -H "Content-type: application/json" \
	    https://api.cloudflare.com/client/v4/zones/${ZoneID}/dns_records/${RecordID} \
	    -d "{\"comment\": \"Managed by ${0}\",\"name\": \"${RecordName}\",\"ttl\": ${TTL},\"content\": \"${PublicIP}\",\"type\": \"${Type}\"}")
	if [ "$(echo ${response} | jq '.success' -r)" != "true" ]; then
	    ErrorMsg="Error setting new IP\n${response}"
		printf "Failed!\n${ErrorMsg}"
		eval ${failedExec}
	    exit 1
	fi
	Update=$(echo ${response} | jq ".result" -r )

	echo -n "${PublicIP}" > ${CachedIPFile} # Record the current public IP in the cache file
	echo "Success"
	eval ${SuccessExec}
	exit 0
SCRIPT
chmod +x /usr/bin/cloudflare-ddns-updater
read -rp "What is the domain name to update with Cloudflare? stoneholme.szynal.co.uk: " web_domain
(crontab -l ; echo "*/5 * * * * /usr/bin/cloudflare-ddns-updater /home/${TARGET_USER}/torrent/configs/cloudflare/.dns_api_token szynal.co.uk ${web_domain%.szynal.co.uk} > /dev/null") | crontab -
read -rp "Is this the root domain?: " is_root_domain
if [ "${is_root_domain}" = "Y" ] || [ "${is_root_domain}" = "y" ]; then
	(crontab -l ; echo "*/5 * * * * /usr/bin/cloudflare-ddns-updater /home/${TARGET_USER}/torrent/configs/cloudflare/.dns_api_token szynal.co.uk '@' > /dev/null") | crontab -
	(crontab -l ; echo "*/5 * * * * /usr/bin/cloudflare-ddns-updater /home/${TARGET_USER}/torrent/configs/cloudflare/.dns_api_token szynal.co.uk '*' > /dev/null") | crontab -
fi

# Install Docker
install_docker "${TARGET_USER}"
docker login


services_location="/home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles/scripts/services"
## Traefik set up
cp "${services_location}/traefik.service" /etc/systemd/system/
mkdir /root/.traefik
cp "${services_location}/traefik/traefik.yml" /root/.traefik/
cp "${services_location}/traefik/middlewares.yml" /root/.traefik/
cp "${services_location}/traefik/dashboard.yml" /root/.traefik/
systemctl enable traefik
systemctl start traefik

## Omada service set up
read -rn1 -p "Is this server running the omada controller service? Y/n: " omada_services
if [ "${omada_services}" = "Y" ] || [ "${omada_services}" = "y" ] ; then
	# Start the Omada Controller
	cp "${services_location}/omada.service" /etc/systemd/system/
	systemctl enable omada
	systemctl start omada

	firewall-cmd --permanent --zone=public \
		--add-port={8088,8043,8843,29811,29812,29813,29814}/tcp \
		--add-port={27001,29810}/udp
	firewall-cmd --reload
fi

## Web services set up
read -rn1 -p "Is this server running the web services? Y/n: " web_services
if [ "${web_services}" = "Y" ] || [ "${web_services}" = "y" ] ; then
	# Start the CV page
	cp "${services_location}/cv.service" /etc/systemd/system/
	systemctl enable cv
	systemctl start cv

	# Start the web experiments site
	cp "${services_location}/web.service" /etc/systemd/system/
	systemctl enable web
	systemctl start web

	firewall-cmd --permanent --zone=public --add-port=60443/tcp
	firewall-cmd --reload
fi

## Torrent services set up
read -rn1 -p "Is this server running the torrent services? Y/n: " torrent_services
if [ "${torrent_services}" = "Y" ] || [ "${torrent_services}" = "y" ] ; then
	# Add the torrent service
	apt install -y unar
	cp "${services_location}/torrent.service" /etc/systemd/system/
	# Keep the torrent stuff on the SSD so the main drives can stay off most of the time
	mkdir "/home/${TARGET_USER}/torrent"
	if [ "${disk_services}" = "Y" ] || [ "${disk_services}" = "y" ] ; then
		rsync -av "${share_mount_dir}/torrent" "/home/${TARGET_USER}/"
	else
		rsync -av "${remote_hostname}:${remote_share_dir}/torrent" "/home/${TARGET_USER}/"
	fi
	# Start the torrent service
	systemctl enable torrent
	systemctl start torrent
	docker pull rjszynal/flexget:latest
	(crontab -l ; echo "*/10 * * * * docker run --name flexget --rm -v /home/${TARGET_USER}/torrent/configs/flexget:/home/flexget/.flexget --net container:transmission rjszynal/flexget:latest") | crontab -
	if [ "${disk_services}" = "Y" ] || [ "${disk_services}" = "y" ] ; then
		nightly_backup_cmd+=(
			"rsync -av --delete --exclude='download' --exclude='watch' /home/${TARGET_USER}/torrent ${share_mount_dir}/"
			"chown -R ${TARGET_USER}:storage-share-rw ${share_mount_dir}/torrent"
		)
	else
		nightly_backup_cmd+=(
			"rsync -av --delete --exclude='download' --exclude='watch' /home/${TARGET_USER}/torrent ${remote_hostname}:${remote_share_dir}/"
			"chown -R ${TARGET_USER}:storage-share-rw ${remote_hostname}:${remote_share_dir}/torrent"
		)
	fi
	#echo "/home/${TARGET_USER}/torrent *(rw,sync,no_root_squash)" >> /etc/exports
	#systemctl restart nfs

	# Keep an eye on home directory space usage
	cat > /home/${TARGET_USER}/home_space_check.sh <<-SCRIPT
		#!/bin/bash
		THRESHOLD=95
		EMAIL="${EMAIL}"

		for partition in /home / ; do
		    current=\$(df \${partition} | tail -n1 | awk '{ print \$5}' | sed 's/%//g')
		    if [ "\${current}" -gt "\${THRESHOLD}" ] ; then
		        echo "\${partition} partition remaining free space is critically low. Used: \${current}%" | \\
		        mail -s 'Disk Space Alert' \${EMAIL}
		    fi
		done
	SCRIPT
	chmod +x "/home/${TARGET_USER}/home_space_check.sh"
	(crontab -l ; echo "0 * * * * /home/${TARGET_USER}/home_space_check.sh") | crontab -
fi

if [[ "${share_name}" == 'stoneholme' ]]; then
	nightly_backup_cmd+=(
		"rsync -av --delete --exclude='redirect' ${share_mount_dir}/ ${remote_hostname}:${remote_share_dir}/"
		"rsync -av --delete ${remote_hostname}:${remote_share_dir}/redirect ${share_mount_dir}/"
	)
fi

read -rn1 -p 'Is this server running print services? Y/n: ' print_services
if [ "${print_services}" = 'Y' ] || [ "${print_services}" = 'y' ] ; then
	read -rn1 -p "What is the current printer IP address? Y/n: " print_ip
	apt install -y cups
	sed -i 's/^Listen localhost:631$/Port 631/' /etc/cups/cupsd.conf
	echo "ServerAlias $(hostname).szynal.co.uk" >> /etc/cups/cupsd.conf
	cupsctl --remote-admin --remote-any --share-printers --user-cancel-any
	firewall-cmd --permanent --zone=public --add-service=ipp
	firewall-cmd --reload
	cp /home/${TARGET_USER}/development/src/github.com/rjszynal/dotfiles/scripts/print_driver/canonts8300.ppd /usr/share/cups/model/
	lpadmin -Ep Canon-TS8300 -D 'Canon TS8300 series Ver.5.90' -m canonts8300.ppd -v lpd://${print_ip}/BINARY_P1
	systemctl enable cups
	systemctl start cups
fi

if [ "${disk_services}" = 'Y' ] || [ "${disk_services}" = 'y' ] ; then
	# BUG: The hdparm settings are reset sometimes so this is a hack to set them again daily
	nightly_backup_cmd+=(
		'/root/set_disk_spindown.sh'
	)
fi
printf "%s\n" "${nightly_backup_cmd[@]}" > nightly_backup.sh
chmod +x nightly_backup.sh
mv nightly_backup.sh /root/nightly_backup.sh
(crontab -l ; echo '0 1 * * * /root/nightly_backup.sh') | crontab -

# Install Ookla Speedtest CLI
apt install -y speedtest-cli
(crontab -l ; echo '*/10 * * * * /usr/bin/speedtest-cli --csv >> /var/log/speedtest/speedtest.log') | crontab -
