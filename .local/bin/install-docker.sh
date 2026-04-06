#!/bin/bash

# Script d'installation universel pour Docker sur Debian et Ubuntu
# - Idempotent : peut être exécuté plusieurs fois sans effet de bord
# - Détecte l'OS pour utiliser le bon dépôt Docker
# - Configure les plages réseau Docker dans /etc/docker/daemon.json

set -e

# --- Détection de l'OS ---
OS_ID=$(. /etc/os-release && echo "$ID")

if [ "$OS_ID" != "debian" ] && [ "$OS_ID" != "ubuntu" ]; then
  echo "ERREUR : Ce script est conçu uniquement pour Debian ou Ubuntu." >&2
  exit 1
fi

echo "--- Début de l'installation/configuration de Docker sur $OS_ID ---"

# --- Étape 1 : Mise à jour et installation des dépendances ---
echo "INFO: Mise à jour des paquets et installation des dépendances..."
sudo apt-get update -q
sudo apt-get install -y ca-certificates curl gnupg jq

# --- Étape 2 : Configuration de la clé GPG de Docker ---
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    echo "INFO: Ajout de la clé GPG officielle de Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc
else
    echo "INFO: Clé GPG Docker déjà présente, étape ignorée."
fi

# --- Étape 3 : Ajout du dépôt Docker ---
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo "INFO: Ajout du dépôt Docker aux sources APT..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS_ID} \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -q
else
    echo "INFO: Dépôt Docker déjà configuré, étape ignorée."
fi

# --- Étape 4 : Installation de Docker Engine ---
if ! command -v docker &> /dev/null; then
    echo "INFO: Installation des paquets Docker..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "INFO: Docker est déjà installé ($(docker --version)), étape ignorée."
fi

# --- Étape 5 : Configuration des plages réseau Docker ---
DAEMON_JSON="/etc/docker/daemon.json"

configure_network() {
    echo "INFO: Application de la configuration réseau dans $DAEMON_JSON..."
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
    echo "INFO: Configuration réseau appliquée."
    # Redémarrer Docker seulement s'il est déjà en cours d'exécution
    if systemctl is-active --quiet docker; then
        echo "INFO: Redémarrage du service Docker pour appliquer la nouvelle configuration..."
        sudo systemctl restart docker
    fi
}

# Vérifier si la configuration réseau est déjà en place
if [ -f "$DAEMON_JSON" ] && jq -e '.bip == "10.200.0.1/24"' "$DAEMON_JSON" > /dev/null 2>&1; then
    echo "INFO: Configuration réseau Docker déjà en place, étape ignorée."
else
    configure_network
fi

# --- Étape 6 : Post-installation ---
if id -nG "$USER" | grep -qw docker; then
    echo "INFO: L'utilisateur '$USER' est déjà dans le groupe 'docker', étape ignorée."
else
    echo "INFO: Ajout de l'utilisateur '$USER' au groupe 'docker'..."
    sudo usermod -aG docker "$USER"
fi

echo ""
echo "✅ Installation et configuration de Docker terminées avec succès."

# --- Étape 7 : Vérification ---
echo "INFO: Vérification de l'installation avec le conteneur 'hello-world'..."
# On utilise sudo car l'appartenance au groupe n'est pas encore effective dans ce shell
sudo docker run hello-world

echo ""
echo "⚠️  IMPORTANT : Pour utiliser Docker sans 'sudo', veuillez vous déconnecter et vous reconnecter,"
echo "ou exécutez la commande suivante dans un nouveau terminal : newgrp docker"
