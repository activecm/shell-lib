#!/bin/bash

# Exit values
# 0 correct version installed
# 3 not installed
# 4 older than required minimum version
# 5 newer than required maximum version
# 6 Docker is installed via snap, which is incompatible with ActiveCM software

if [ ! -x "$(command -v docker)" ]; then
	exit 3
fi

MIN_VERSION_MAJOR=17
MIN_VERSION_MINOR=05
MAX_VERSION_MAJOR=19
MAX_VERSION_MINOR=03

VERSION="$(docker -v | sed 's/^.* \([0-9][0-9]*\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\).*$/\1 \2 \3/')"
VERSION_MAJOR="$(echo $VERSION | cut -d' ' -f1)"
VERSION_MINOR="$(echo $VERSION | cut -d' ' -f2)"

if [ "$VERSION_MAJOR" -lt "$MIN_VERSION_MAJOR" ] ||
	[ "$VERSION_MAJOR" -eq "$MIN_VERSION_MAJOR" -a "$VERSION_MINOR" -lt "$MIN_VERSION_MINOR" ]; then
	exit 4
# Disabled in https://github.com/activecm/shell-lib/pull/9
# elif [ "$VERSION_MAJOR" -gt "$MAX_VERSION_MAJOR" ] ||
# 	[ "$VERSION_MAJOR" -eq "$MAX_VERSION_MAJOR" -a "$VERSION_MINOR" -gt "$MAX_VERSION_MINOR" ]; then
# 	exit 5
elif [ "$(command -v docker)" = "/snap/bin/docker" ]; then
	exit 6
else
	exit 0
fi

