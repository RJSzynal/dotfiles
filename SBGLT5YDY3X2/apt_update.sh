#!/bin/bash

/usr/bin/apt-get -y update && \
	/usr/bin/apt-get -y full-upgrade && \
	/usr/bin/apt-get -y autoremove

