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
  - installe le JRE et JDK (OpenJDK default)
  - installe Maven et Gradle
EOF
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être exécuté en root."
}

main() {
    require_root

    log "Installation de Java JRE + JDK + outils de build"
    apt-get update
    apt-get install -y \
        default-jre \
        default-jdk \
        maven \
        gradle

    log "Configuration de JAVA_HOME via /etc/profile.d/"
    local java_home
    java_home="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

    cat > /etc/profile.d/java.sh <<PROFILE
export JAVA_HOME="${java_home}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"
PROFILE
    chmod 0644 /etc/profile.d/java.sh

    log "Java installé avec succès."
    java -version 2>&1 | head -1
    javac -version 2>&1 | head -1
}

main "$@"
