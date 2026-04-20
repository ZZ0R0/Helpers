#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

trap 'echo "[!] Erreur ligne $LINENO : commande échouée." >&2' ERR

log() {
  echo "[*] $*"
}

die() {
  echo "[!] $*" >&2
  exit 1
}

run_as_target() {
  local target_user="$1"
  local target_home="$2"
  shift 2

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- env \
      HOME="$target_home" \
      XDG_DATA_DIRS="/var/lib/snapd/desktop:/var/lib/snapd/desktop/applications:/usr/local/share:/usr/share" \
      "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -u "$target_user" env \
      HOME="$target_home" \
      XDG_DATA_DIRS="/var/lib/snapd/desktop:/var/lib/snapd/desktop/applications:/usr/local/share:/usr/share" \
      "$@"
  else
    die "Ni runuser ni sudo n'est disponible."
  fi
}

find_sublime_desktop_id() {
  local path=""

  path="$(
    find /var/lib/snapd/desktop/applications -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null \
      | xargs -0 grep -liE '^Name=.*Sublime Text' 2>/dev/null \
      | head -n1
  )"

  if [[ -z "${path:-}" ]]; then
    path="$(
      find /var/lib/snapd/desktop/applications -maxdepth 1 -type f \
        \( -iname '*sublime*.desktop' -o -iname '*subl*.desktop' \) \
        2>/dev/null \
        | head -n1
    )"
  fi

  [[ -n "${path:-}" ]] || return 1
  basename "$path"
}

wait_for_snapd() {
  local i
  for i in $(seq 1 60); do
    if snap version >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

main() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Ce script doit être lancé en root."

  local target_user="${1:-${SUDO_USER:-}}"
  [[ -n "${target_user:-}" && "$target_user" != "root" ]] || die "Passe l'utilisateur desktop cible en argument. Exemple : $0 elz"

  local target_home
  target_home="$(getent passwd "$target_user" | cut -d: -f6)"
  [[ -n "${target_home:-}" && -d "$target_home" ]] || die "Impossible de trouver le HOME de l'utilisateur '$target_user'."

  export DEBIAN_FRONTEND=noninteractive

  log "Installation des paquets requis"
  apt-get update
  apt-get install -y snapd xdg-utils grep findutils coreutils util-linux

  log "Activation de snapd"
  systemctl enable --now snapd.socket
  systemctl start snapd.service || true

  log "Attente de disponibilité de snapd"
  wait_for_snapd || die "snapd ne répond pas correctement."

  log "Installation de Sublime Text"
  if ! snap list sublime-text >/dev/null 2>&1; then
    snap install sublime-text --classic
  else
    log "Sublime Text est déjà installé"
  fi

  log "Détection du fichier .desktop"
  local desktop_id
  desktop_id="$(find_sublime_desktop_id)" || die "Impossible de trouver le launcher .desktop de Sublime Text dans /var/lib/snapd/desktop/applications."
  [[ "$desktop_id" == *.desktop ]] || die "Identifiant .desktop invalide : $desktop_id"

  log "Desktop ID détecté : $desktop_id"

  local -a mimes=(
    text/plain
    text/markdown
    application/json
    application/xml
    text/x-python
    text/x-shellscript
    text/x-csrc
    text/x-c++src
    application/javascript
    text/html
    text/css
  )

  log "Application des associations MIME pour l'utilisateur $target_user"
  local mime
  for mime in "${mimes[@]}"; do
    run_as_target "$target_user" "$target_home" xdg-mime default "$desktop_id" "$mime"
  done

  log "Vérification"
  run_as_target "$target_user" "$target_home" xdg-mime query default text/plain || true
  run_as_target "$target_user" "$target_home" gio mime text/plain || true

  cat <<EOF

[OK] Installation et configuration terminées.

Utilisateur configuré : $target_user
HOME                : $target_home
Desktop ID          : $desktop_id

Test rapide :
  sudo -u $target_user env HOME=$target_home gio open /etc/hosts

EOF
}

main "$@"