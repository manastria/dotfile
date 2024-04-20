# -*- mode: bash -*-

# Chemin du fichier où l'agent SSH stocke ses variables d'environnement.
SSH_ENV="$HOME/.ssh/agent-environment"

echo "SSH agent script starting."

# Fonction pour vérifier si un agent SSH est en cours d'exécution.
# Elle teste si la variable SSH_AUTH_SOCK est définie et si `ssh-add -l` peut lister des clés.
agent_is_running() {
    if [ "$SSH_AUTH_SOCK" ]; then
        # ssh-add -l teste si l'agent a des clés
        # 0 = agent en cours d'exécution avec des clés
        # 1 = agent en cours d'exécution sans clés
        # 2 = agent non en cours d'exécution
        ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ]
        echo "Agent is already running. PID: $SSH_AGENT_PID, Socket: $SSH_AUTH_SOCK."
        true
    else
        echo "No running agent linked to current session."
        false
    fi
}

# Fonction pour vérifier si l'agent SSH actuel a des clés chargées.
agent_has_keys() {
    if ssh-add -l >/dev/null 2>&1; then
        echo "Agent has keys loaded."
        true
    else
        echo "Agent is running but no keys are loaded."
        false
    fi
}

# Fonction pour charger les variables d'environnement de l'agent SSH à partir du fichier.
agent_load_env() {
    if [ -f "$SSH_ENV" ]; then
        . "$SSH_ENV" >/dev/null
        echo "Environment loaded from $SSH_ENV."
        echo "Loaded agent details: PID: $SSH_AGENT_PID, Socket: $SSH_AUTH_SOCK."
    else
        echo "No environment file found. A new SSH agent might be started."
    fi
}

# Fonction pour démarrer un nouvel agent SSH et sauvegarder ses variables d'environnement.
agent_start() {
    echo "Initialising new SSH agent..."
    (umask 077; ssh-agent | sed 's/^echo/#echo/' >"$SSH_ENV")
    . "$SSH_ENV" >/dev/null
    echo "New agent initialized with PID: $SSH_AGENT_PID and Socket: $SSH_AUTH_SOCK."
}

# Fonction pour vérifier si l'agent stocké dans le fichier d'environnement est toujours valide.
agent_is_valid() {
    if [ -n "$SSH_AGENT_PID" ] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        echo "Agent with PID $SSH_AGENT_PID is still valid."
        true
    else
        echo "Agent with PID $SSH_AGENT_PID is no longer valid."
        false
    fi
}

# Logique principale pour gérer l'agent SSH.
if ! agent_is_running; then
    agent_load_env
    if ! agent_is_running || ! agent_is_valid; then
        agent_start
        ssh-add
    fi
fi

# Démarrage d'un nouvel agent si aucun n'est en cours, ou ajout de clés si l'agent n'a pas de clés.
if ! agent_is_running; then
    agent_start
    ssh-add
elif ! agent_has_keys; then
    ssh-add
fi

# Nettoie les variables d'environnement utilisées temporairement dans le script.
unset env

echo "SSH agent script completed."
