# -*- mode: bash -*-

# Chemin du fichier où l'agent SSH stocke ses variables d'environnement.
SSH_ENV="$HOME/.ssh/agent-environment"

# Couleurs pour l'affichage des messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages avec des couleurs
log() {
    color=$1
    shift
    echo -e "${color}$*${NC}"
}

log $GREEN "SSH agent script starting."

# Fonction pour vérifier si un agent SSH est en cours d'exécution.
# Elle teste si la variable SSH_AUTH_SOCK est définie et si `ssh-add -l` peut lister des clés.
agent_is_running() {
    if [ "$SSH_AUTH_SOCK" ]; then
        # ssh-add -l teste si l'agent a des clés
        # 0 = agent en cours d'exécution avec des clés
        # 1 = agent en cours d'exécution sans clés
        # 2 = agent non en cours d'exécution
        ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ]
        log $GREEN "  Agent is already running. PID: $SSH_AGENT_PID, Socket: $SSH_AUTH_SOCK."
        true
    else
        log $YELLOW "  No running agent linked to current session."
        false
    fi
}

# Fonction pour vérifier si l'agent SSH actuel a des clés chargées.
agent_has_keys() {
    if ssh-add -l >/dev/null 2>&1; then
        log $GREEN "  Agent has keys loaded."
        true
    else
        log $YELLOW "  Agent is running but no keys are loaded."
        false
    fi
}

# Fonction pour charger les variables d'environnement de l'agent SSH à partir du fichier.
agent_load_env() {
    if [ -f "$SSH_ENV" ]; then
        . "$SSH_ENV" >/dev/null
        log $GREEN "  Environment loaded from $SSH_ENV."
        log $GREEN "  Loaded agent details: PID: $SSH_AGENT_PID, Socket: $SSH_AUTH_SOCK."
    else
        log $RED "  No environment file found. A new SSH agent might be started."
    fi
}

# Fonction pour démarrer un nouvel agent SSH et sauvegarder ses variables d'environnement.
agent_start() {
    log $YELLOW "  Initialising new SSH agent..."
    (umask 077; ssh-agent | sed 's/^echo/#echo/' >"$SSH_ENV")
    . "$SSH_ENV" >/dev/null
    log $GREEN "  New agent initialized with PID: $SSH_AGENT_PID and Socket: $SSH_AUTH_SOCK."
}

# Fonction pour vérifier si l'agent stocké dans le fichier d'environnement est toujours valide.
agent_is_valid() {
    if [ -n "$SSH_AGENT_PID" ] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        log $GREEN "  Agent with PID $SSH_AGENT_PID is still valid."
        true
    else
        log $RED "  Agent with PID $SSH_AGENT_PID is no longer valid."
        false
    fi
}

# Logique principale pour gérer l'agent SSH.
if ! agent_is_running; then
    log $YELLOW "  No running agent found."
    # Charge les variables d'environnement de l'agent s'il existe déjà.
    agent_load_env
    if ! agent_is_running || ! agent_is_valid; then
        log $RED "  Agent is not running or is not valid."
        # Démarrage d'un nouvel agent si l'agent actuel n'est pas valide.
        agent_start
        ssh-add
    fi
fi

# Démarrage d'un nouvel agent si aucun n'est en cours, ou ajout de clés si l'agent n'a pas de clés.
if ! agent_is_running; then
    log $YELLOW "  Starting new agent and adding keys..."
    # Démarrage d'un nouvel agent et ajout de clés.
    agent_start
    ssh-add
elif ! agent_has_keys; then
    log $YELLOW "  Agent is running but has no keys loaded. Adding keys..."
    # Ajout de clés à l'agent existant.
    ssh-add
fi

#     # Support pour l'ajout de plusieurs clés SSH.
#     # Les chemins des clés peuvent être spécifiés via la variable SSH_KEYS, ou par défaut.
#     default_keys="$HOME/.ssh/id_rsa $HOME/.ssh/id_ecdsa"
#     keys_to_add="${SSH_KEYS:-$default_keys}"
#     for key in $keys_to_add; do
#         # Ajoute la clé si elle existe.
#         [ -f "$key" ] && ssh-add "$key"
#     done

# Nettoie les variables d'environnement utilisées temporairement dans le script.
unset env

log $GREEN "SSH agent script completed."
