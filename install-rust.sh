#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TARGET_USER="${1:-}"

log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
trap 'warn "Erreur à la ligne ${BASH_LINENO[0]}: commande '\''${BASH_COMMAND}'\''"' ERR

usage() {
    cat <<EOF
Usage:
  sudo bash $SCRIPT_NAME <main_user>

Exemple:
  sudo bash $SCRIPT_NAME robin

Ce script :
  - installe Rust via rustup pour <main_user>
  - installe aussi les build essentials nécessaires
EOF
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être exécuté en root."
}

require_user_arg() {
    if [[ -z "${TARGET_USER}" ]]; then
        usage
        exit 1
    fi
    id "${TARGET_USER}" >/dev/null 2>&1 || die "Utilisateur introuvable : ${TARGET_USER}"
}

get_home_dir() {
    getent passwd "$1" | cut -d: -f6
}

main() {
    require_root
    require_user_arg

    local target_home
    target_home="$(get_home_dir "${TARGET_USER}")"

    export DEBIAN_FRONTEND=noninteractive

    log "Installation des dépendances de build"
    apt-get update
    apt-get install -y build-essential curl pkg-config libssl-dev

    log "Installation de Rust via rustup pour ${TARGET_USER}"
    if [[ -f "${target_home}/.cargo/bin/rustup" ]]; then
        log "rustup déjà installé, mise à jour"
        runuser -u "${TARGET_USER}" -- "${target_home}/.cargo/bin/rustup" update
    else
        runuser -u "${TARGET_USER}" -- bash -c \
            'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
    fi

    log "Configuration du PATH via /etc/profile.d/"
    cat > /etc/profile.d/rust.sh <<'PROFILE'
if [[ -d "${HOME}/.cargo/bin" ]]; then
    export PATH="${HOME}/.cargo/bin:${PATH}"
fi
PROFILE
    chmod 0644 /etc/profile.d/rust.sh

    log "Rust installé avec succès."
    runuser -u "${TARGET_USER}" -- "${target_home}/.cargo/bin/rustc" --version
}

main "$@"
