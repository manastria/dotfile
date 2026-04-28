# -*- mode: shell-script -*-
# Fonction zenv : lancer zsh avec un profil powerlevel10k
# Usage : zenv <profil> [--tmux|-t]
# Sans argument : affiche les profils disponibles

zenv() {
    local profil=""
    local use_tmux=0

    # Analyse des arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --tmux|-t)
                use_tmux=1
                ;;
            -*)
                echo "Option inconnue : $1" >&2
                return 1
                ;;
            *)
                profil="$1"
                ;;
        esac
        shift
    done

    # Sans argument : lister les profils disponibles
    if [ -z "$profil" ]; then
        echo "Profils disponibles :"
        echo "  base    - Configuration minimale (sans oh-my-zsh)"
        echo "  light   - Pure prompt + autosuggestions + syntax-highlighting (sans oh-my-zsh)"
        echo "  omz     - oh-my-zsh sans powerlevel10k"
        for f in "${HOME}"/.zsh/powerlevel10k/p10k.zsh.*; do
            if [ -f "$f" ]; then
                echo "  ${f##*.}"
            fi
        done
        echo ""
        echo "Usage : zenv <profil> [--tmux|-t]"
        return 0
    fi

    # Vérifier que le profil existe (sauf base et omz)
    if [ "$profil" != "base" ] && [ "$profil" != "light" ] && [ "$profil" != "omz" ]; then
        local pfile="${HOME}/.zsh/powerlevel10k/p10k.zsh.${profil}"
        if [ ! -f "$pfile" ]; then
            echo "Erreur : profil '${profil}' introuvable (${pfile})" >&2
            echo "Utilisez 'zenv' sans argument pour voir les profils disponibles." >&2
            return 1
        fi
    fi

    # Lancer zsh avec ou sans tmux
    if [ "$use_tmux" -eq 1 ]; then
        TERM=xterm-256color ZSH_PROFILE="$profil" tmux
    else
        TERM=xterm-256color ZSH_PROFILE="$profil" zsh -i
    fi
}

# Alias sémantiques
alias zsh-daily='zenv simple --tmux'
alias zsh-remote='zenv ssh --tmux'
alias zsh-writer='zenv writer --tmux'
alias zsh-minimal='zenv base'

# Connexion SSH avec tmux et profil zsh sur la machine distante
# Usage : zssh [-e profil] [options ssh...] hôte
zssh() {
    local profil="ssh"

    # Extraire le profil si spécifié
    case "$1" in
        --profile|-e)
            profil="$2"
            shift 2
            ;;
    esac

    if [ $# -eq 0 ]; then
        echo "Usage : zssh [-e profil] [options ssh...] hôte" >&2
        echo "Profil par défaut : ssh" >&2
        return 1
    fi

    # -t : force l'allocation d'un pseudo-terminal (requis pour tmux)
    # new-session -A -s main : crée ou rattache la session "main"
    ssh -t "$@" "TERM=xterm-256color ZSH_PROFILE='${profil}' tmux new-session -A -s main"
}
