#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

IFS=$'\n\t'

# shellcheck disable=SC2034
__FILE__="$(realpath -- "${BASH_SOURCE[0]}")"
__DIR__="$(dirname -- "$__FILE__")"
__NAME__="$(basename -- "$__FILE__")"

TIZEN_STUDIO_VERSION="5.6"
TIZEN_STUDIO_URL="https://download.tizen.org/sdk/Installer/tizen-studio_${TIZEN_STUDIO_VERSION}/web-cli_Tizen_Studio_${TIZEN_STUDIO_VERSION}_ubuntu-64.bin"

for var in TIZEN_TV_IP CERT_NAME CERT_ALIAS CERT_COUNTRY CERT_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: $var environment variable is required" >&2
        exit 1
    fi
done

#
# Handle tizen-studio installation and final build since we don't want to
# redistribute it inside the container
#

#
# Download and install
#
TIZEN_STUDIO_INSTALL_DIR="/build/tizen-studio"
if [[ ! -f "/build/tizen-studio.bin" ]]; then
    curl \
        --fail \
        --output "/build/tizen-studio.bin.tmp" \
        "$TIZEN_STUDIO_URL"
    mv "/build/tizen-studio.bin.tmp" "/build/tizen-studio.bin"
fi

chmod +x "/build/tizen-studio.bin"

if [[ ! -x "${TIZEN_STUDIO_INSTALL_DIR}/tools/ide/bin/tizen" ]]; then
    "/build/tizen-studio.bin" \
        --accept-license \
        "$TIZEN_STUDIO_INSTALL_DIR"
fi
PATH="${PATH}:${TIZEN_STUDIO_INSTALL_DIR}/tools/ide/bin:${TIZEN_STUDIO_INSTALL_DIR}/tools"

#
# Don't build another certificate if we already have one.
# Building wgt with a different certificate from any previous installed on
# the TV prevents wgt to be installed
#

if [[ ! -f "/cert/${CERT_NAME}.p12" ]]; then
    tizen \
        certificate \
        --alias "${CERT_ALIAS}" \
        --password "${CERT_PASSWORD}" \
        --country "${CERT_COUNTRY}" \
        --city "${CERT_COUNTRY}" \
        --name "${CERT_NAME}" \
        --filename "${CERT_NAME}"
    cp "/build/tizen-studio-data/keystore/author/${CERT_NAME}.p12" "/cert/${CERT_NAME}.p12"
fi

tizen \
    security-profiles add \
    --name "${CERT_NAME}" \
    --author "/cert/${CERT_NAME}.p12" \
    --password "${CERT_PASSWORD}"

sed -i "s|/cert/${CERT_NAME}.pwd||g" /build/tizen-studio-data/profile/profiles.xml
sed -i "s|/build/tizen-studio-data/tools/certificate-generator/certificates/distributor/tizen-distributor-signer.pwd|tizenpkcs12passfordsigner|" /build/tizen-studio-data/profile/profiles.xml

#
# Build and package wgt file
#
tizen build-web --output /build/build-web -- /src

cat >/build/tizen-package-wrapper.sh <<EOF
#!/usr/bin/expect -f
set timeout -1
spawn tizen package --type wgt --output /build/package -- /build/build-web
expect "Author password: "
send -- "$CERT_PASSWORD\r"
expect "Yes: (Y), No: (N) ?"
send -- "Y\r"
expect eof
EOF
chmod +x /build/tizen-package-wrapper.sh
/build/tizen-package-wrapper.sh

#
# Install package
#
if ! sdb connect "$TIZEN_TV_IP"; then
    echo "Error: Could not connect to $TIZEN_TV_IP" >&2
    exit 1
fi

DEVICE_ID="$(sdb devices | grep "^${TIZEN_TV_IP}:" | awk '{print $3}')"
if [[ -z "$DEVICE_ID" ]]; then
    echo "Error: Could not find device ID for $TIZEN_TV_IP"
    echo "Available devices:"
    sdb devices
    exit 1
fi

tizen install --name Jellyfin.wgt --target "${DEVICE_ID}" -- /build/package
