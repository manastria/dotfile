#!/usr/bin/env bash
# usb-umount — Démonte les volumes LUKS/f2fs définis dans devices.conf
# Usage : usb-umount [UUID]   (sans argument : démonte tout ce qui est monté)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

CONFIG_FILE="${USB_MOUNT_CONF:-${HOME}/.config/usb-mount/devices.conf}"

# ── Validation config ──────────────────────────────────────────────────────────
[[ -f "$CONFIG_FILE" ]] || die "Fichier de configuration introuvable : ${CONFIG_FILE}"

# ── Préchauffage sudo ──────────────────────────────────────────────────────────
info "Des droits administrateur sont nécessaires pour le démontage."
sudo -v

# ── Filtre optionnel sur un UUID précis ───────────────────────────────────────
FILTER_UUID="${1:-}"

# ── Compteurs ─────────────────────────────────────────────────────────────────
count_umounted=0
count_skipped=0

# ── Fonction : démonter une entrée ────────────────────────────────────────────
umount_entry() {
  local uuid="$1"
  local mapper="$2"
  local mountpoint="$3"

  local did_something=0

  if mountpoint -q "$mountpoint" 2>/dev/null; then
    info "Démontage de ${mountpoint}..."
    sudo umount "$mountpoint"
    did_something=1
  fi

  # Vérifie aussi si le conteneur est ouvert sous un autre nom
  local active_mapper="$mapper"
  if [[ ! -e "/dev/mapper/${mapper}" ]]; then
    local device="/dev/disk/by-uuid/${uuid}"
    if [[ -e "$device" ]]; then
      local phys_dev existing_mapper
      phys_dev="$(readlink -f "$device")"
      existing_mapper="$(lsblk -rno NAME,TYPE "$phys_dev" 2>/dev/null | awk '$2=="crypt"{print $1; exit}')"
      if [[ -n "$existing_mapper" ]]; then
        warn "${mapper} — ouvert sous le nom '${existing_mapper}', fermeture du mapper existant"
        active_mapper="$existing_mapper"
      fi
    fi
  fi

  if [[ -e "/dev/mapper/${active_mapper}" ]]; then
    info "Fermeture LUKS /dev/mapper/${active_mapper}..."
    sudo cryptsetup close "$active_mapper"
    did_something=1
  fi

  if [[ $did_something -eq 1 ]]; then
    success "${mapper} démonté proprement"
    (( count_umounted++ )) || true
  else
    info "${mapper} — déjà démonté"
    (( count_skipped++ )) || true
  fi
}

# ── Lecture de la config ──────────────────────────────────────────────────────
info "Lecture de ${CONFIG_FILE}"
echo ""

while IFS= read -r line <&3 || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue

  read -r uuid mapper mountpoint <<< "$line"

  if [[ -z "$uuid" || -z "$mapper" || -z "$mountpoint" ]]; then
    continue
  fi

  if [[ -n "$FILTER_UUID" && "$uuid" != "$FILTER_UUID" ]]; then
    continue
  fi

  umount_entry "$uuid" "$mapper" "$mountpoint"

done 3< "$CONFIG_FILE"

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
info "Résumé : ${count_umounted} démonté(s), ${count_skipped} déjà démonté(s)"
