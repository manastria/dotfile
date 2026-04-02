#!/usr/bin/env bash
# wezterm-terminfo-deploy — déploie l'entrée terminfo wezterm sur une machine distante
# Usage : wezterm-terminfo-deploy user@machine
#
# La commande wezterm tcl génère l'entrée terminfo de WezTerm.
# tic -x - l'installe dans ~/.terminfo/ sur la machine distante.
# WezTerm n'a pas besoin d'être installé sur la machine distante.

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $(basename "$0") user@machine" >&2
  exit 1
fi

if ! command -v wezterm &>/dev/null; then
  echo "Erreur : wezterm n'est pas installé sur cette machine." >&2
  exit 1
fi

TARGET="$1"

echo "Déploiement du terminfo wezterm sur ${TARGET}…"
wezterm tcl | ssh "$TARGET" 'tic -x - && echo "terminfo wezterm installé dans ~/.terminfo/"'
