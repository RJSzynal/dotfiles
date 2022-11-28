#!/bin/bash

verbose=false
if [ -n "${1}" ]; then
	verbose=true;
fi

until [ -n "${latest_file}" ]; do
	latest_file=$(curl -s https://golang.org/dl/ | grep linux-amd64 | sed -n 's/.*>\(go[0-9.]*.linux-amd64.tar.gz\)<\/a>.*/\1/p' | head -n1)
done
current_version=$(/usr/local/go/bin/go version | cut -d' ' -f3)

if [ "${latest_file}" != "${current_version}.linux-amd64.tar.gz" ]; then
	tmp_dir=$(mktemp -d)
	cd ${tmp_dir}
	wget https://golang.org/dl/${latest_file}
	tar -C /usr/local -xzf ${latest_file}
	cd /
	rm -rf ${tmp_dir}
else
	if [ "${verbose}" = true ]; then
		echo "${current_version} is still the latest version"
	fi
fi

