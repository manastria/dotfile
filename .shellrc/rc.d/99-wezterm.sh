# wezterm.zsh — fallback TERM pour machines distantes sans terminfo wezterm
# Chargé depuis ~/.shellrc/zshrc.d/

if [[ "$TERM" == "wezterm" ]] && ! infocmp wezterm &>/dev/null; then
  export TERM=xterm-256color
fi
