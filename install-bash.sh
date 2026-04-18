#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
TARGET_USER="${1:-}"

BLESH_REPO="https://github.com/akinomyoga/ble.sh.git"
BLESH_SRC_DIR="/usr/local/src/ble.sh"
BLESH_PREFIX="/usr/local"
BLESH_FILE="${BLESH_PREFIX}/share/blesh/ble.sh"

MANAGED_BASHRC_START="# >>> bash-ux-managed >>>"
MANAGED_BASHRC_END="# <<< bash-ux-managed <<<"
MANAGED_INPUTRC_START="# >>> bash-ux-managed >>>"
MANAGED_INPUTRC_END="# <<< bash-ux-managed <<<"

usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME <main_user>

Exemple:
  su -c '/root/$SCRIPT_NAME robin'

Ce script :
  - installe bash-completion
  - installe/maj ble.sh system-wide dans ${BLESH_PREFIX}
  - configure ~/.bashrc et ~/.inputrc pour root et pour <main_user>
EOF
}

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

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Ce script doit être exécuté en root."
    fi
}

require_user_arg() {
    if [[ -z "${TARGET_USER}" ]]; then
        usage
        exit 1
    fi

    if ! getent passwd "${TARGET_USER}" >/dev/null 2>&1; then
        die "Utilisateur introuvable : ${TARGET_USER}"
    fi
}

get_home_dir() {
    local user="$1"
    getent passwd "$user" | cut -d: -f6
}

backup_file_once() {
    local file="$1"

    if [[ -f "$file" ]]; then
        local backup="${file}.bak.pre-bash-ux"
        if [[ ! -e "$backup" ]]; then
            cp -a -- "$file" "$backup"
        fi
    fi
}

strip_managed_block() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local tmp
    tmp="$(mktemp)"

    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { skip=1; next }
        $0 == end   { skip=0; next }
        skip != 1   { print }
    ' "$file" > "$tmp"

    cat "$tmp" > "$file"
    rm -f "$tmp"
}

append_managed_block() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local content="$4"

    mkdir -p "$(dirname "$file")"
    touch "$file"

    backup_file_once "$file"
    strip_managed_block "$file" "$start_marker" "$end_marker"

    {
        printf '\n%s\n' "$start_marker"
        printf '%s\n' "$content"
        printf '%s\n' "$end_marker"
    } >> "$file"
}

set_owner_if_needed() {
    local file="$1"
    local user="$2"

    if [[ "$user" != "root" ]]; then
        chown "$user":"$user" "$file"
    else
        chown root:root "$file"
    fi
}

ensure_permissions() {
    local file="$1"
    local mode="$2"
    chmod "$mode" "$file"
}

install_packages() {
    log "Installation des paquets nécessaires"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        bash-completion \
        git \
        make \
        gawk \
        ca-certificates
}

install_or_update_blesh() {
    log "Installation / mise à jour de ble.sh dans ${BLESH_PREFIX}"

    mkdir -p "$(dirname "$BLESH_SRC_DIR")"

    if [[ -d "${BLESH_SRC_DIR}/.git" ]]; then
        git -C "$BLESH_SRC_DIR" fetch --depth 1 origin
        git -C "$BLESH_SRC_DIR" reset --hard origin/master
        git -C "$BLESH_SRC_DIR" submodule update --init --recursive --depth 1
    else
        rm -rf "$BLESH_SRC_DIR"
        git clone --recursive --depth 1 --shallow-submodules \
            "$BLESH_REPO" "$BLESH_SRC_DIR"
    fi

    make -C "$BLESH_SRC_DIR" install PREFIX="$BLESH_PREFIX"

    [[ -r "$BLESH_FILE" ]] || die "ble.sh n'a pas été installé correctement : ${BLESH_FILE}"
}

build_bashrc_block() {
    cat <<'EOF'
# Chargement bash-completion
if [ -n "${BASH_VERSION:-}" ] && ! shopt -oq posix; then
    if [ -r /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    fi
fi

# Chargement ble.sh uniquement pour les shells interactifs bash
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]] && [ -r /usr/local/share/blesh/ble.sh ]; then
    source /usr/local/share/blesh/ble.sh

    # Revenir à un comportement proche du Bash standard sur Entrée,
    # y compris après collage multi-lignes
    function _bashux_blesh_enter_fix_emacs {
        ble-bind -f 'C-m' accept-line
        ble-bind -f 'RET' accept-line
        return 0
    }
    blehook/eval-after-load keymap_emacs _bashux_blesh_enter_fix_emacs

    function _bashux_blesh_enter_fix_vi {
        ble-bind -m vi_imap -f 'C-m' accept-line
        ble-bind -m vi_imap -f 'RET' accept-line
        ble-bind -m vi_nmap -f 'C-m' accept-line
        ble-bind -m vi_nmap -f 'RET' accept-line
        return 0
    }
    blehook/eval-after-load keymap_vi _bashux_blesh_enter_fix_vi

    # Style sobre compatible terminal GNOME dark
    if declare -F ble-face >/dev/null 2>&1; then
        ble-face -s auto_complete fg=245

        ble-face -s menu_complete_match fg=110,bold
        ble-face -s menu_complete_selected fg=255,bg=238
        ble-face -s menu_desc_default fg=248
        ble-face -s menu_desc_type fg=110
        ble-face -s menu_desc_quote fg=150
        ble-face -s menu_filter_fixed fg=110,bold
        ble-face -s menu_filter_input fg=255,bg=237

        ble-face -s syntax_command fg=110
        ble-face -s syntax_quoted fg=150
        ble-face -s syntax_escape fg=179
        ble-face -s syntax_expr fg=111
        ble-face -s syntax_error fg=255,bg=124
        ble-face -s syntax_varname fg=179
        ble-face -s syntax_comment fg=242

        ble-face -s command_builtin fg=174
        ble-face -s command_alias fg=116
        ble-face -s command_function fg=146
        ble-face -s command_keyword fg=111
        ble-face -s filename_directory fg=111,underline
        ble-face -s filename_executable fg=114,underline
    fi

    # Nettoyage des marqueurs visuels jugés agressifs
    bleopt prompt_eol_mark=''
    bleopt exec_elapsed_mark=
    bleopt exec_exit_mark=
    bleopt edit_marker=
    bleopt edit_marker_error=
fi
EOF
}

build_inputrc_block() {
    cat <<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward

set show-all-if-ambiguous on
set completion-ignore-case on
EOF
}

configure_user_files() {
    local user="$1"
    local home_dir="$2"
    local bashrc="${home_dir}/.bashrc"
    local inputrc="${home_dir}/.inputrc"

    log "Configuration de ${user} (${home_dir})"

    append_managed_block "$bashrc" "$MANAGED_BASHRC_START" "$MANAGED_BASHRC_END" "$(build_bashrc_block)"
    append_managed_block "$inputrc" "$MANAGED_INPUTRC_START" "$MANAGED_INPUTRC_END" "$(build_inputrc_block)"

    set_owner_if_needed "$bashrc" "$user"
    set_owner_if_needed "$inputrc" "$user"

    ensure_permissions "$bashrc" 0644
    ensure_permissions "$inputrc" 0644
}

check_shell_info() {
    local user="$1"
    local shell_path
    shell_path="$(getent passwd "$user" | cut -d: -f7 || true)"

    if [[ "$shell_path" != */bash ]]; then
        warn "L'utilisateur ${user} n'a pas bash comme shell de login (${shell_path})."
        warn "La configuration a quand même été écrite dans ~/.bashrc et ~/.inputrc."
    fi
}

print_done() {
    cat <<EOF

Configuration terminée.

Utilisateurs configurés :
  - root
  - ${TARGET_USER}

Fichiers modifiés :
  - /root/.bashrc
  - /root/.inputrc
  - $(get_home_dir "${TARGET_USER}")/.bashrc
  - $(get_home_dir "${TARGET_USER}")/.inputrc

Installation système :
  - ${BLESH_FILE}

Pour appliquer immédiatement :
  - ouvrir une nouvelle session shell
  - ou lancer : source ~/.bashrc

Test rapide :
  - taper le début d'une ancienne commande puis flèche haut
  - taper quelques lettres d'une commande connue pour voir l'autosuggestion inline
  - coller plusieurs lignes puis appuyer sur Entrée pour vérifier qu'il n'y a plus besoin de Ctrl+J
EOF
}

main() {
    require_root
    require_user_arg

    local root_home target_home
    root_home="/root"
    target_home="$(get_home_dir "${TARGET_USER}")"

    [[ -d "$root_home" ]] || die "Home root introuvable"
    [[ -d "$target_home" ]] || die "Home utilisateur introuvable : ${target_home}"

    install_packages
    install_or_update_blesh

    configure_user_files "root" "$root_home"
    configure_user_files "${TARGET_USER}" "$target_home"

    check_shell_info "root"
    check_shell_info "${TARGET_USER}"

    print_done
}

main "$@"