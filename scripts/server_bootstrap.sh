#!/bin/bash

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run as root"
    exit
fi

USERNAME="$(whoami)"
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAqcpCNp9MEYa+Sd5qr/c93uvV0sxqo78bm177itA7HdIUFi5IFSznQcQUAxllR3jS5r+/AJ5JVB0fP4yKDLjKnTRK4ShCWSHyg2XuVJPIfbpXYnnMhgF4ZbQKWbxTWKXWJz+6BH94i6R2+M3qXCOYx/imeiseMpa5hWY98y6I70DihiF+UaY7t07EYK6SagyYqXjBro7fUJsO11KhX3wo2nUNlwYHM/0AufxsibbWiXaz4oAjw1IUPMNTAaAUlhfiDV1zFKmqfppxDYqQkYVBv6MeHzR5O+XSU8ikUHPq21eJ9fEFQhO+fzZkuOJHBu0o6Q9eSqxk3w08QcRVq6BcYQ== Personal"
EMAIL="robert@szynal.co.uk"
nightly_backup_cmd=('#!/bin/sh')

## SSH access
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "${PUBLIC_KEY}" >> ~/.ssh/authorized_keys
chown "${USERNAME}": ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

## Ensure everything is up to date and install some general packages
sudo yum upgrade -y
sudo yum install -y \
	curl \
	git \
	tmux \
	unar \
	neovim \
	yum-cron

# Only keep 2 kernels
sudo sed -i '/^installonly_limit=/ s/5/2/' /etc/yum.conf

# Set up user account
git clone https://github.com/RJSzynal/dotfiles.git ~/development/src/github.com/rjszynal/dotfiles/
(crontab -l; echo '0 4 * * * git --git-dir=~/development/src/github.com/rjszynal/dotfiles/.git --work-tree=~/development/src/github.com/rjszynal/dotfiles pull') | crontab -
ln -sfn ~/{development/src/github.com/rjszynal/dotfiles/,}.dockerfunc
ln -sfn ~/{development/src/github.com/rjszynal/dotfiles/,}.exports
ln -sfn ~/{development/src/github.com/rjszynal/dotfiles/,}.aliases

cat >> ${HOME}/.bashrc <<-"BASHRC"
	for file in ~/.{bash_prompt,aliases,functions,path,dockerfunc,extra,exports}; do
	    if [[ -r "$file" ]] && [[ -f "$file" ]]; then
	        # shellcheck source=/dev/null
	        source "$file"
	    fi
	done
	unset file
BASHRC

git clone https://github.com/RJSzynal/dockerfiles.git ~/development/src/github.com/rjszynal/dockerfiles/
(crontab -l; echo '0 4 * * Mon bash -c "cd /home/robert/development/src/github.com/rjszynal/dockerfiles && git pull && make"') | crontab -

# Set up yum-cron
sudo sed -i -e '/^apply_updates =/ s/no/yes/' \
	-e "/^email_to =/ s/root/${EMAIL}/" \
	-e '/^emit_via =/ s/stdio/email/' /etc/yum/yum-cron.conf
sudo systemctl restart yum-cron
sudo systemctl enable yum-cron

read -rn1 -p "Is this server running disk services? Y/n: " disk_services
if [ "${disk_services}" = "Y" ] || [ "${disk_services}" = "y" ] ; then
	# Set up smartd
	sudo sed -i '/^DEVICESCAN/ s/^/#/' /etc/smartmontools/smartd.conf
	echo "DEVICESCAN -H -m ${EMAIL} -M test -M diminishing -M exec /usr/libexec/smartmontools/smartdnotify -n standby,48,q" | sudo tee -a /etc/smartmontools/smartd.conf
	sudo systemctl restart smartd

	## ZFS set up
	# Install
	sudo yum install -y https://zfsonlinux.org/epel/zfs-release.el7_9.noarch.rpm
	sudo yum install -y epel-release
	sudo yum install -y kernel-devel-$(uname -r) 
	sudo yum install -y \
		zfs \
		hdparm \
		smartmontools
	sudo /sbin/modprobe zfs
	sudo systemctl enable zfs.target

	# ZFS Creation
	read -rp "What is the server name? (for naming the file share): " share_name
	lsblk
	read -rp "Which devices should be in the raid? e.g. sdb sdc sdd sde: " -a raid_drives
	sudo zpool import "${share_name}" || sudo zpool create -f "${share_name}" mirror "${raid_drives[@]}"
	read -rp "Where should the share be mounted locally? e.g. /mnt/${share_name}: " share_mount_dir
	sudo zfs set mountpoint="${share_mount_dir}" "${share_name}"

	# Healthchecks
	sudo bash -c "cat > /root/zfs_check.sh" <<-SCRIPT
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
	sudo chmod +x /root/zfs_check.sh
	(sudo crontab -l ; echo "*/15 * * * * /root/zfs_check.sh") | sudo crontab -
	(sudo crontab -l ; echo "0 5 1 * * /usr/sbin/zpool scrub nordelle") | sudo crontab -
	
	# Reduce time spent spun up
	sudo bash -c "cat > /root/set_disk_spindown.sh" <<-"SCRIPT"
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
	sudo chmod +x /root/set_disk_spindown.sh


	## Set up the NFS share
	sudo yum install -y nfs-utils
	echo "${share_mount_dir} *(rw,sync,no_root_squash,fsid=0)" | sudo tee -a /etc/exports
	sudo groupadd storage-share-rw
	sudo chown nfsnobody:storage-share-rw "${share_mount_dir}"
	sudo chmod 755 "${share_mount_dir}"
	sudo systemctl enable rpcbind
	sudo systemctl enable nfs
	sudo systemctl enable nfs-lock
	sudo systemctl enable nfs-idmap
	sudo firewall-cmd --permanent --zone=public --add-service=nfs
	sudo firewall-cmd --permanent --zone=public --add-service=mountd
	sudo firewall-cmd --permanent --zone=public --add-service=rpc-bind
	sudo firewall-cmd --reload
	sudo systemctl start rpcbind
	sudo systemctl start nfs
	
	
	## Set up the SMB share
	sudo yum install -y \
		samba \
		samba-client \
		samba-common
	sudo bash -c "cat > /etc/samba/smb.conf" <<-SAMBA
		[global]
		    workgroup = WORKGROUP
		    server string = Samba Server %v
		    netbios name = $(hostname -s)
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
	sudo bash -c "cat > /etc/samba/smbusers" <<-"SAMBAUSERS"
		root = root administrator
	SAMBAUSERS
	echo "Please set the password for connecting to the samba shares"
	sudo smbpasswd -a root
	sudo chcon -t samba_share_t "${share_mount_dir}"
	sudo usermod -aG storage-share-rw "${USERNAME}"
	sudo systemctl enable smb.service
	sudo systemctl enable nmb.service
	sudo firewall-cmd --permanent --zone=public --add-service=samba
	sudo firewall-cmd --reload
	sudo systemctl start smb.service
	sudo systemctl start nmb.service
fi


## Mount remote shares
read -rp "What is the remote share host name? e.g. nordelle.szynal.co.uk: " remote_hostname
read -rp "What is the remote share location? e.g. /mnt/stoneholme: " remote_share_dir
read -rp "Where should the remote share be mounted locally? e.g. ${remote_share_dir}: " remote_share_local_mount_dir
#sudo mkdir -p ${remote_share_local_mount_dir}
#echo "${remote_hostname}:${remote_share_dir}    ${remote_share_local_mount_dir}   nfs    defaults,noauto 0 0" | sudo tee -a /etc/fstab
#sudo mount ${remote_share_local_mount_dir}


## Keep the domain IP address updated in godaddy nameservers
sudo bash -c "cat > /usr/bin/godaddy-ddns-updater" <<"SCRIPT"
#!/bin/bash

# GoDaddy.sh v1.3 by Nazar78 @ TeaNazaR.com
###########################################
# Simple DDNS script to update GoDaddy's DNS. Just schedule every 5mins in crontab.
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
#
# PS: Feel free to distribute but kindly retain the credits (-:
###########################################

if [ $# -lt 2 ] || [ $# -gt 5 ]
then
  echo "Usage: $0 credentials domain [sub-domain] [ttl] [record_type]"
  echo "  credentials: GoDaddy developer API in the format 'key:secret' or"
  echo "               location of file containing that value on the first line"
  echo "  domain: The domain you're setting. e.g. mydomain.com"
  echo "  sub-domain: Record name, as seen in the DNS setup page. Default: @ (apex domain)"
  echo "  ttl: Time To Live in seconds. Default: 600 (10 minutes)"
  echo "  record_type: Record type, as seen in the DNS setup page. Default: A"
  exit 1
fi

## Set and validate the variables
# Get the Production API key/secret from https://developer.godaddy.com/keys/.
# Ensure it's for "Production" as first time it's created for "Test".
if [ -z "${1}" ]
then
  echo "Error: Requires API 'Key:Secret' value. Can be a file location containing the value."
  exit 1
else
  if [ -e "${1}" ]
  then
      Credentials=$(head -n 1 ${1})
  else
      Credentials=${1}
  fi
fi
if [ -z "${Credentials}" ] # Check this again in case the file had a blank line
then
  echo "Error: Requires API 'Key:Secret' value. Can be a file location containing the value."
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

# Time To Live in seconds, minimum default 600 (10mins).
# If your public IP seldom changes, set it to 3600 (1hr) or more for DNS servers cache performance.
TTL=${4-600}
[ -z "${TTL}" ] && TTL=600
[ "${TTL}" -lt 600 ] && TTL=600 # 600 is the minimum

# Record type, as seen in the DNS setup page, default A.
Type=${5-A}
[ -z "${Type}" ] && Type=A

# Writable path to last known Public IP record cached. Best to place in tmpfs.
CacheFilename=${Domain}_${Type}_${Name}
# This cleans up any illegal characters e.g. When setting the * record
CachedIP=/tmp/${CacheFilename//[*\/]/_}
echo -n>>${CachedIP} 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Error: Can't write to ${CachedIP}."
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
FailedExec=''
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
  echo "Fail! ${PublicIP}"
  eval ${FailedExec}
  exit 1
fi


## Compare the current public IP to the cached IP from the last run
if [ "$(cat ${CachedIP} 2>/dev/null)" = "${PublicIP}" ]
then
  echo "Current 'Public IP' matches 'Cached IP' recorded. No update required!"
  exit 0
fi


## Get the currently set IP from the GoDaddy record
echo -n "Checking '${Domain}' IP records from 'GoDaddy'..."

Check=$(${Curl} -kLs \
-H "Authorization: sso-key ${Credentials}" \
-H "Content-type: application/json" \
https://api.godaddy.com/v1/domains/${Domain}/records/${Type}/${Name} \
2>/dev/null | grep -Eo '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' 2>/dev/null)


## Compare the current public IP to the GoDaddy record
if [ $? -eq 0 ] && [ "${Check}" = "${PublicIP}" ]
then
  echo -n "${Check}" > ${CachedIP} # Record the current public IP in the cache file
  echo "unchanged"
  echo "Current 'Public IP' matches 'GoDaddy' records. No update required."
  exit 0
fi


## Update the GoDaddy record with the current IP
echo "changed"
echo -n "Updating '${Domain}'..."

Update=$(${Curl} -kLs \
-X PUT \
-H "Authorization: sso-key ${Credentials}" \
-H "Content-type: application/json" \
-w "%{http_code}" \
-o /dev/null \
https://api.godaddy.com/v1/domains/${Domain}/records/${Type}/${Name} \
-d "[{\"data\":\"${PublicIP}\",\"ttl\":${TTL}}]" 2>/dev/null)

if [ $? -eq 0 ] && [ "${Update}" -eq 200 ]
then
  echo -n "${PublicIP}" > ${CachedIP} # Record the current public IP in the cache file
  echo "Success"
  eval ${SuccessExec}
  exit 0
else
  echo "Fail! HTTP_ERROR:${Update}"
  eval ${FailedExec}
  exit 1
fi
SCRIPT
sudo chmod +x /usr/bin/godaddy-ddns-updater
read -rp "What is the domain name to update with godaddy? stoneholme.szynal.co.uk: " web_domain
(crontab -l ; echo "*/5 * * * * /usr/bin/godaddy-ddns-updater /home/${USERNAME}/torrent/configs/godaddy/.creds szynal.co.uk ${web_domain%.szynal.co.uk} 1800 > /dev/null") | crontab -
read -rp "Is this the root domain?: " is_root_domain
if [ "${is_root_domain}" = "Y" ] || [ "${is_root_domain}" = "y" ]; then
	(crontab -l ; echo "*/5 * * * * /usr/bin/godaddy-ddns-updater /home/${USERNAME}/torrent/configs/godaddy/.creds szynal.co.uk @ 1800 > /dev/null") | crontab -
	(crontab -l ; echo "*/5 * * * * /usr/bin/godaddy-ddns-updater /home/${USERNAME}/torrent/configs/godaddy/.creds szynal.co.uk "*" 1800 > /dev/null") | crontab -
fi

# Install Docker
# DIRECT-LVM
sudo yum install -y \
	device-mapper-persistent-data \
	lvm2
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "${USERNAME}"


services_location="${HOME}/development/src/github.com/rjszynal/dotfiles/scripts/services"
## Traefik set up
sudo cp "${services_location}/traefik.service" /etc/systemd/system/
sudo systemctl enable traefik
sudo systemctl start traefik

## Web services set up
read -rn1 -p "Is this server running the web services? Y/n: " web_services
if [ "${web_services}" = "Y" ] || [ "${web_services}" = "y" ] ; then
	# Start the CV page
	sudo cp "${services_location}/cv.service" /etc/systemd/system/
	sudo systemctl enable cv
	sudo systemctl start cv

	# Start the web experiments site
	#sudo cp "${services_location}/web.service" /etc/systemd/system/
	#sudo systemctl enable web
	#sudo systemctl start web

fi

## Torrent services set up
read -rn1 -p "Is this server running the torrent services? Y/n: " torrent_services
if [ "${torrent_services}" = "Y" ] || [ "${torrent_services}" = "y" ] ; then
	# Add the torrent service
	sudo yum install -y unar
	sudo cp "${services_location}/torrent.service" /etc/systemd/system/
	# Keep the torrent stuff on the SSD so the main drives can stay off most of the time
	mkdir "/home/${USERNAME}/torrent"
	if [ "${disk_services}" = "Y" ] || [ "${disk_services}" = "y" ] ; then
		rsync -av "${share_mount_dir}/torrent" "/home/${USERNAME}/"
	else
		rsync -av "${remote_hostname}:${remote_share_dir}/torrent" "/home/${USERNAME}/"
	fi
	# Start the torrent service
	sudo systemctl enable torrent
	sudo systemctl start torrent
	sudo docker pull rjszynal/flexget:latest
	(crontab -l ; echo "*/10 * * * * docker run --name flexget --rm -v /home/${USERNAME}/torrent/configs/flexget:/home/flexget/.flexget --net container:transmission rjszynal/flexget:latest") | crontab -
	if [ "${disk_services}" = "Y" ] || [ "${disk_services}" = "y" ] ; then
		nightly_backup_cmd+=(
			"rsync -av --delete --exclude='download' --exclude='watch' /home/${USERNAME}/torrent ${share_mount_dir}/"
			"chown -R ${USERNAME}: ${share_mount_dir}/torrent"
		)
	else
		nightly_backup_cmd+=(
			"rsync -av --delete --exclude='download' --exclude='watch' /home/${USERNAME}/torrent ${remote_hostname}:${remote_share_dir}/"
			"chown -R ${USERNAME}: ${remote_hostname}:${remote_share_dir}/torrent"
		)
	fi
	#echo "/home/${USERNAME}/torrent *(rw,sync,no_root_squash)" | sudo tee -a /etc/exports
	#systemctl restart nfs

	# Keep an eye on home directory space usage
	sudo bash -c "cat > /home/${USERNAME}/home_space_check.sh" <<- SCRIPT
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
	sudo chmod +x "/home/${USERNAME}/home_space_check.sh"
	(crontab -l ; echo "0 * * * * /home/${USERNAME}/home_space_check.sh") | crontab -
fi

if [[ "${share_name}" == 'stoneholme' ]]; then
	nightly_backup_cmd+=(
		"rsync -av --delete --exclude='redirect' ${share_mount_dir}/ ${remote_hostname}:${remote_share_dir}/"
		"rsync -av --delete ${remote_hostname}:${remote_share_dir}/redirect ${share_mount_dir}/"
	)
fi

if [ "${disk_services}" = 'Y' ] || [ "${disk_services}" = 'y' ] ; then
	# BUG: The hdparm settings are reset sometimes so this is a hack to set them again daily
	nightly_backup_cmd+=(
		'/root/set_disk_spindown.sh'
	)
fi
sudo printf "%s\n" "${nightly_backup_cmd[@]}" > nightly_backup.sh
chmod +x nightly_backup.sh
sudo mv nightly_backup.sh /root/nightly_backup.sh
(sudo crontab -l ; echo '0 1 * * * /root/nightly_backup.sh') | sudo crontab -
(sudo crontab -l ; echo '*/10 * * * * speedtest --format=csv >> /var/log/speedtest/speedtest.log') | sudo crontab -
