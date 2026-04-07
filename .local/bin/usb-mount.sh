#!/usr/bin/env bash
# usb-mount — Monte les volumes LUKS/f2fs définis dans devices.conf
# Usage : usb-mount [UUID]   (sans argument : monte toutes les clés branchées)

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
MOUNT_OPTS="compress_algorithm=zstd,compress_log_size=3,compress_extension=*,nocompress_extension=jpg,nocompress_extension=png,nocompress_extension=mp4,nocompress_extension=zip,nocompress_extension=gz,nocompress_extension=zst,nodiscard,lazytime"

# ── Validation config ──────────────────────────────────────────────────────────
[[ -f "$CONFIG_FILE" ]] || die "Fichier de configuration introuvable : ${CONFIG_FILE}"

# ── Préchauffage sudo ──────────────────────────────────────────────────────────
info "Des droits administrateur sont nécessaires pour le montage."
sudo -v

# ── Filtre optionnel sur un UUID précis ───────────────────────────────────────
FILTER_UUID="${1:-}"

# ── Compteurs ─────────────────────────────────────────────────────────────────
count_mounted=0
count_skipped=0
count_absent=0

# ── Fonction : monter une entrée ──────────────────────────────────────────────
mount_entry() {
  local uuid="$1"
  local mapper="$2"
  local mountpoint="$3"
  local device="/dev/disk/by-uuid/${uuid}"

  if [[ ! -e "$device" ]]; then
    warn "${mapper} — clé absente (UUID : ${uuid})"
    (( count_absent++ )) || true
    return
  fi

  if mountpoint -q "$mountpoint" 2>/dev/null; then
    info "${mapper} — déjà monté sur ${mountpoint}"
    (( count_skipped++ )) || true
    return
  fi

  info "Montage de ${mapper} (UUID : ${uuid})..."

  if [[ ! -e "/dev/mapper/${mapper}" ]]; then
    # Vérifie si le conteneur LUKS est déjà ouvert sous un autre nom
    local phys_dev existing_mapper
    phys_dev="$(readlink -f "$device")"
    existing_mapper="$(lsblk -rno NAME,TYPE "$phys_dev" 2>/dev/null | awk '$2=="crypt"{print $1; exit}')"
    if [[ -n "$existing_mapper" ]]; then
      warn "${mapper} — déjà ouvert sous le nom '${existing_mapper}', utilisation du mapper existant"
      mapper="$existing_mapper"
    else
      sudo cryptsetup open "$device" "$mapper"
    fi
  fi

  if [[ ! -d "$mountpoint" ]]; then
    sudo mkdir -p "$mountpoint"
  fi

  sudo mount -t f2fs -o "$MOUNT_OPTS" "/dev/mapper/${mapper}" "$mountpoint"
  sudo chown "${USER}:${USER}" "$mountpoint"

  success "${mapper} monté sur ${mountpoint}"
  (( count_mounted++ )) || true
}

# ── Lecture de la config ──────────────────────────────────────────────────────
info "Lecture de ${CONFIG_FILE}"
echo ""

while IFS= read -r line <&3 || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue

  read -r uuid mapper mountpoint <<< "$line"

  if [[ -z "$uuid" || -z "$mapper" || -z "$mountpoint" ]]; then
    warn "Ligne malformée ignorée : ${line}"
    continue
  fi

  if [[ -n "$FILTER_UUID" && "$uuid" != "$FILTER_UUID" ]]; then
    info "Filtre actif : entrée ignorée (UUID : ${uuid})"
    continue
  fi

  info "Entrée trouvée : mapper=${mapper}  point=${mountpoint}  uuid=${uuid}"
  mount_entry "$uuid" "$mapper" "$mountpoint"

done 3< "$CONFIG_FILE"

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
info "Résumé : ${count_mounted} monté(s), ${count_skipped} déjà monté(s), ${count_absent} absent(s)"
