#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TARGET_USER="${1:-}"
export DEBIAN_FRONTEND=noninteractive

log() {
    printf '[*] %s\n' "$*"
}

warn() {
    printf '[!] %s\n' "$*" >&2
}

die() {
    printf '[x] %s\n' "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    warn "Erreur à la ligne ${BASH_LINENO[0]}: commande '${BASH_COMMAND}'"
    exit "$exit_code"
}
trap on_error ERR

usage() {
    cat <<'EOF'
Usage:
  sudo bash install_gpaste_debian13.sh [USERNAME]

Exemples:
  sudo bash install_gpaste_debian13.sh
  sudo bash install_gpaste_debian13.sh elz

Comportement:
  - installe GPaste + extension GNOME + Extension Manager
  - si USERNAME est fourni et qu'une session GNOME active existe,
    tente d'activer automatiquement l'extension pour cet utilisateur
EOF
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Ce script doit être exécuté en root."
}

require_apt() {
    command -v apt-get >/dev/null 2>&1 || die "apt-get est introuvable."
}

user_exists() {
    local user="$1"
    id "$user" >/dev/null 2>&1
}

find_gpaste_extension_uuid() {
    local extdir meta
    for extdir in /usr/share/gnome-shell/extensions/*; do
        [[ -d "$extdir" ]] || continue
        meta="${extdir}/metadata.json"
        [[ -f "$meta" ]] || continue
        if grep -qi 'gpaste' "$meta"; then
            basename "$extdir"
            return 0
        fi
    done
    return 1
}

enable_extension_for_user() {
    local user="$1"
    local uid runtime_dir dbus_addr ext_uuid

    uid="$(id -u "$user")"
    runtime_dir="/run/user/${uid}"
    dbus_addr="unix:path=${runtime_dir}/bus"

    [[ -d "$runtime_dir" ]] || {
        warn "Pas de runtime dir pour ${user} (${runtime_dir})."
        warn "Extension non activée automatiquement."
        return 0
    }

    [[ -S "${runtime_dir}/bus" ]] || {
        warn "Pas de bus D-Bus utilisateur pour ${user}."
        warn "L'utilisateur devra activer l'extension après connexion GNOME."
        return 0
    }

    command -v gnome-extensions >/dev/null 2>&1 || {
        warn "Commande gnome-extensions absente, activation auto impossible."
        return 0
    }

    ext_uuid="$(find_gpaste_extension_uuid || true)"
    [[ -n "${ext_uuid}" ]] || {
        warn "UUID de l'extension GPaste introuvable."
        warn "L'utilisateur devra l'activer manuellement."
        return 0
    }

    log "Activation de l'extension '${ext_uuid}' pour ${user} ..."
    su - "$user" -s /bin/bash -c "
        export XDG_RUNTIME_DIR='${runtime_dir}'
        export DBUS_SESSION_BUS_ADDRESS='${dbus_addr}'
        gnome-extensions enable '${ext_uuid}'
    " || {
        warn "Échec de l'activation automatique pour ${user}."
        warn "Activation manuelle requise après connexion."
        return 0
    }

    log "Extension activée pour ${user}."
}

install_packages() {
    log "Mise à jour de l'index APT ..."
    apt-get update

    log "Installation des paquets GPaste / GNOME ..."
    apt-get install -y --no-install-recommends \
        gpaste-2 \
        gnome-shell-extension-gpaste \
        gnome-shell-extension-manager
}

post_install_info() {
    local ext_uuid="${1:-}"

    cat <<EOF

Installation terminée.

Paquets installés :
  - gpaste-2
  - gnome-shell-extension-gpaste
  - gnome-shell-extension-manager

Vérifications utiles :
  gpaste-client history
  gpaste-client list-histories

EOF

    if [[ -n "${ext_uuid}" ]]; then
        cat <<EOF
Extension détectée :
  ${ext_uuid}

EOF
    fi

    cat <<'EOF'
Si l'extension n'apparaît pas immédiatement dans GNOME :
  1. déconnecte/reconnecte la session
  2. ouvre "Extension Manager"
  3. active GPaste

Applications GUI utiles :
  - GPaste
  - Extension Manager
EOF
}

main() {
    require_root
    require_apt

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    if [[ -n "${TARGET_USER}" ]]; then
        user_exists "${TARGET_USER}" || die "Utilisateur introuvable: ${TARGET_USER}"
    fi

    install_packages

    local ext_uuid=""
    ext_uuid="$(find_gpaste_extension_uuid || true)"

    if [[ -n "${TARGET_USER}" ]]; then
        enable_extension_for_user "${TARGET_USER}"
    else
        warn "Aucun utilisateur fourni."
        warn "L'installation est faite, mais l'activation GNOME reste manuelle."
    fi

    post_install_info "${ext_uuid}"
}

main "$@"