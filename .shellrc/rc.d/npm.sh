# --- npm user prefix (idempotent) ---
if command -v npm >/dev/null 2>&1; then
  NPM_PACKAGES="$HOME/.npm-packages"

  # Crée le dossier au besoin
  if [ ! -d "$NPM_PACKAGES" ]; then
    mkdir -p "$NPM_PACKAGES"
    # Première init du prefix côté npm (silencieux si ça échoue)
    npm config set prefix "$NPM_PACKAGES" >/dev/null 2>&1 || true
  else
    # Si le prefix actuel diffère, aligne-le
    current_prefix="$(npm config get prefix 2>/dev/null || echo '')"
    if [ "$current_prefix" != "$NPM_PACKAGES" ] && [ -n "$current_prefix" ]; then
      npm config set prefix "$NPM_PACKAGES" >/dev/null 2>&1 || true
    fi
  fi

  # Ajoute ~/.npm-packages/bin au PATH (une seule fois). 
  # (append comme dans ton exemple; passe-le en prepend si tu préfères prioriser les binaires user)
  case ":$PATH:" in
    *":$NPM_PACKAGES/bin:"*) : ;;               # déjà présent
    *) PATH="$PATH:$NPM_PACKAGES/bin" ;;
  esac
  export PATH
fi
# --- /npm user prefix ---
