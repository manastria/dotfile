# WezTerm shell integration
if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
  # Sur Debian, /etc/zsh/zprofile ne source pas /etc/profile.d/,
  # donc wezterm.sh n'est jamais chargé automatiquement par zsh.
  # On le source ici explicitement pour activer les zones sémantiques,
  # les variables utilisateur et l'OSC 7 (precmd_functions).
  [[ -f /etc/profile.d/wezterm.sh ]] && source /etc/profile.d/wezterm.sh

  # Complétions zsh
  source "$(wezterm shell-completion --shell zsh 2>/dev/null)" 2>/dev/null
fi
