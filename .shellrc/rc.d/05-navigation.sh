# Désactivation de zoxide & fzf : `mkdir -p ~/.config && touch ~/.config/no_advanced_nav`

# ------------------------------------------------------------------
# Configuration zoxide & fzf
# ------------------------------------------------------------------

# 1. Vérification "Sentinel" : Si ce fichier existe, on arrête tout.
# Utile pour les machines très lentes. Créez ce fichier vide sur la machine concernée.
if [ -f "$HOME/.config/no_advanced_nav" ]; then
    return
fi

# 2. Chargement fzf (Compatible Bash/Zsh) — optionnel, indépendant de zoxide
if command -v fzf >/dev/null 2>&1; then
    if [ -n "$BASH_VERSION" ]; then
        [ -f ~/.fzf.bash ] && source ~/.fzf.bash
    elif [ -n "$ZSH_VERSION" ]; then
        [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    fi
fi

# 3. Chargement zoxide (fournit les commandes z et zi)
if command -v zoxide >/dev/null 2>&1; then
    if [ -n "$BASH_VERSION" ]; then
        eval "$(zoxide init bash)"
    elif [ -n "$ZSH_VERSION" ]; then
        eval "$(zoxide init zsh)"
    fi
fi

# ------------------------------------------------------------------
# Fonction 'v' : Ouvre un fichier dans $EDITOR via fzf + fd (requiert fzf)
# ------------------------------------------------------------------
# Usage : v          → recherche floue dans le répertoire courant
#         v motif    → pré-filtre sur le motif
if command -v fzf >/dev/null 2>&1; then
    v() {
        local file
        file="$(fdfind -H --type f . 2>/dev/null \
            | fzf --height 40% --reverse --query="${*:-}" --select-1 --exit-0)"
        [ -n "$file" ] && ${EDITOR:-vim} "$file"
    }
fi
