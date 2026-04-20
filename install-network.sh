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

    log "Installation des outils réseau et sécurité"
    apt-get update
    apt-get install -y \
        nmap \
        tcpdump \
        whois \
        openssh-client \
        openssh-server \
        gnupg \
        pass \
        wireguard-tools \
        iptables \
        ufw \
        fail2ban

    log "Outils réseau/sécurité installés."
}

main "$@"
