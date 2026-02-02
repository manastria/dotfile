#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# XFCE / Xubuntu - Workspaces + keybindings (xfconf)
# - Configure 4 workspaces (1x4) with names
# - Tiling: Super+Arrows
# - Workspace nav: Ctrl+Alt+Left/Right
# - Move window to prev/next: Ctrl+Alt+Shift+Left/Right
# - Direct workspaces (AZERTY): Super + & é " '  => workspace 1..4
# - Move window to workspace: Shift+Super+1..4 => move_window_workspace_1..4
# - Ensure Whisker is NOT bound to Super_L / Super_R
# ------------------------------------------------------------
# Pour voir la liste des raccourcis: `xfconf-query -c xfce4-keyboard-shortcuts -lv`

WORKSPACE_COUNT=4
WORKSPACE_ROWS=1
WORKSPACE_NAMES=("Cours" "Terminal" "Code" "Réseau")

WHISKER_SHORTCUT="<Primary>Escape"
WHISKER_COMMAND="xfce4-popup-whiskermenu"

APPSMENU_SHORTCUT="<Alt>F1"
APPSMENU_COMMAND="xfce4-popup-applicationsmenu"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }

set_int() {
  local channel="$1" prop="$2" value="$3"
  if xfconf-query -c "$channel" -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$prop" -s "$value"
  else
    xfconf-query -c "$channel" -p "$prop" -n -t int -s "$value"
  fi
}

set_str_array() {
  local channel="$1" prop="$2"; shift 2
  xfconf-query -c "$channel" -p "$prop" -r >/dev/null 2>&1 || true
  local args=()
  for v in "$@"; do
    args+=(-t string -s "$v")
  done
  xfconf-query -c "$channel" -p "$prop" -n -a "${args[@]}"
}

set_key() {
  local prop="$1" action="$2"
  if xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -s "$action"
  else
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -n -t string -s "$action"
  fi
}

set_command_shortcut() {
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
  xfce4-panel -r >/dev/null 2>&1 || true
  xfwm4 --replace >/dev/null 2>&1 & disown || true
}

need_cmd xfconf-query
backup_xfce_conf

echo "1) Workspaces"
set_int xfwm4 /general/workspace_count "$WORKSPACE_COUNT"
set_int xfwm4 /general/workspace_rows "$WORKSPACE_ROWS"
if [ "${#WORKSPACE_NAMES[@]}" -ge "$WORKSPACE_COUNT" ]; then
  set_str_array xfwm4 /general/workspace_names "${WORKSPACE_NAMES[@]:0:$WORKSPACE_COUNT}"
fi

echo "2) Tiling (Super+Arrows)"
set_key "/xfwm4/custom/<Super>Left"  "tile_left_key"
set_key "/xfwm4/custom/<Super>Right" "tile_right_key"
set_key "/xfwm4/custom/<Super>Up"    "tile_up_key"
set_key "/xfwm4/custom/<Super>Down"  "tile_down_key"

echo "3) Workspace navigation (Ctrl+Alt+Left/Right)"
set_key "/xfwm4/custom/<Primary><Alt>Left"  "prev_workspace_key"
set_key "/xfwm4/custom/<Primary><Alt>Right" "next_workspace_key"

echo "4) Move window to prev/next workspace (Ctrl+Alt+Shift+Left/Right)"
set_key "/xfwm4/custom/<Primary><Alt><Shift>Left"  "move_window_prev_workspace_key"
set_key "/xfwm4/custom/<Primary><Alt><Shift>Right" "move_window_next_workspace_key"

echo "5) Direct workspaces (AZERTY): Super + & é \" '"
# AZERTY keysyms for the top row (unshifted):
# 1 -> ampersand (&), 2 -> eacute (é), 3 -> quotedbl ("), 4 -> apostrophe (')
# This matches what you showed in xfconf:
# /xfwm4/custom/<Super>ampersand workspace_1_key etc.
set_key "/xfwm4/custom/<Super>ampersand"  "workspace_1_key"
set_key "/xfwm4/custom/<Super>eacute"     "workspace_2_key"
set_key "/xfwm4/custom/<Super>quotedbl"   "workspace_3_key"
set_key "/xfwm4/custom/<Super>apostrophe" "workspace_4_key"

echo "6) Send window to workspace: Shift+Super+1..4"
# XFCE stores these as <Shift><Super>1..4 in your configuration.
set_key "/xfwm4/custom/<Shift><Super>1" "move_window_workspace_1_key"
set_key "/xfwm4/custom/<Shift><Super>2" "move_window_workspace_2_key"
set_key "/xfwm4/custom/<Shift><Super>3" "move_window_workspace_3_key"
set_key "/xfwm4/custom/<Shift><Super>4" "move_window_workspace_4_key"

echo "7) Whisker menu: Ctrl+Esc, and neutralize Super_L/Super_R"
set_command_shortcut "/commands/custom/${WHISKER_SHORTCUT}" "$WHISKER_COMMAND"
set_command_shortcut "/commands/custom/${APPSMENU_SHORTCUT}" "$APPSMENU_COMMAND"

remove_key_if_exists xfce4-keyboard-shortcuts "/commands/custom/<Super>"
set_command_shortcut "/commands/custom/Super_L" ""
set_command_shortcut "/commands/custom/Super_R" ""


echo "8) Divers"
echo "   Lock Screen : Super+L au lieu de Ctrl+Alt+L"
# On libère le raccourci par défaut dans xfwm4 (le gestionnaire de fenêtres)
remove_key_if_exists xfce4-keyboard-shortcuts "/commands/custom/<Primary><Alt>l"

# On affecte Super+L à la commande de verrouillage
set_command_shortcut "/commands/custom/<Super>l" "xflock4"

remove_key_if_exists xfce4-keyboard-shortcuts "/commands/custom/<Primary><Alt>t"
set_command_shortcut "/commands/custom/<Super>t" "exo-open --launch TerminalEmulator"

remove_key_if_exists xfce4-keyboard-shortcuts "/commands/custom/<Primary><Alt>f"
remove_key_if_exists xfce4-keyboard-shortcuts "/commands/custom/<Super>f"


echo "9) Reload"
reload_session_bits

# Suppression de quelques raccourcis clavier gênants par défaut
echo "9) Remove annoying default shortcuts"
# Supprimer CTRL+F12
remove_key_if_exists xfce4-keyboard-shortcuts "/xfwm4/custom/<Primary>F12"

echo "Configuration du clavier"

xfconf-query -c keyboard-layout -p /Default/XkbDisable -s false
xfconf-query -c keyboard-layout -p /Default/XkbLayout  -s fr --create -t string
xfconf-query -c keyboard-layout -p /Default/XkbVariant -s oss --create -t string


# Application immédiate
setxkbmap fr oss

echo "9) Application de la personnalisation .Xmodmap"
if [ -f "$HOME/.Xmodmap" ]; then
  xmodmap "$HOME/.Xmodmap"
  echo "Fichier .Xmodmap chargé avec succès."
else
  echo "Note : Aucun fichier .Xmodmap trouvé dans $HOME."
fi

echo "Done. If needed, log out / log in once."
