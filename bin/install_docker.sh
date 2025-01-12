#!/bin/bash

# Script pour installer Docker sur Debian 12

# Mettez à jour les paquets existants
sudo apt-get update

# Installez les dépendances nécessaires
sudo apt-get install -y ca-certificates curl gnupg

# Configurez le répertoire pour les clés GPG
sudo install -m 0755 -d /etc/apt/keyrings

# Téléchargez et ajoutez la clé GPG officielle de Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Ajoutez le dépôt Docker à vos sources APT
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mettez à jour les paquets avec le nouveau dépôt
sudo apt-get update

# Installez Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Vérifiez l'installation
sudo docker run hello-world

# Ajoutez l'utilisateur actuel au groupe Docker
sudo usermod -aG docker $USER

echo "Installation terminée. Veuillez vous déconnecter et vous reconnecter pour appliquer les changements."
