#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'

function is_bound {
	if [[ ! -d "$1" ]]; then
		echo "Not dir" >&2
		return 1
	fi

	# This checks if the device number (st_dev from stat) is the same as root
	# directory
	if [[ "$(stat --format=%d /)" = "$(stat --format=%d "$1")" ]]; then
		echo "same device" >&2
		return 1
	fi

	return 0
}

if ! is_bound "/cert"; then
	echo "Error: /cert directory must be mounted as a volume" >&2
	echo "Usage: docker run -v /path/to/certs:/cert ..." >&2
	exit 1
fi

mkdir -p /build

# Infere outside UID and GID, get them from the owner of /cert directory
PUID="${PUID:-$(stat --format=%u /cert)}"
PGID="${PGID:-$(stat --format=%g /cert)}"

# Setup build user and directories permissions
# For user just try to delete any existing user and group and recreate with
# current values
userdel builder 2>/dev/null || true
groupdel builder 2>/dev/null || true
groupadd --gid "$PGID" builder
useradd --uid "$PUID" --gid "$PGID" --home-dir /build --no-create-home --shell /bin/bash builder
chown -R "${PUID}:${PGID}" /cert /build

# Launch build script
echo "launch build with PUID=$PUID"
exec tini -- sudo -H -E -u builder /run.sh
