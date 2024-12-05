# -*- mode: bash -*-

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000

# activation date_heure dans la commande history
export HISTTIMEFORMAT="%Y/%m/%d_%T : "

shopt -s histappend 
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"
