#!/bin/bash

# Script d'installation universel pour Docker sur Debian et Ubuntu
# - Stoppe le script en cas d'erreur
# - Détecte l'OS pour utiliser le bon dépôt Docker

# Arrête le script immédiatement si une commande échoue
set -e

# --- Détection de l'OS ---
# On utilise le fichier /etc/os-release qui est un standard moderne.
# La variable $ID contiendra "debian" ou "ubuntu".
OS_ID=$(. /etc/os-release && echo "$ID")

if [ "$OS_ID" != "debian" ] && [ "$OS_ID" != "ubuntu" ]; then
  echo "ERREUR : Ce script est conçu uniquement pour Debian ou Ubuntu." >&2
  exit 1
fi

echo "--- Début de l'installation de Docker sur $OS_ID ---"

# --- Étape 1 : Mise à jour et installation des dépendances ---
echo "INFO: Mise à jour des paquets et installation des dépendances..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# --- Étape 2 : Configuration des clés GPG de Docker ---
echo "INFO: Ajout de la clé GPG officielle de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
# La structure de l'URL de la clé est la même pour Debian et Ubuntu
curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# --- Étape 3 : Ajout du dépôt Docker ---
echo "INFO: Ajout du dépôt Docker aux sources APT..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS_ID} \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# --- Étape 4 : Installation de Docker Engine ---
echo "INFO: Installation des paquets Docker..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- Étape 5 : Post-installation ---
echo "INFO: Ajout de l'utilisateur '$USER' au groupe 'docker'..."
sudo usermod -aG docker "$USER"

echo ""
echo "✅ Installation de Docker terminée avec succès."

# --- Étape 6 : Vérification ---
echo "INFO: Vérification de l'installation avec le conteneur 'hello-world'..."
# On utilise sudo car l'appartenance au groupe n'est pas encore effective dans ce shell
sudo docker run hello-world

echo ""
echo "⚠️  IMPORTANT : Pour utiliser Docker sans 'sudo', veuillez vous déconnecter et vous reconnecter,"
echo "ou exécutez la commande suivante dans un nouveau terminal : newgrp docker"
