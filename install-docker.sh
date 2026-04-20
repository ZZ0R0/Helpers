#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TARGET_USER="${1:-}"
export DEBIAN_FRONTEND=noninteractive

log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
trap 'warn "Erreur à la ligne ${BASH_LINENO[0]}: commande '\''${BASH_COMMAND}'\''"' ERR

usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME <main_user>

Exemple:
  sudo bash $SCRIPT_NAME robin

Ce script :
  - installe Docker Engine (repo officiel Docker)
  - installe Docker Compose plugin
  - ajoute <main_user> au groupe docker
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

main() {
    require_root
    require_user_arg

    log "Suppression d'anciens paquets Docker éventuels"
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        apt-get remove -y "$pkg" 2>/dev/null || true
    done

    log "Installation des dépendances"
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    log "Ajout du dépôt officiel Docker"
    install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    fi

    local arch codename
    arch="$(dpkg --print-architecture)"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"

    cat > /etc/apt/sources.list.d/docker.list <<REPO
deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${codename} stable
REPO

    log "Installation de Docker Engine + Compose"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    log "Activation du service Docker"
    systemctl enable --now docker

    log "Ajout de ${TARGET_USER} au groupe docker"
    usermod -aG docker "${TARGET_USER}"

    log "Docker installé avec succès."
    docker --version
    log "L'utilisateur ${TARGET_USER} pourra utiliser docker sans sudo après re-login."
}

main "$@"
