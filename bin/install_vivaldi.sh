#!/bin/bash

# Script pour installer le navigateur Vivaldi sur Debian/Ubuntu de manière sécurisée

# S'assurer que le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root. Utilisez 'sudo ./install_vivaldi.sh'" >&2
  exit 1
fi

# Installer les dépendances nécessaires (wget, gpg)
echo "--- Installation des dépendances ---"
apt update
apt install -y wget gpg

# 1. Ajout de la clé GPG officielle de Vivaldi
echo "--- Téléchargement et ajout de la clé GPG de Vivaldi ---"
wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/vivaldi-browser-keyring.gpg

# Vérifier que la clé a bien été ajoutée
if [ ! -f /usr/share/keyrings/vivaldi-browser-keyring.gpg ]; then
    echo "Erreur : La clé GPG de Vivaldi n'a pas pu être téléchargée." >&2
    exit 1
fi

# 2. Ajout du dépôt Vivaldi
echo "--- Ajout du dépôt Vivaldi aux sources APT ---"
echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser-keyring.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" > /etc/apt/sources.list.d/vivaldi-archive.list

# 3. Installation de Vivaldi
echo "--- Mise à jour des paquets et installation de Vivaldi ---"
apt update
apt install -y vivaldi-stable

echo "--- Installation de Vivaldi terminée avec succès ! ---"

exit 0
