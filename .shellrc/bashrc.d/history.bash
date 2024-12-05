# -*- mode: bash -*-

# Eternal bash history.
# ---------------------
# Undocumented feature which sets the size to "unlimited".
# https://stackoverflow.com/questions/9457233/unlimited-bash-history
export HISTFILESIZE=
export HISTSIZE=

# activation date_heure dans la commande history
export HISTTIMEFORMAT="%Y-%m-%d │ %H:%M:%S → "

# Ignorer les commandes dupliquées consécutives et les commandes commençant par un espace
#export HISTCONTROL=ignoreboth

# Ne pas stocker certaines commandes sensibles ou inutiles dans l'historique
#export HISTIGNORE="ls:ll:cd:pwd:clear:history:exit"

# Ajouter à l'historique au lieu d'écraser
shopt -s histappend

# Enregistrer les commandes multi-lignes sur une seule ligne
shopt -s cmdhist

# Enregistrer chaque commande immédiatement, pas à la fin de la session
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"


# Fonction pour sauvegarder l'historique par utilisateur
backup_history() {
    local backup_dir="$HOME/.history_backups"
    mkdir -p "$backup_dir"
    cp "$HISTFILE" "$backup_dir/bash_history_$(date +%Y%m%d_%H%M%S)"
}

# Créer une sauvegarde de l'historique à la déconnexion
trap backup_history EXIT