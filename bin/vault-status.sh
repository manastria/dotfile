#!/usr/bin/env bash
set -euo pipefail

MAP_NAME="vault_prof"
MNT="$HOME/Vault"

BINDS=(
  "$MNT/browser/vivaldi-prof|$HOME/.config/vivaldi"
  "$MNT/browser/brave-prof|$HOME/.config/BraveSoftware/Brave-Browser"
)

hr() { printf '%s\n' "------------------------------------------------------------"; }

echo "vault-status"
hr

if [[ -e "/dev/mapper/$MAP_NAME" ]]; then
  echo "LUKS : OUVERT  (/dev/mapper/$MAP_NAME)"
else
  echo "LUKS : FERME"
fi

if mountpoint -q "$MNT"; then
  echo "Vault : MONTE  ($MNT)"
  findmnt -rn -o SOURCE,FSTYPE,OPTIONS --mountpoint "$MNT" || true
else
  echo "Vault : DEMONTE ($MNT)"
fi

hr
echo "Binds :"
hr

for pair in "${BINDS[@]}"; do
  IFS='|' read -r SRC DST <<< "$pair"

  if [[ ! -d "$DST" ]]; then
    echo "- $DST : ABSENT (attendu -> $SRC)"
    continue
  fi

  if mountpoint -q "$DST"; then
    real_src="$(findmnt -rn -o SOURCE --mountpoint "$DST" | head -n1)"
    echo "- $DST : MONTE (source -> $real_src)"
  else
    echo "- $DST : DEMONTE (attendu -> $SRC)"
  fi
done

hr
