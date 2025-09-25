# Charger Atuin s'il est installé
if command -v atuin &> /dev/null; then
  eval "$(atuin init bash)"
fi

# Retourne toujours un code de sortie 0
return 0 2>/dev/null || true
