# Atuin DOIT arriver après Starship
if command -v atuin >/dev/null 2>&1; then
  # Optionnel : si tu veux garder la flèche ↑ native Bash, ajoute --disable-up-arrow
  eval "$(atuin init bash)"
fi
