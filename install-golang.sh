#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
export DEBIAN_FRONTEND=noninteractive

GO_VERSION="1.24.2"
GO_INSTALL_DIR="/usr/local"

log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
trap 'warn "Erreur à la ligne ${BASH_LINENO[0]}: commande '\''${BASH_COMMAND}'\''"' ERR

usage() {
    cat <<EOF
Usage:
  sudo bash $SCRIPT_NAME

Ce script :
  - télécharge et installe Go ${GO_VERSION} dans ${GO_INSTALL_DIR}
  - configure le PATH system-wide via /etc/profile.d/
EOF
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être exécuté en root."
}

main() {
    require_root

    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *)       die "Architecture non supportée : $(uname -m)" ;;
    esac

    local tarball="go${GO_VERSION}.linux-${arch}.tar.gz"
    local url="https://go.dev/dl/${tarball}"

    log "Téléchargement de Go ${GO_VERSION} (${arch})"
    curl -fsSL -o "/tmp/${tarball}" "${url}"

    log "Suppression de l'ancienne installation Go"
    rm -rf "${GO_INSTALL_DIR}/go"

    log "Extraction dans ${GO_INSTALL_DIR}"
    tar -C "${GO_INSTALL_DIR}" -xzf "/tmp/${tarball}"
    rm -f "/tmp/${tarball}"

    log "Configuration du PATH system-wide"
    cat > /etc/profile.d/golang.sh <<'PROFILE'
export PATH="/usr/local/go/bin:${HOME}/go/bin:${PATH}"
PROFILE
    chmod 0644 /etc/profile.d/golang.sh

    log "Go installé avec succès."
    "${GO_INSTALL_DIR}/go/bin/go" version
}

main "$@"
