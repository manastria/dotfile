#!/usr/bin/env bash
# Déploie l'entrée terminfo xterm-ghostty sur une machine distante
# Usage: ghostty-terminfo-deploy user@machine

if [[ -z "$1" ]]; then
  echo "Usage: $0 user@machine" >&2
  exit 1
fi

ghostty +show-terminfo | ssh "$1" 'tic -x -'
