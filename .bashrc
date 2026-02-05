# -*- mode: bash -*-
# $HOME/.bashrc
#
# this file is sourced by all *interactive* bash shells on startup,
# including some apparently interactive shells such as scp and rcp
# that can't tolerate any output. so make sure this doesn't display
# anything or bad things will happen !

# test for an interactive shell. there is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* ]] ; then
  # shell is non-interactive. be done now!
  return
fi

# Source global definitions
if [ -f /etc/bashrc ]; then
	 . /etc/bashrc
fi


# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac


# load all files from .shell/bashrc.d directory
if [ -d "$HOME"/.shellrc/bashrc.d ]; then
  for file in "$HOME"/.shellrc/bashrc.d/*.bash; do
    source "$file"
  done
fi

# load all files from .shell/rc.d directory
if [ -d "$HOME"/.shellrc/rc.d ]; then
  for file in "$HOME"/.shellrc/rc.d/*.sh; do
    source "$file"
  done
fi

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
# [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"



# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Chargement des alias
if [ -f ~/.bash_aliases ] && [ -r ~/.bash_aliases ] && [ -s ~/.bash_aliases ]; then
    # Vérifier les permissions du fichier
    if [ "$(stat -c %a ~/.bash_aliases)" = "600" ] || [ "$(stat -c %a ~/.bash_aliases)" = "644" ]; then
        # Vérifier que le propriétaire est bien l'utilisateur courant
        if [ "$(stat -c %U ~/.bash_aliases)" = "$USER" ]; then
            . ~/.bash_aliases
        else
            echo "ATTENTION: ~/.bash_aliases n'appartient pas à l'utilisateur courant"
        fi
    else
        echo "ATTENTION: ~/.bash_aliases a des permissions incorrectes"
    fi
fi

# some more ls aliases
#alias ll='ls -alF'
#alias la='ls -A'
#alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Ajout du répertoire pour le répertoire bin perso
export PATH=$PATH:${HOME}/bin:${HOME}/.local/bin

# Ajout du répertoire pour 'sl'
export PATH=$PATH:/usr/games

# Déduplique PATH proprement (sans processus externe)
path_clean() {
  local saveIFS="$IFS"
  IFS=':'

  # tableau associatif pour marquer les chemins déjà vus (Bash ≥ 4)
  local -A seen=()
  local -a out=()
  local p

  for p in $PATH; do
    # ignorer les entrées vides
    [[ -z $p ]] && continue
    # enlever un éventuel slash final pour normaliser
    p="${p%/}"
    [[ ! -d $p ]] && continue        # <- filtre les chemins inexistants
    # ignorer si déjà présent
    [[ -n ${seen["$p"]} ]] && continue
    seen["$p"]=1
    out+=("$p")
  done

  # reconstruire PATH avec des :
  IFS=':'
  PATH="${out[*]}"
  IFS="$saveIFS"
  export PATH
}

# Nettoyer PATH à chaque ouverture de shell interactif
path_clean

# Retourne toujours un code de sortie 0
return 0 2>/dev/null || true
