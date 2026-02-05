#!/usr/bin/env bash
set -euo pipefail

MAP_NAME="vault_prof"
MNT="$HOME/Vault"

BIND_TARGETS=(
  "$HOME/.config/vivaldi"
  "$HOME/.config/BraveSoftware/Brave-Browser"

  "$HOME/snap/firefox/common/.mozilla/firefox"
  "$HOME/snap/firefox/common/.cache/mozilla/firefox"
)

PROCS=(vivaldi brave brave-browser firefox firefox-bin)

echo "Fermeture des navigateurs..."
for p in "${PROCS[@]}"; do
  pkill -x "$p" 2>/dev/null || true
done

echo "Démontage des binds..."
for ((i=${#BIND_TARGETS[@]}-1; i>=0; i--)); do
  dst="${BIND_TARGETS[$i]}"

  # Si le dossier n'existe pas, on ignore
  [[ -d "$dst" ]] || { echo "Skip (absent): $dst"; continue; }

  # Si ce n'est pas un point de montage, on ignore
  if ! mountpoint -q "$dst"; then
    echo "Skip (pas un mountpoint): $dst"
    continue
  fi

  sudo umount "$dst" 2>/dev/null || true
  echo "Bind démonté: $dst"
done

echo "Démontage du Vault..."
if mountpoint -q "$MNT"; then
  sudo umount "$MNT" 2>/dev/null || true
  echo "Vault démonté: $MNT"
else
  echo "Skip (Vault pas monté): $MNT"
fi

echo "Fermeture de LUKS..."
if [[ -e "/dev/mapper/$MAP_NAME" ]]; then
  sudo cryptsetup close "$MAP_NAME" 2>/dev/null || true
  echo "LUKS fermé: $MAP_NAME"
else
  echo "Skip (LUKS déjà fermé): $MAP_NAME"
fi

echo "OK: Vault fermé."
