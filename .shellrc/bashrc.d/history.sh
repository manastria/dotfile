# -*- mode: bash -*-

# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# activation date_heure dans la commande history
export HISTTIMEFORMAT="%Y/%m/%d_%T : "
