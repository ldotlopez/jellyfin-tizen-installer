#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'

# shellcheck disable=SC2034
__FILE__="$(realpath -- "${BASH_SOURCE[0]}")"
__DIR__="$(dirname -- "$__FILE__")"
__NAME__="$(basename -- "$__FILE__")"

DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME:-jellyfin-tizen-installer}"

function error() {
    echo -e "\033[31merror:\033[m ${*}"
}

set +e
# shellcheck disable=SC1091
if ! source "${__DIR__}/.env"; then
    error "Environment file '${__DIR__}/.env' is missing or invalid"
    exit 1

fi
set -e
for var in CERT_ALIAS CERT_COUNTRY CERT_FILENAME CERT_NAME CERT_PASSWORD JELLYFIN_BRANCH; do
    if [[ -z "${!var:-}" ]]; then
        error "$var environment variable is missing, check '${__DIR__}/.env'" >&2
        exit 1
    fi
done

docker build --tag "${DOCKER_IMAGE_TAG}:${JELLYFIN_BRANCH}" "${__DIR__}/docker" || {
    error "unable to run docker build"
    exit 1
}

mkdir -p "$__DIR__/cert" "$__DIR__/build"
docker run --rm -it \
    -e "PUID=$(id -u)" \
    -e "PGID=$(id -g)" \
    -e "CERT_ALIAS=${CERT_ALIAS}" \
    -e "CERT_COUNTRY=${CERT_COUNTRY}" \
    -e "CERT_NAME=${CERT_NAME}" \
    -e "CERT_PASSWORD=${CERT_PASSWORD}" \
    -e "TIZEN_TV_IP=${TIZEN_TV_IP}" \
    -v "${__DIR__}/cert:/cert" \
    -v "${__DIR__}/build:/build" \
    "${DOCKER_IMAGE_TAG}:${JELLYFIN_BRANCH}"
