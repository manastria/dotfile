# -*- mode: bash -*-

# Chemin du fichier où l'agent SSH stocke ses variables d'environnement.
SSH_ENV="$HOME/.ssh/agent-environment"

# Couleurs pour l'affichage des messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variable pour activer/désactiver le mode debug
DEBUG=${DEBUG:-0}

# Fonction pour afficher les messages avec des couleurs
log() {
    color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Fonction pour afficher les messages de debug
debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        log $1 $2
    else
        logger -t ssh-agent-script "$2"
    fi
}

log $BLUE "SSH agent script starting."

# Fonction pour vérifier si un agent SSH est en cours d'exécution.
agent_is_running() {
    if [ "$SSH_AUTH_SOCK" ]; then
        if ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ]; then
            debug_log $GREEN "  Agent is already running. PID: $SSH_AGENT_PID, Socket: $SSH_AUTH_SOCK."
            return 0
        fi
    fi
    debug_log $YELLOW "  No running agent linked to current session."
    return 1
}

# Fonction pour vérifier si l'agent SSH actuel a des clés chargées.
agent_has_keys() {
    if ssh-add -l >/dev/null 2>&1; then
        debug_log $GREEN "  Agent has keys loaded."
        return 0
    else
        debug_log $YELLOW "  Agent is running but no keys are loaded."
        return 1
    fi
}

# Fonction pour charger les variables d'environnement de l'agent SSH à partir du fichier.
agent_load_env() {
    if [ -f "$SSH_ENV" ]; then
        . "$SSH_ENV" >/dev/null
        debug_log $GREEN "  Environment loaded from $SSH_ENV."
        debug_log $GREEN "  Loaded agent details: PID: $SSH_AGENT_PID, Socket: $SSH_AUTH_SOCK."
    else
        debug_log $RED "  No environment file found. A new SSH agent might be started."
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
        debug_log $GREEN "  Agent with PID $SSH_AGENT_PID is still valid."
        return 0
    else
        debug_log $RED "  Agent with PID $SSH_AGENT_PID is no longer valid."
        return 1
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

# Support pour l'ajout de plusieurs clés SSH.
default_keys="$HOME/.ssh/id_rsa $HOME/.ssh/id_ecdsa"
keys_to_add="${SSH_KEYS:-$default_keys}"
for key in $keys_to_add; do
    # Ajoute la clé si elle existe.
    [ -f "$key" ] && ssh-add "$key"
done

# Nettoie les variables d'environnement utilisées temporairement dans le script.
unset env

log $BLUE "SSH agent script completed."
