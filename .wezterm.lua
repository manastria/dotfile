local wezterm = require 'wezterm'
local config = wezterm.config_builder()

---------------------------------------
-- SECTION 1 : SHELL PAR DÉFAUT
---------------------------------------
config.default_prog = { '/bin/zsh' }

---------------------------------------
-- SECTION 2 : POLICE
---------------------------------------
-- JetBrains Mono comme police principale
-- FiraMono Nerd Font en fallback pour les glyphes Nerd Font (starship, eza…)
config.font = wezterm.font_with_fallback {
  'FiraMono Nerd Font',
  'JetBrains Mono',
}
config.font_size = 11.0

---------------------------------------
-- SECTION 3 : THÈME & BASCULE LIGHT/DARK
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
-- SECTION 4 : TERMINAL (TERM)
---------------------------------------
-- Utilise 'wezterm' si le terminfo est installé (voir install-wezterm.sh),
-- sinon retombe sur xterm-256color.
-- Le test est fait côté Lua en appelant infocmp via le shell.
if os.execute('infocmp wezterm > /dev/null 2>&1') then
  config.term = 'wezterm'
else
  config.term = 'xterm-256color'
end

---------------------------------------
-- SECTION 5 : APPARENCE
---------------------------------------
config.window_background_opacity = 0.95

-- Barre de titre + poignées de redimensionnement fournies par le système
-- ('NONE' supprimerait aussi le redimensionnement à la souris)
config.window_decorations = 'TITLE | RESIZE'

-- Padding intérieur
config.window_padding = {
  left = 4, right = 4, top = 4, bottom = 4,
}

-- Historique de défilement
config.scrollback_lines = 10000

-- Pas de barre de défilement (tmux gère déjà son propre scrollback)
config.enable_scroll_bar = false

---------------------------------------
-- SECTION 6 : RACCOURCIS CLAVIER
---------------------------------------
config.keys = {
  -- Bascule light/dark (vidéoprojecteur)
  {
    key = 'F5',
    mods = 'NONE',
    action = wezterm.action.EmitEvent 'toggle-theme',
  },
  -- Saute au prompt précédent / suivant (nécessite l'intégration shell,
  -- voir .shellrc/zshrc.d/99-wezterm.zsh)
  { key = 'UpArrow',   mods = 'CTRL|SHIFT', action = wezterm.action.ScrollToPrompt(-1) },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = wezterm.action.ScrollToPrompt(1)  },
}

---------------------------------------
-- SECTION 7 : SOURIS
---------------------------------------
-- Copie à la sélection : au relâchement du bouton gauche, la sélection (1 clic
-- = glisser, 2 = mot, 3 = ligne) va dans le presse-papiers ET la sélection
-- primaire. Sous tmux (souris active), c'est tmux qui sélectionne ; Maj + glisser
-- rend la main à WezTerm.
local copy_on_select = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection'

config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE', action = copy_on_select },
  { event = { Up = { streak = 2, button = 'Left' } }, mods = 'NONE', action = copy_on_select },
  { event = { Up = { streak = 3, button = 'Left' } }, mods = 'NONE', action = copy_on_select },
  -- Clic milieu : colle le presse-papiers
  {
    event  = { Down = { streak = 1, button = 'Middle' } },
    mods   = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Caractères qui délimitent un « mot » lors d'un double-clic de sélection
config.selection_word_boundary = ' \t\n{}[]()"\',;:'

---------------------------------------
-- SECTION 8 : ENCODAGE CLAVIER
---------------------------------------
-- Active l'encodage CSI-u : permet aux applications (vim, tmux…) de
-- distinguer des combinaisons comme Ctrl+Maj+lettre ou Ctrl+I / Tab.
config.enable_csi_u_key_encoding = true









-- Active la barre d'onglets pour afficher le statut à droite
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false

wezterm.on('update-status', function(window, pane)
  -- 1. Récupération de la taille de police courante
  local font_size = window:effective_config().font_size

  -- 2. Récupération des dimensions du panneau actif (colonnes x lignes)
  local dims = pane:get_dimensions()
  local cols = dims.cols
  local rows = dims.viewport_rows

  -- 3. Détection du contexte (SSH / tmux / local)
  local domain_name = pane:get_domain_name()
  local title = pane:get_title()

  local context_tag = "LOCAL"
  if domain_name and domain_name ~= "local" then
    context_tag = "SSH: " .. domain_name
  elseif title:find("ssh") then
    context_tag = "SSH"
  elseif title:find("tmux") then
    context_tag = "TMUX"
  end

  -- 4. Formatage visuel avec couleurs sobres
  window:set_right_status(wezterm.format({
    { Foreground = { Color = '#89b4fa' } },
    { Text = ' ' .. context_tag .. ' ' },
    { Foreground = { Color = '#6c7086' } },
    { Text = '|' },

    { Foreground = { Color = '#fab387' } },
    { Text = string.format(' %d×%d ', cols, rows) },
    { Foreground = { Color = '#6c7086' } },
    { Text = '|' },

    { Foreground = { Color = '#a6e3a1' } },
    { Text = string.format(' %.1f pt ', font_size) },
  }))
end)


return config
