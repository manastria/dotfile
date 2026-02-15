# Désactivation de FASD & FZF : `mkdir -p ~/.config && touch ~/.config/no_advanced_nav`

# ------------------------------------------------------------------
# Configuration FASD & FZF
# ------------------------------------------------------------------

# 1. Vérification "Sentinel" : Si ce fichier existe, on arrête tout.
# Utile pour vos machines très lentes. Créez juste ce fichier vide sur la machine concernée.
if [ -f "$HOME/.config/no_advanced_nav" ]; then
    return
fi

# 2. Vérification de présence : Si les binaires ne sont pas là, on ne fait rien.
if ! command -v fzf >/dev/null 2>&1 || ! command -v fasd >/dev/null 2>&1; then
    return
fi

# ------------------------------------------------------------------
# Chargement FZF (Compatible Bash/Zsh)
# ------------------------------------------------------------------
# On détecte le shell courant pour charger le bon fichier de config FZF existant
if [ -n "$BASH_VERSION" ]; then
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash
elif [ -n "$ZSH_VERSION" ]; then
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# ------------------------------------------------------------------
# Chargement FASD
# ------------------------------------------------------------------
eval "$(fasd --init auto)"

# ------------------------------------------------------------------
# Les fonctions "Magiques" (Le cœur de votre productivité)
# ------------------------------------------------------------------

# Fonction 'v' : Ouvre un fichier récent
v() {
    local file
    file="$(fasd -f -l "$@" | fzf --height 40% --reverse --query="$*" --select-1 --exit-0)"
    [ -n "$file" ] && ${EDITOR:-vim} "$file"
}

# Fonction 'z' : Change de dossier (remplace le z par défaut de fasd)
# Nécessite un unalias préalable au cas où fasd l'aurait défini
unalias z 2>/dev/null
z() {
    if [ $# -eq 0 ]; then
        local dir
        dir="$(fasd -d -l | fzf --height 40% --reverse --cycle)" && cd "$dir"
    else
        local dir
        dir="$(fasd -d -l "$@" | fzf --height 40% --reverse --cycle --query="$*" --select-1 --exit-0)"
        [ -d "$dir" ] && cd "$dir"
    fi
}
