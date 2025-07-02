#!/bin/bash

# Script pour installer le navigateur Brave sur Debian/Ubuntu de manière sécurisée

# S'assurer que le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root. Utilisez 'sudo ./install_brave.sh'" >&2
  exit 1
fi

# Installer les dépendances nécessaires (curl, gpg)
echo "--- Installation des dépendances ---"
apt update
apt install -y curl gpg

# 1. Ajout de la clé GPG officielle de Brave
echo "--- Ajout de la clé GPG de Brave ---"
curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/brave-browser-archive-keyring.gpg

# Vérifier que la clé a bien été ajoutée
if [ ! -f /usr/share/keyrings/brave-browser-archive-keyring.gpg ]; then
    echo "Erreur : La clé GPG de Brave n'a pas pu être téléchargée." >&2
    exit 1
fi

# 2. Ajout du dépôt Brave
echo "--- Ajout du dépôt Brave aux sources APT ---"
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# 3. Installation de Brave
echo "--- Mise à jour des paquets et installation de Brave ---"
apt update
apt install -y brave-browser

echo "--- Installation de Brave terminée avec succès ! ---"

exit 0
