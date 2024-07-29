#!/bin/bash
# -*- mode: bash -*-

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # Pas de couleur

# Met à jour la liste des paquets et upgrade les paquets existants
sudo apt update && sudo apt upgrade -y

# Liste des paquets à installer
packages=(vim bat fd-find zsh fzf sqlite3 git curl wget htop tree ncdu aptitude tmux haveged openssh-server squid-deb-proxy-client)
# Liste des paquets à installer pour les addons de VirtualBox
packages+=(dkms build-essential module-assistant)
to_install=()

# Vérifie si un environnement graphique est installé
if dpkg -l | grep -q xserver; then
    echo -e "${BLUE}Environnement graphique détecté. Ajout de paquets spécifiques.${NC}"
    packages+=(terminator)
else
    echo -e "${RED}Aucun environnement graphique détecté.${NC}"
fi

# Boucle sur chaque paquet
for pkg in "${packages[@]}"; do
    # Vérifie si le paquet est déjà installé
    if dpkg -s $pkg &> /dev/null; then
        echo -e "${BLUE}Le paquet $pkg est déjà installé.${NC}"
    else
        # Vérifie si le paquet existe dans les dépôts
        if apt-cache show $pkg &> /dev/null; then
            echo -e "${GREEN}Le paquet $pkg sera installé.${NC}"
            to_install+=($pkg)  # Ajoute le paquet à la liste des paquets à installer
        else
            echo -e "${RED}Le paquet $pkg n'existe pas dans les dépôts.${NC}"
        fi
    fi
done

# Installe tous les paquets en une seule commande
if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installation des paquets: ${to_install[*]}"
    sudo apt install -y "${to_install[@]}"
else
    echo "Aucun nouveau paquet à installer."
fi
