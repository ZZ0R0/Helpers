#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
export DEBIAN_FRONTEND=noninteractive

log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
trap 'warn "Erreur à la ligne ${BASH_LINENO[0]}: commande '\''${BASH_COMMAND}'\''"' ERR

usage() {
    cat <<EOF
Usage:
  sudo bash $SCRIPT_NAME

Ce script :
  - installe Python 3, pip, venv, dev headers
  - installe pipx pour les outils CLI isolés
EOF
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être exécuté en root."
}

main() {
    require_root

    log "Installation de Python 3 + outils"
    apt-get update
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-setuptools \
        python3-wheel \
        pipx

    log "Configuration de pipx dans le PATH system-wide"
    cat > /etc/profile.d/pipx.sh <<'PROFILE'
if [[ -d "${HOME}/.local/bin" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi
PROFILE
    chmod 0644 /etc/profile.d/pipx.sh

    log "Python installé avec succès."
    python3 --version
    pip3 --version 2>/dev/null || true
}

main "$@"
