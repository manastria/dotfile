# -*- mode: bash -*-

# Configuration
SSH_ENV="$HOME/.ssh/agent-environment"
AGENTS_CONFIG="$HOME/.ssh/agents.conf"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEBUG=${DEBUG:-0}

# Structure pour stocker les agents disponibles
declare -A SSH_AGENTS=(
    ["default"]="$SSH_AUTH_SOCK_DEFAULT"
    ["1password"]="$HOME/.1password/agent.sock"
    ["keepassxc"]="$HOME/.keepassxc/ssh-agent.sock"
)

# Fonctions de logging
log() {
    color=$1
    shift
    echo -e "${color}$*${NC}"
}

debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        log $1 $2
    else
        logger -t ssh-agent-script "$2"
    fi
}

# Fonction pour sauvegarder la configuration des agents
save_agents_config() {
    local config_file="$AGENTS_CONFIG"
    rm -f "$config_file"
    for agent_name in "${!SSH_AGENTS[@]}"; do
        echo "${agent_name}=${SSH_AGENTS[$agent_name]}" >> "$config_file"
    done
}

# Fonction pour charger la configuration des agents
load_agents_config() {
    local config_file="$AGENTS_CONFIG"
    if [ -f "$config_file" ]; then
        while IFS='=' read -r name socket; do
            SSH_AGENTS["$name"]="$socket"
        done < "$config_file"
    fi
}

# Fonction pour ajouter un nouvel agent
add_ssh_agent() {
    local name="$1"
    local socket="$2"
    
    if [ -z "$name" ] || [ -z "$socket" ]; then
        log $RED "Usage: add_ssh_agent <name> <socket_path>"
        return 1
    fi
    
    SSH_AGENTS["$name"]="$socket"
    save_agents_config
    log $GREEN "Added SSH agent '$name' with socket: $socket"
}

# Fonction pour lister les agents disponibles
list_ssh_agents() {
    log $BLUE "Available SSH agents:"
    for agent_name in "${!SSH_AGENTS[@]}"; do
        local socket="${SSH_AGENTS[$agent_name]}"
        if [ -e "$socket" ]; then
            log $GREEN "  $agent_name: $socket (Available)"
        else
            log $RED "  $agent_name: $socket (Not available)"
        fi
    done
}

# Fonction pour basculer entre les agents
switch_ssh_agent() {
    local target_agent="$1"
    
    if [ -z "$target_agent" ]; then
        log $RED "Usage: switch_ssh_agent <agent_name>"
        list_ssh_agents
        return 1
    fi
    
    if [ ! ${SSH_AGENTS[$target_agent]+_} ]; then
        log $RED "Unknown SSH agent: $target_agent"
        list_ssh_agents
        return 1
    fi
    
    local target_socket="${SSH_AGENTS[$target_agent]}"
    
    if [ ! -e "$target_socket" ]; then
        log $RED "Agent socket not available: $target_socket"
        return 1
    fi
    
    # Sauvegarde l'agent actuel si ce n'est pas déjà fait
    [ -z "$SSH_AUTH_SOCK_DEFAULT" ] && export SSH_AUTH_SOCK_DEFAULT="$SSH_AUTH_SOCK"
    
    export SSH_AUTH_SOCK="$target_socket"
    log $GREEN "Switched to SSH agent: $target_agent"
    
    # Vérifie si l'agent fonctionne
    if ! ssh-add -l >/dev/null 2>&1 && [ $? -ne 1 ]; then
        log $RED "Failed to connect to agent: $target_agent"
        export SSH_AUTH_SOCK="$SSH_AUTH_SOCK_DEFAULT"
        return 1
    fi
}

# [Le reste de votre script original reste identique]

# Charge la configuration des agents au démarrage
load_agents_config

# Ajoute les alias pour utilisation dans le shell
alias ssh-agents='list_ssh_agents'
alias ssh-agent-switch='switch_ssh_agent'
alias ssh-agent-add='add_ssh_agent'
