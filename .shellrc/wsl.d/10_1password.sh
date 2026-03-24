#!/bin/sh
# Configuration de 1Password sous WSL
# Les outils CLI de 1Password (op) communiquent avec le daemon Windows via le socket WSL

# Socket du daemon 1Password (installé côté Windows)
# Chemin standard : /mnt/c/Users/<USER>/AppData/Local/1Password/app/8/1password.sock
_OP_SOCK_BASE="/mnt/c/Users/${USER}/AppData/Local/1Password/app/8/1password.sock"

if [ -S "${_OP_SOCK_BASE}" ]; then
    export OP_SOCK="${_OP_SOCK_BASE}"
fi
unset _OP_SOCK_BASE

# Intégration SSH : utiliser l'agent SSH de 1Password (Windows) depuis WSL
# Nécessite npiperelay + socat installés dans WSL
#   sudo apt install socat
#   go install github.com/jstarks/npiperelay@latest
#
# Pour activer, décommenter les lignes suivantes :
# export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
# if ! ss -a | grep -q "$SSH_AUTH_SOCK"; then
#     rm -f "$SSH_AUTH_SOCK"
#     (setsid socat \
#         UNIX-LISTEN:"${SSH_AUTH_SOCK}",fork \
#         EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent" \
#         &)
# fi
