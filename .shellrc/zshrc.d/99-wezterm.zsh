# WezTerm shell integration
if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
  source "$(wezterm shell-completion --shell zsh 2>/dev/null)" 2>/dev/null
fi
