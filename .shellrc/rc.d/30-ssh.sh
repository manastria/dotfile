#!/bin/sh
# ~/.shellrc/rc.d/30-ssh.sh


# Fonction pour se connecter à un hôte distant via SSH et lancer tmux
function tmux-connect {
    TERM=xterm-256color ssh -p ${3:-22} $1@$2 -t "tmux new -A -s ssh-session"
}
# Usage : tmux-connect user host [port]

