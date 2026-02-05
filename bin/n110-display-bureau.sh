#!/usr/bin/env bash
set -euo pipefail

# Mode BUREAU
# - DP-1 : écran principal (2560x1440)
# - DP-2 : maximisé (1920x1080)
# - HDMI-1 (VP) : désactivé

PRIMARY="DP-1"
SECOND="DP-2"
PROJECTOR="HDMI-1"

PRIMARY_MODE="2560x1440"
SECOND_MODE="1920x1080"
SECOND_POS="2560x0"  # à droite de DP-1

xrandr \
  --output "$PRIMARY"   --mode "$PRIMARY_MODE" --primary --pos 0x0 --rotate normal \
  --output "$SECOND"    --mode "$SECOND_MODE"  --pos "$SECOND_POS" --rotate normal \
  --output "$PROJECTOR" --off

xrandr --listmonitors
