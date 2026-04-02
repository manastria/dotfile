local wezterm = require 'wezterm'
local config = wezterm.config_builder()

---------------------------------------
-- SECTION 1 : DÉTECTION DE LA PLATEFORME
---------------------------------------
local is_windows = wezterm.target_triple:find('windows') ~= nil
local is_linux   = wezterm.target_triple:find('linux')   ~= nil

---------------------------------------
-- SECTION 2 : SHELL & PROGRAMME PAR DÉFAUT
---------------------------------------
local launch_menu = {}

if is_windows then
  table.insert(launch_menu, { label = 'Linux (WSL)',  args = { 'wsl.exe' } })
  table.insert(launch_menu, { label = 'Git Bash',     args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login' } })
  table.insert(launch_menu, { label = 'PowerShell',   args = { 'powershell.exe', '-NoLogo' } })
  config.default_prog = { 'wsl.exe' }
end

if is_linux then
  config.default_prog = { '/bin/zsh' }
end

config.launch_menu = launch_menu

---------------------------------------
-- SECTION 3 : POLICE
---------------------------------------
-- JetBrains Mono comme police principale
-- FiraMono Nerd Font en fallback pour les glyphes Nerd Font (starship, eza…)
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'FiraMono Nerd Font',
}
config.font_size = 11.0

---------------------------------------
-- SECTION 4 : THÈME & BASCULE LIGHT/DARK
---------------------------------------
local theme_dark  = 'Night Owl (Gogh)'
local theme_light = 'One Light (Gogh)'

-- Thème dark par défaut
config.color_scheme = theme_dark

-- Bascule light/dark avec F5
-- Utile en classe lors du passage au vidéoprojecteur
wezterm.on('toggle-theme', function(window)
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme == theme_light then
    overrides.color_scheme = theme_dark
  else
    overrides.color_scheme = theme_light
  end
  window:set_config_overrides(overrides)
end)

---------------------------------------
-- SECTION 5 : TERMINAL & COMPATIBILITÉ TMUX
---------------------------------------
-- Utilise wezterm si le terminfo est disponible, sinon xterm-256color
-- Détection côté Lua : on tente une commande shell
local terminfo_wezterm = os.execute('infocmp wezterm > /dev/null 2>&1')
if terminfo_wezterm then
  config.term = 'wezterm'
else
  config.term = 'xterm-256color'
end

---------------------------------------
-- SECTION 6 : APPARENCE
---------------------------------------
config.window_background_opacity = 0.95

-- Décore la fenêtre selon la plateforme
if is_linux then
  -- Laisse le gestionnaire de fenêtres gérer les décorations
  config.window_decorations = 'NONE'
end

-- Padding intérieur
config.window_padding = {
  left = 4, right = 4, top = 4, bottom = 4,
}

-- Scrollback
config.scrollback_lines = 10000

---------------------------------------
-- SECTION 7 : KEYBINDS
---------------------------------------
config.keys = {
  -- Bascule light/dark (vidéoprojecteur)
  {
    key = 'F5',
    mods = 'NONE',
    action = wezterm.action.EmitEvent 'toggle-theme',
  },
  -- Lance le menu de lancement (fuzzy)
  {
    key = 'L',
    mods = 'ALT',
    action = wezterm.action.ShowLauncherArgs {
      flags = 'FUZZY|LAUNCH_MENU_ITEMS',
    },
  },
  { key = 'UpArrow',   mods = 'CTRL|SHIFT', action = wezterm.action.ScrollToPrompt(-1) },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = wezterm.action.ScrollToPrompt(1)  },
}

---------------------------------------
-- SECTION 8 : SOURIS
---------------------------------------
-- Clic milieu → colle depuis le presse-papiers
config.mouse_bindings = {
  {
    event  = { Down = { streak = 1, button = 'Middle' } },
    mods   = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Copie automatique à la sélection (équivalent copy-on-select)
config.selection_word_boundary = ' \t\n{}[]()"\',;:'

---------------------------------------
-- SECTION 9 : INTÉGRATION TMUX
---------------------------------------
-- WezTerm détecte automatiquement tmux et adapte certains comportements.
-- On désactive les features WezTerm qui entrent en conflit avec tmux :

-- Pas de scroll natif WezTerm si tmux gère le scrollback
config.enable_scroll_bar = false


---------------------------------------
-- SECTION 10 : 
---------------------------------------
config.enable_csi_u_key_encoding = true

return config
