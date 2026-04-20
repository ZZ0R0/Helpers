#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TARGET_USER="${1:-}"
export DEBIAN_FRONTEND=noninteractive

NODE_MAJOR=22

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
  - installe Node.js ${NODE_MAJOR}.x LTS (via repo NodeSource)
  - installe npm et corepack (yarn/pnpm)
  - configure le préfixe npm global pour <main_user>
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

    log "Installation des dépendances"
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    log "Ajout du dépôt NodeSource"
    install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/nodesource.gpg ]]; then
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
            | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    fi

    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list

    log "Installation de Node.js ${NODE_MAJOR}.x"
    apt-get update
    apt-get install -y nodejs

    log "Activation de corepack (yarn, pnpm)"
    corepack enable || warn "corepack enable échoué (non critique)"

    log "Configuration du préfixe npm global pour ${TARGET_USER}"
    local npm_prefix="${target_home}/.npm-global"
    runuser -u "${TARGET_USER}" -- mkdir -p "${npm_prefix}"
    runuser -u "${TARGET_USER}" -- npm config set prefix "${npm_prefix}"

    cat > /etc/profile.d/node.sh <<'PROFILE'
if [[ -d "${HOME}/.npm-global/bin" ]]; then
    export PATH="${HOME}/.npm-global/bin:${PATH}"
fi
PROFILE
    chmod 0644 /etc/profile.d/node.sh

    log "Node.js installé avec succès."
    node --version
    npm --version
}

main "$@"
