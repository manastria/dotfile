#!/usr/bin/env bash
set -euo pipefail

IMG="$HOME/vault.img"
MAP_NAME="vault_prof"
MNT="$HOME/Vault"
USER_GRP="$(id -gn)"

# "SOURCE_DANS_VAULT|CIBLE"
BINDS=(
  "$MNT/browser/vivaldi-prof|$HOME/.config/vivaldi"
  "$MNT/browser/brave-prof|$HOME/.config/BraveSoftware/Brave-Browser"

  "$MNT/browser/firefox/mozilla-firefox|$HOME/snap/firefox/common/.mozilla/firefox"
  "$MNT/browser/firefox/cache-firefox|$HOME/snap/firefox/common/.cache/mozilla/firefox"
)


die() { echo "ERREUR: $*" >&2; exit 1; }

[[ -f "$IMG" ]] || die "Conteneur introuvable: $IMG"
mkdir -p "$MNT"

# Ouvrir LUKS si nécessaire
if [[ ! -e "/dev/mapper/$MAP_NAME" ]]; then
  sudo cryptsetup open "$IMG" "$MAP_NAME"
fi

# Monter le volume si nécessaire
if ! mountpoint -q "$MNT"; then
  sudo mount "/dev/mapper/$MAP_NAME" "$MNT"
  sudo chown -R "$USER:$USER_GRP" "$MNT"
fi

# Monter les bind mounts
for pair in "${BINDS[@]}"; do
  IFS='|' read -r SRC DST <<< "$pair"

  mkdir -p "$SRC"
  mkdir -p "$DST"

  if mountpoint -q "$DST"; then
    echo "Bind déjà monté: $DST"
    continue
  fi

  sudo mount --bind "$SRC" "$DST"
  echo "Bind OK: $SRC -> $DST"
done

echo "OK: Vault ouvert, monté sur $MNT, binds en place."
