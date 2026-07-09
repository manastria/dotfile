# -*- mode: shell-script -*-
# Thème oh-my-zsh "omz-ascii" : rendu identique au prompt du profil "base",
# uniquement des caractères ASCII/ANSI (aucune icône Unicode/Powerline).
# Destiné aux consoles Linux (TTY, Ctrl+Alt+F1) dont le jeu de caractères est limité.

setopt PROMPT_SUBST

if [[ $EUID == 0 ]]; then
    _omz_ascii_host="%{$fg[red]%}%m%{$reset_color%}"
    _omz_ascii_char="#"
else
    _omz_ascii_host="%{$fg[green]%}%n@%m%{$reset_color%}"
    _omz_ascii_char="$"
fi

PROMPT='${_omz_ascii_host}:%{$fg[blue]%}%~%{$reset_color%}
${_omz_ascii_char} '
