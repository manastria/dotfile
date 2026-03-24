#!/bin/sh
# Configuration SSH sous WSL
# Utilise les binaires SSH de Windows pour interagir avec l'agent Windows (ex: 1Password)

# Utiliser ssh.exe (Windows) au lieu du ssh Linux
# Équivalent à : git config --global core.sshCommand "ssh.exe"
export GIT_SSH_COMMAND="ssh.exe"

alias ssh='ssh.exe'
alias ssh-add='ssh-add.exe'
