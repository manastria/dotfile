# -*- mode: bash -*-

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
    xterm) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# Fonction pour définir le titre de la fenêtre
set_window_title() {
    # Vérifie si on est dans un terminal graphique
    case "$TERM" in
        xterm*|rxvt*|konsole*|gnome*|alacritty)
            echo -en "\033]0;$(pwd | sed -e "s;^$HOME;~;")\a"
            ;;
    esac
}

__prompt_command() {
    local EXIT="$?"             # This needs to be first
    PS1=""

    local RCol='\[\e[0m\]'

    local Red='\[\e[0;31m\]'
    local Gre='\[\e[0;32m\]'
    local BYel='\[\e[1;33m\]'
    local BBlu='\[\e[1;34m\]'
    local Pur='\[\e[0;35m\]'

    if [ $EXIT != 0 ]; then
        PS1+="${Red}\u${RCol}"      # Add red if exit code non 0
    else
        PS1+="${Gre}\u${RCol}"
    fi

    PS1+="${RCol}@${BBlu}\h ${Pur}\w${BYel}\\$ ${RCol}"
	
    # Mise à jour du titre de la fenêtre uniquement pour les terminaux graphiques
    set_window_title
}



if [ "$color_prompt" = yes ]; then
    # Si l'option color_prompt est activée (c'est-à-dire si le terminal supporte les couleurs),
    # on définit PROMPT_COMMAND comme étant la fonction __prompt_command.
    # Cette fonction est appelée après chaque commande exécutée pour régénérer la variable PS1
    # qui contient la définition de l'invite (le prompt).
    # La ligne commentée en dessous montre une alternative pour PS1 sans utiliser PROMPT_COMMAND.
    # Elle définissait un prompt coloré directement sans la fonction __prompt_command.
    # PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    PROMPT_COMMAND=__prompt_command  # Appelle la fonction __prompt_command pour définir PS1 dynamiquement
else
    # Si le terminal ne supporte pas les couleurs, on définit PS1 sans utiliser la fonction __prompt_command,
    # en générant un prompt simple avec le nom d'utilisateur (\u), le nom d'hôte (\h) et le chemin complet (\w).
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# On désactive les variables color_prompt et force_color_prompt une fois qu'on n'en a plus besoin
unset color_prompt force_color_prompt
