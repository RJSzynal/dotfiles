#!/bin/bash

sudo /usr/sbin/service docker start && \
	sleep 2 && \
	cd /home/robert/development/src/stash.skybet.net/GDO/traefik-dev-env && \
	make up

