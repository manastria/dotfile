# -*- mode: shell-script -*-
# Fonction zenv : lancer zsh avec un profil powerlevel10k
# Usage : zenv <profil> [--tmux|-t] [--session|-s nom] [--detach|-d]
# Sans argument : affiche les profils disponibles
#
# Avec tmux, zenv crée la session nommée (défaut : main) ou s'y rattache si elle
# existe déjà (tmux new-session -A). -s implique --tmux.

# Vrai si tmux >= 3.2 : new-session accepte alors -e VAR=val, qui fixe le profil
# dans l'environnement de la session même quand le serveur tmux tourne déjà.
_zenv_tmux_has_env_flag() {
    local v major minor
    v="$(tmux -V 2>/dev/null | sed 's/[^0-9.]//g')"
    major="${v%%.*}"
    minor="${v#*.}"
    [ "$minor" = "$v" ] && minor=0
    [ -n "$major" ] || return 1
    [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "${minor:-0}" -ge 2 ]; }
}

# Crée ou reprend la session tmux : _zenv_tmux <profil> <session> <detach 0|1>
_zenv_tmux() {
    local profil="$1" session="$2" detach="$3"

    # -A : rattache la session si elle existe, la crée sinon
    # -D : détache les autres clients (reprise depuis une autre machine)
    set -- new-session -A -s "$session"
    if [ "$detach" -eq 1 ]; then
        set -- "$@" -D
    fi
    if _zenv_tmux_has_env_flag; then
        set -- "$@" -e "ZSH_PROFILE=${profil}"
    fi

    if [ -n "${TMUX:-}" ]; then
        # Déjà dans tmux : imbriquer est déconseillé, on crée la session en
        # arrière-plan si besoin, puis on y bascule.
        if ! tmux has-session -t "=${session}" 2>/dev/null; then
            _zenv_tmux_has_env_flag \
                || echo "Attention : tmux < 3.2, le profil '${profil}' ne sera pas appliqué à la nouvelle session." >&2
            TERM=xterm-256color ZSH_PROFILE="$profil" tmux "$@" -d || return 1
        fi
        tmux switch-client -t "=${session}"
    else
        # ZSH_PROFILE en préfixe : suffit au premier démarrage du serveur tmux ;
        # -e (ci-dessus) couvre le cas d'un serveur déjà lancé.
        TERM=xterm-256color ZSH_PROFILE="$profil" tmux "$@"
    fi
}

zenv() {
    local profil=""
    local use_tmux=0
    local session="main"
    local detach=0

    # Analyse des arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --tmux|-t)
                use_tmux=1
                ;;
            --session|-s)
                if [ -z "${2:-}" ]; then
                    echo "Option $1 : nom de session manquant" >&2
                    return 1
                fi
                session="$2"
                use_tmux=1
                shift
                ;;
            --detach|-d)
                detach=1
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

    # tmux transforme '.' et ':' en '_' dans les noms de session : on les refuse
    case "$session" in
        *.*|*:*)
            echo "Nom de session invalide : '${session}' ('.' et ':' interdits)" >&2
            return 1
            ;;
    esac

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
        echo "Usage : zenv <profil> [--tmux|-t] [--session|-s nom] [--detach|-d]"
        echo "  --tmux, -t      lance le profil dans tmux (session 'main' par défaut)"
        echo "  --session, -s   nom de la session tmux (implique --tmux)"
        echo "  --detach, -d    détache les autres clients de la session (reprise à distance)"
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
        command -v tmux >/dev/null 2>&1 || { echo "Erreur : tmux n'est pas installé" >&2; return 1; }
        _zenv_tmux "$profil" "$session" "$detach"
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
