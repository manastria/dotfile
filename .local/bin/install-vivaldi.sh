#!/bin/bash

# Script pour installer Vivaldi (avec nettoyage préalable)
# Nécessite sudo

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# 1. Nettoyage des anciennes configurations conflictuelles
# C'est ici qu'on résout l'erreur "Signed-By" et le doublon
echo "--- Nettoyage des anciennes sources Vivaldi ---"
rm -f /etc/apt/sources.list.d/vivaldi.list
rm -f /etc/apt/sources.list.d/vivaldi.sources

# 2. Installation des dépendances
echo "--- Installation des dépendances ---"
apt update && apt install -y wget gpg

# 3. Gestion de la clé GPG
echo "--- Configuration de la clé GPG ---"
wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor --yes -o /usr/share/keyrings/vivaldi-browser-keyring.gpg

# 4. Ajout du dépôt avec restriction d'architecture (arch=amd64)
# Cela empêche apt de chercher la version i386 qui n'existe pas
echo "--- Création du fichier source propre ---"
echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser-keyring.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" > /etc/apt/sources.list.d/vivaldi-archive.list

# 5. Installation
echo "--- Installation de Vivaldi ---"
apt update
apt install -y vivaldi-stable

echo "--- Terminé ---"