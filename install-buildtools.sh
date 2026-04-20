#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
export DEBIAN_FRONTEND=noninteractive

log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
trap 'warn "Erreur à la ligne ${BASH_LINENO[0]}: commande '\''${BASH_COMMAND}'\''"' ERR

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être exécuté en root."
}

main() {
    require_root

    log "Installation des outils de build"
    apt-get update
    apt-get install -y \
        build-essential \
        gcc \
        g++ \
        make \
        cmake \
        ninja-build \
        autoconf \
        automake \
        libtool \
        pkg-config \
        libssl-dev \
        libffi-dev \
        zlib1g-dev \
        libreadline-dev \
        libsqlite3-dev \
        libbz2-dev \
        liblzma-dev \
        libncurses-dev

    log "Outils de build installés."
}

main "$@"
