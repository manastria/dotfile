# --- pyenv (init robuste & idempotent) ------------------------------
# Dossier d'installation par défaut
export PYENV_ROOT="$HOME/.pyenv"

# Ajoute $PYENV_ROOT/bin au PATH une seule fois
case ":$PATH:" in
  *":$PYENV_ROOT/bin:"*) : ;;
  *) export PATH="$PYENV_ROOT/bin:$PATH" ;;
esac

# Si pyenv est disponible, on l'initialise proprement
if command -v pyenv >/dev/null 2>&1; then
  # Initialise les shims, hooks, etc. (à garder dans ~/.bashrc)
  eval "$(pyenv init -)"

  # Active pyenv-virtualenv *seulement si le plugin est installé*
  if pyenv commands 2>/dev/null | grep -qx 'virtualenv-init'; then
    eval "$(pyenv virtualenv-init -)"
  fi
fi
# --------------------------------------------------------------------
