# Assurez-vous que le mode vim est activé
bindkey -v

# Définir une fonction pour lier des touches spéciales
function vim-mode-bindkey () {
    local -a maps
    local command

    while (( $# )); do
        [[ $1 = '--' ]] && break
        maps+=$1
        shift
    done
    shift

    command=$1
    shift

    # Accumuler les combinaisons de touches
    function vim-mode-accum-combo () {
        typeset -g -a combos
        local combo="$1"; shift
        if (( $#@ )); then
            local cur="$1"; shift
            combos+="$combo$cur"
        else
            combos+="$combo"
        fi
    }

    local -a combos
    vim-mode-accum-combo '' "$@"
    for c in ${combos}; do
        for m in ${maps}; do
            bindkey -M $m "$c" $command
        done
    done
}

# Définir une fonction pour potentiellement lier des touches avec un préfixe Meta (Alt)
vim-mode-maybe-bind() {
    local k="$1"; shift
    if [[ ${VIM_MODE_ESC_PREFIXED_WANTED-^?^Hbdf.g} = *${k}* ]]; then
        vim-mode-bindkey "$@"
    fi
}

# Lier les raccourcis clavier spécifiés
vim-mode-maybe-bind H viins -- run-help '\eh'  # Alt + h
vim-mode-bindkey viins -- push-line '^Q'       # Ctrl + Q

# Assurez-vous que run-help est correctement lié
autoload -Uz run-help

