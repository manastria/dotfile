# -*- mode: bash -*-

# Fonction pour détecter si le terminal supporte les couleurs
detect_color_support() {
    case "$TERM" in
        xterm-color|*-256color) color_prompt=yes;;
        xterm) color_prompt=yes;;
    esac

    if [ -n "$force_color_prompt" ]; then
        if command -v tput >/dev/null && tput setaf 1 >&/dev/null; then
            color_prompt=yes
        else
            color_prompt=
        fi
    fi
}

# Définition des couleurs si le terminal les supporte
set_colors() {
    if [ "$color_prompt" = yes ]; then
        RCol='\[\e[0m\]'    # Réinitialise les couleurs

        Red='\[\e[0;31m\]'
        Gre='\[\e[0;32m\]'
        Yel='\[\e[0;33m\]'
        Blu='\[\e[0;34m\]'
        Pur='\[\e[0;35m\]'
        Cyn='\[\e[0;36m\]'
        Whi='\[\e[0;37m\]'

        BRed='\[\e[1;31m\]'
        BGre='\[\e[1;32m\]'
        BYel='\[\e[1;33m\]'
        BBlu='\[\e[1;34m\]'
        BPur='\[\e[1;35m\]'
        BCyn='\[\e[1;36m\]'
        BWhi='\[\e[1;37m\]'
    else
        # Si pas de support des couleurs, on définit les variables à vide
        RCol=''
        Red=''
        Gre=''
        Yel=''
        Blu=''
        Pur=''
        Cyn=''
        Whi=''
        BRed=''
        BGre=''
        BYel=''
        BBlu=''
        BPur=''
        BCyn=''
        BWhi=''
    fi
}

# Style de prompt par défaut
prompt_default() {
    local EXIT="$?"

    if [ $EXIT != 0 ]; then
        PS1="${Red}\u${RCol}"      # Nom d'utilisateur en rouge si la dernière commande a échoué
    else
        PS1="${Gre}\u${RCol}"      # Nom d'utilisateur en vert si la dernière commande a réussi
    fi

    PS1+="${RCol}@${BBlu}\h ${Pur}\w${BYel}\\$ ${RCol}"
    PS1+="\[\e]1337;CurrentDir"'=$(pwd)\a\]'
}

# Style 'unhatched' : utilisateur en vert, répertoire en bleu, ':' et symbole en blanc
prompt_unhatched() {
    local EXIT="$?"

    # Symbole du prompt : '#' pour root, '$' pour les autres
    local prompt_symbol='$'
    if [ "$EUID" -eq 0 ]; then
        prompt_symbol='#'
    fi

    PS1="${Gre}\u@localhost${RCol}:${Blu}\w${RCol}${Whi}${prompt_symbol} ${RCol}"
}

# Fonction pour sélectionner le style de prompt
set_prompt_style() {
    local style="$1"

    case "$style" in
        default)
            PROMPT_COMMAND=prompt_default
            ;;
        unhatched)
            PROMPT_COMMAND=prompt_unhatched
            ;;
        *)
            echo "Erreur : Style de prompt inconnu '$style'. Les styles disponibles sont : default, unhatched."
            return 1
            ;;
    esac
}

# Fonction pour vérifier si le script est sourcé
is_sourced() {
    # Vérifie si $0 est identique à $BASH_SOURCE
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# Fonction principale pour initialiser le prompt
init_prompt() {
    # Détecte le support des couleurs
    detect_color_support

    # Définit les variables de couleurs
    set_colors

    # Sélectionne le style de prompt en fonction du paramètre
    set_prompt_style "$PROMPT_STYLE" || return 1

    # Si c'est un xterm ou rxvt, définit le titre de la fenêtre
    case "$TERM" in
        xterm*|rxvt*)
            PS1="\[\e]0;\u@\h: \w\a\]$PS1"
            ;;
        *)
            ;;
    esac

    # Nettoie les variables temporaires
    unset color_prompt force_color_prompt
}

# Vérifie si le script est sourcé
if ! is_sourced; then
    echo "Erreur : Ce script doit être sourcé, et non exécuté directement."
    echo "Utilisation : source ./prompt.sh [style]"
    exit 1
fi

# Vérifie si un style est passé en paramètre
if [ -n "$1" ]; then
    PROMPT_STYLE="$1"
else
    PROMPT_STYLE="default"
fi

# Initialise le prompt
init_prompt
