#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
TARGET_USER="${1:-}"

log() { printf '\n\033[1;34m===[ %s ]===\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage:
  sudo bash $SCRIPT_NAME <main_user>

Exemple:
  sudo bash $SCRIPT_NAME robin

Ce script lance séquentiellement tous les scripts d'installation :

  1. install-buildtools.sh    — compilateurs, cmake, libs de dev
  2. install-essentials.sh    — git, htop, ripgrep, fzf, tmux…
  3. install-network.sh       — nmap, tcpdump, wireguard, ufw…
  4. install-python.sh        — Python 3, pip, venv, pipx
  5. install-java.sh          — OpenJDK JRE + JDK, Maven, Gradle
  6. install-golang.sh        — Go (dernière version)
  7. install-rust.sh          — Rust via rustup (pour <main_user>)
  8. install-node.sh          — Node.js LTS via NodeSource
  9. install-docker.sh        — Docker Engine + Compose
 10. install-bash.sh          — ble.sh, bash-completion
 11. install-clip.sh          — GPaste clipboard manager
 12. install-sublimtext.sh    — Sublime Text (snap)
 13. install-msedit.sh        — Microsoft Edit (CLI)

Chaque script peut aussi être lancé individuellement.
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

run_script() {
    local script="$1"
    shift
    local path="${SCRIPT_DIR}/${script}"

    if [[ ! -f "$path" ]]; then
        warn "Script introuvable, ignoré : ${script}"
        return 0
    fi

    log "${script}"
    if bash "$path" "$@"; then
        printf '\033[1;32m[✓] %s terminé\033[0m\n' "$script"
    else
        warn "${script} a échoué (code $?) — on continue"
    fi
}

main() {
    require_root
    require_user_arg

    local start_time
    start_time="$(date +%s)"

    log "Démarrage de l'installation complète pour ${TARGET_USER}"

    # --- Sans argument utilisateur ---
    run_script install-buildtools.sh
    run_script install-essentials.sh
    run_script install-network.sh
    run_script install-python.sh
    run_script install-java.sh
    run_script install-golang.sh

    # --- Avec argument utilisateur ---
    run_script install-rust.sh    "${TARGET_USER}"
    run_script install-node.sh    "${TARGET_USER}"
    run_script install-docker.sh  "${TARGET_USER}"
    run_script install-bash.sh    "${TARGET_USER}"
    run_script install-clip.sh    "${TARGET_USER}"
    run_script install-sublimtext.sh "${TARGET_USER}"

    # --- Sans argument (téléchargement direct) ---
    run_script install-msedit.sh

    local end_time elapsed
    end_time="$(date +%s)"
    elapsed=$(( end_time - start_time ))

    log "Installation complète terminée en ${elapsed}s"
    printf '\033[1;32mTout est prêt. Re-login recommandé pour %s.\033[0m\n' "${TARGET_USER}"
}

main "$@"
