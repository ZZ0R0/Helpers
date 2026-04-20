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

    log "Installation des outils essentiels"
    apt-get update
    apt-get install -y \
        git \
        git-lfs \
        curl \
        wget \
        htop \
        btop \
        tree \
        jq \
        ripgrep \
        fd-find \
        bat \
        fzf \
        tmux \
        unzip \
        zip \
        p7zip-full \
        rsync \
        strace \
        lsof \
        net-tools \
        dnsutils \
        iproute2 \
        mtr-tiny \
        ncdu \
        file \
        bc \
        shellcheck \
        neofetch

    log "Configuration de git-lfs"
    git lfs install --system || true

    log "Outils essentiels installés."
}

main "$@"
