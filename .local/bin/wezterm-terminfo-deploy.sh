#!/usr/bin/env bash
# wezterm-terminfo-deploy — déploie l'entrée terminfo wezterm sur une machine distante
# Usage : wezterm-terminfo-deploy user@machine
#
# WezTerm n'a pas de sous-commande pour exporter son terminfo : on télécharge
# le fichier source officiel en local et tic -x - le compile dans ~/.terminfo/
# sur la machine distante. WezTerm n'a besoin d'être installé nulle part.

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $(basename "$0") user@machine" >&2
  exit 1
fi

TARGET="$1"

echo "Déploiement du terminfo wezterm sur ${TARGET}…"
curl -fsSL https://raw.githubusercontent.com/wezterm/wezterm/main/termwiz/data/wezterm.terminfo \
  | ssh "$TARGET" 'tic -x - && echo "terminfo wezterm installé dans ~/.terminfo/"'
