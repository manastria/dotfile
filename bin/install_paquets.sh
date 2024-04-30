#!/bin/bash

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # Pas de couleur

# Met à jour la liste des paquets et upgrade les paquets existants
sudo apt update && sudo apt upgrade -y

# Liste des paquets à installer
packages=(vim bat fd-find zsh fzf sqlite3 git curl wget htop tree ncdu aptitude tmux)

# Boucle sur chaque paquet
for pkg in "${packages[@]}"; do
    # Vérifie si le paquet est déjà installé
    if dpkg -s $pkg &> /dev/null; then
        echo -e "${BLUE}Le paquet $pkg est déjà installé.${NC}"
    else
        # Vérifie si le paquet existe dans les dépôts
        if apt-cache show $pkg &> /dev/null; then
            echo -e "${GREEN}Installation du paquet $pkg...${NC}"
            sudo apt install -y $pkg
        else
            echo -e "${RED}Le paquet $pkg n'existe pas dans les dépôts.${NC}"
        fi
    fi
done
