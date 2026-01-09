#!/usr/bin/env bash
set -euo pipefail

# Mode COURS
# - DP-1 : écran principal (2560x1440)
# - DP-2 + HDMI-1 (vidéoprojecteur) : miroir, idéalement en 1280x800 (WXGA)
#
# Remarque : le miroir impose la même résolution sur DP-2 et HDMI-1.

PRIMARY="DP-1"
MIRROR_A="DP-2"
MIRROR_B="HDMI-1"

PRIMARY_MODE="2560x1440"
MIRROR_MODE="1280x800"   # recommandé pour Epson EB-W49 (WXGA)
MIRROR_POS="2560x0"      # à droite de DP-1

# Applique la config
xrandr \
  --output "$PRIMARY"  --mode "$PRIMARY_MODE" --primary --pos 0x0 --rotate normal \
  --output "$MIRROR_A" --mode "$MIRROR_MODE"  --pos "$MIRROR_POS" --rotate normal \
  --output "$MIRROR_B" --mode "$MIRROR_MODE"  --same-as "$MIRROR_A" --rotate normal

# Optionnel : affiche un résumé
xrandr --listmonitors
