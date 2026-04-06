#!/bin/bash

# Script d'installation universel pour Docker sur Debian et Ubuntu
# - Idempotent : peut être exécuté plusieurs fois sans effet de bord
# - Détecte l'OS pour utiliser le bon dépôt Docker
# - Configure les plages réseau Docker dans /etc/docker/daemon.json

set -e

# --- Couleurs et fonctions de log ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

# --- Détection de l'OS ---
OS_ID=$(. /etc/os-release && echo "$ID")

if [ "$OS_ID" != "debian" ] && [ "$OS_ID" != "ubuntu" ]; then
    die "Ce script est conçu uniquement pour Debian ou Ubuntu."
fi

echo -e "\n${BOLD}--- Installation/configuration de Docker sur $OS_ID ---${RESET}\n"

# --- Détection de l'utilisateur cible pour le groupe docker ---
# Doit être fait avant le sudo warmup : $SUDO_USER et $USER sont fiables ici.
if [ -n "${SUDO_USER:-}" ]; then
    DOCKER_USER="$SUDO_USER"       # Lancé via sudo → vrai utilisateur appelant
elif [ "$(id -u)" -ne 0 ]; then
    DOCKER_USER="$USER"            # Lancé normalement (cas Tier 2 attendu)
else
    DOCKER_USER=""                 # Root direct : impossible à détecter
fi

if [ -n "$DOCKER_USER" ]; then
    warn "L'utilisateur qui sera ajouté au groupe 'docker' : ${BOLD}${DOCKER_USER}${RESET}"
    read -r -p "    Est-ce correct ? [O/n] " _resp
    case "${_resp,,}" in
        n|no|non) DOCKER_USER="" ;;
    esac
fi

if [ -z "$DOCKER_USER" ]; then
    read -r -p "Saisissez le login de l'utilisateur à ajouter au groupe 'docker' : " DOCKER_USER
fi

if ! id "$DOCKER_USER" &>/dev/null; then
    die "L'utilisateur '$DOCKER_USER' n'existe pas sur ce système."
fi

# --- Préchauffage sudo (Tier 2 : une seule demande de mot de passe) ---
info "Des droits administrateur sont nécessaires pour certaines étapes."
sudo -v
( while true; do sudo -n true; sleep 50; done ) &
_SUDO_PID=$!
trap 'kill "$_SUDO_PID" 2>/dev/null' EXIT INT TERM

# --- Étape 1 : Mise à jour et installation des dépendances ---
info "Mise à jour des paquets et installation des dépendances..."
sudo apt-get update -q
sudo apt-get install -y ca-certificates curl gnupg jq
success "Dépendances installées."

# --- Étape 2 : Configuration de la clé GPG de Docker ---
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    info "Ajout de la clé GPG officielle de Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    success "Clé GPG ajoutée."
else
    info "Clé GPG Docker déjà présente, étape ignorée."
fi

# --- Étape 3 : Ajout du dépôt Docker ---
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    info "Ajout du dépôt Docker aux sources APT..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS_ID} \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -q
    success "Dépôt Docker configuré."
else
    info "Dépôt Docker déjà configuré, étape ignorée."
fi

# --- Étape 4 : Installation de Docker Engine ---
if ! command -v docker &> /dev/null; then
    info "Installation des paquets Docker..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    success "Docker Engine installé."
else
    info "Docker est déjà installé ($(docker --version)), étape ignorée."
fi

# --- Étape 5 : Configuration des plages réseau Docker ---
DAEMON_JSON="/etc/docker/daemon.json"

configure_network() {
    info "Application de la configuration réseau dans $DAEMON_JSON..."
    sudo mkdir -p /etc/docker
    if [ -f "$DAEMON_JSON" ] && [ -s "$DAEMON_JSON" ]; then
        # Fusionner avec la configuration existante (nos clés prennent la priorité)
        MERGED=$(jq '. + {
          "bip": "10.200.0.1/24",
          "default-address-pools": [{"base": "10.200.0.0/16", "size": 24}]
        }' "$DAEMON_JSON")
        echo "$MERGED" | sudo tee "$DAEMON_JSON" > /dev/null
    else
        sudo tee "$DAEMON_JSON" > /dev/null << 'EOF'
{
  "bip": "10.200.0.1/24",
  "default-address-pools": [
    {
      "base": "10.200.0.0/16",
      "size": 24
    }
  ]
}
EOF
    fi
    success "Configuration réseau appliquée."
    # Redémarrer Docker seulement s'il est déjà en cours d'exécution
    if systemctl is-active --quiet docker; then
        info "Redémarrage du service Docker pour appliquer la nouvelle configuration..."
        sudo systemctl restart docker
        success "Service Docker redémarré."
    fi
}

if [ -f "$DAEMON_JSON" ] && jq -e '.bip == "10.200.0.1/24"' "$DAEMON_JSON" > /dev/null 2>&1; then
    info "Configuration réseau Docker déjà en place, étape ignorée."
else
    configure_network
fi

# --- Étape 6 : Ajout de l'utilisateur au groupe docker ---
if id -nG "$DOCKER_USER" | grep -qw docker; then
    info "L'utilisateur '$DOCKER_USER' est déjà dans le groupe 'docker', étape ignorée."
else
    info "Ajout de l'utilisateur '$DOCKER_USER' au groupe 'docker'..."
    sudo usermod -aG docker "$DOCKER_USER"
    success "Utilisateur '$DOCKER_USER' ajouté au groupe 'docker'."
fi

echo ""
success "Installation et configuration de Docker terminées avec succès."

# --- Étape 7 : Vérification ---
info "Vérification de l'installation avec le conteneur 'hello-world'..."
# On utilise sudo car l'appartenance au groupe n'est pas encore effective dans ce shell
sudo docker run hello-world

echo ""
warn "Pour utiliser Docker sans 'sudo', déconnectez-vous et reconnectez-vous,"
warn "ou exécutez dans un nouveau terminal : ${BOLD}newgrp docker${RESET}"
