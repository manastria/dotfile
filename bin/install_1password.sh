#!/bin/bash

# Script pour installer 1Password sur Debian/Ubuntu
# Ce script nécessite les droits superutilisateur (sudo)

set -e

# Couleurs pour la sortie
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Pas de couleur

# Vérifier si le script est exécuté avec sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Ce script doit être exécuté avec sudo.${NC}"
  exit 1
fi

# Étape 1 : Ajouter la clé GPG du dépôt
echo -e "${YELLOW}Ajout de la clé GPG du dépôt 1Password...${NC}"
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

# Étape 2 : Ajouter le dépôt APT
echo -e "${YELLOW}Ajout du dépôt APT pour 1Password...${NC}"
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | tee /etc/apt/sources.list.d/1password.list

# Étape 3 : Ajouter la politique debsig-verify
echo -e "${YELLOW}Ajout de la politique debsig-verify...${NC}"
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

# Étape 4 : Mettre à jour les paquets et installer 1Password
echo -e "${YELLOW}Mise à jour des paquets et installation de 1Password...${NC}"
apt update && apt install -y 1password

# Confirmation de l'installation
if command -v 1password &> /dev/null; then
  echo -e "${GREEN}1Password a été installé avec succès !${NC}"
else
  echo -e "${RED}L'installation de 1Password a échoué.${NC}"
  exit 1
fi

# Fin du script
echo -e "${GREEN}Script terminé.${NC}"
