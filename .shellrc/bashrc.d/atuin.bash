# Charger Atuin s'il est installé
if command -v atuin &> /dev/null; then
  eval "$(atuin init bash)"
fi
