#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# XFCE / Xubuntu - Workspaces + keybindings (xfconf)
# - Configure 4 workspaces (1x4) with names
# - Keep tiling on Super+Arrows
# - Use Ctrl+Alt+Left/Right for workspace navigation
# - Use Ctrl+Alt+Shift+Left/Right to move window to prev/next workspace
# - Ensure Whisker is NOT bound to Super_L / Super_R (prevents focus stealing)
# - Bind Whisker to Ctrl+Esc (optional but handy)
# ------------------------------------------------------------

# ---- Settings you may want to change ----
WORKSPACE_COUNT=4
WORKSPACE_ROWS=1   # 1 => 1x4 (simple). 2 => 2x2 if you prefer
WORKSPACE_NAMES=("Cours" "Terminal" "Code" "Réseau")

# Whisker menu shortcut (recommended): Ctrl+Esc
WHISKER_SHORTCUT="<Primary>Escape"
WHISKER_COMMAND="xfce4-popup-whiskermenu"

# If you want the classic applications menu on Alt+F1 (often already there)
APPSMENU_SHORTCUT="<Alt>F1"
APPSMENU_COMMAND="xfce4-popup-applicationsmenu"

# ---- Helpers ----
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }

set_int() {
  local channel="$1" prop="$2" value="$3"
  if xfconf-query -c "$channel" -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$prop" -s "$value"
  else
    xfconf-query -c "$channel" -p "$prop" -n -t int -s "$value"
  fi
}

set_str() {
  local channel="$1" prop="$2" value="$3"
  if xfconf-query -c "$channel" -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$prop" -s "$value"
  else
    xfconf-query -c "$channel" -p "$prop" -n -t string -s "$value"
  fi
}

set_str_array() {
  # Usage: set_str_array channel prop "a" "b" "c"
  local channel="$1" prop="$2"; shift 2
  # Always recreate the array to avoid leftovers
  xfconf-query -c "$channel" -p "$prop" -r >/dev/null 2>&1 || true
  # Build: -t string -s "..." (repeated) + -a for array
  local args=()
  for v in "$@"; do
    args+=(-t string -s "$v")
  done
  xfconf-query -c "$channel" -p "$prop" -n -a "${args[@]}"
}

set_key() {
  # Keybinding for xfwm4 in channel xfce4-keyboard-shortcuts
  # Example: set_key "/xfwm4/custom/<Super>Left" "tile_left_key"
  local prop="$1" action="$2"
  if xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -s "$action"
  else
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -n -t string -s "$action"
  fi
}

set_command_shortcut() {
  # Example: set_command_shortcut "/commands/custom/<Primary>Escape" "xfce4-popup-whiskermenu"
  local prop="$1" cmd="$2"
  if xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -s "$cmd"
  else
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -n -t string -s "$cmd"
  fi
}

remove_key_if_exists() {
  local channel="$1" prop="$2"
  xfconf-query -c "$channel" -p "$prop" -r >/dev/null 2>&1 || true
}

backup_xfce_conf() {
  local stamp dest
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="$HOME/xfce-backup-$stamp"
  mkdir -p "$dest"
  cp -a "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml" "$dest/" 2>/dev/null || true
  echo "Backup: $dest/xfce-perchannel-xml"
}

reload_session_bits() {
  # These reloads are safe; you can always log out/in instead.
  xfce4-panel -r >/dev/null 2>&1 || true
  xfwm4 --replace >/dev/null 2>&1 & disown || true
}

# ---- Main ----
need_cmd xfconf-query
backup_xfce_conf

echo "1) Configure workspaces (xfwm4 channel)"
set_int xfwm4 /general/workspace_count "$WORKSPACE_COUNT"
set_int xfwm4 /general/workspace_rows "$WORKSPACE_ROWS"

# Workspace names: only if count matches
if [ "${#WORKSPACE_NAMES[@]}" -ge "$WORKSPACE_COUNT" ]; then
  set_str_array xfwm4 /general/workspace_names "${WORKSPACE_NAMES[@]:0:$WORKSPACE_COUNT}"
fi

echo "2) Tiling shortcuts (Super+Arrows) - xfwm4 keybindings"
set_key "/xfwm4/custom/<Super>Left"  "tile_left_key"
set_key "/xfwm4/custom/<Super>Right" "tile_right_key"
set_key "/xfwm4/custom/<Super>Up"    "tile_up_key"
set_key "/xfwm4/custom/<Super>Down"  "tile_down_key"

echo "3) Workspace navigation shortcuts (Ctrl+Alt+Left/Right)"
# These action names are standard in xfwm4; if your XFCE is unusual, they may be ignored.
set_key "/xfwm4/custom/<Primary><Alt>Left"  "prev_workspace_key"
set_key "/xfwm4/custom/<Primary><Alt>Right" "next_workspace_key"

echo "4) Move current window to prev/next workspace (Ctrl+Alt+Shift+Left/Right)"
set_key "/xfwm4/custom/<Primary><Alt><Shift>Left"  "move_window_prev_workspace_key"
set_key "/xfwm4/custom/<Primary><Alt><Shift>Right" "move_window_next_workspace_key"

echo "5) Whisker menu: bind to Ctrl+Esc, and neutralize Super_L/Super_R stealing focus"
set_command_shortcut "/commands/custom/${WHISKER_SHORTCUT}" "$WHISKER_COMMAND"

# Optional: keep Alt+F1 for applications menu
set_command_shortcut "/commands/custom/${APPSMENU_SHORTCUT}" "$APPSMENU_COMMAND"

# Remove any custom binding on "<Super>" (rare, but can exist)
remove_key_if_exists xfce4-keyboard-shortcuts "/commands/custom/<Super>"

# Neutralize default Super_L / Super_R by overriding them with empty strings in custom.
# This prevents Whisker from popping up when you tap Super alone.
set_command_shortcut "/commands/custom/Super_L" ""
set_command_shortcut "/commands/custom/Super_R" ""

echo "6) Reload panel + window manager"
reload_session_bits

echo "Done."
echo "If something feels inconsistent, log out / log in once."
