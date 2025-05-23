#!/bin/bash
# -*- mode: bash -*-

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Pas de couleur

# Étape 1: Mise à jour de la liste des paquets et mise à niveau des paquets existants
echo -e "${YELLOW}Étape 1: Mise à jour et mise à niveau des paquets${NC}"
sudo apt update && sudo apt upgrade -y
echo -e "${GREEN}Mise à jour et mise à niveau terminées.${NC}"

# Étape 2: Désinstallation des paquets obsolètes
echo -e "${YELLOW}Étape 2: Désinstallation des paquets obsolètes${NC}"
# Liste des paquets à supprimer
packages_to_remove=(squid-deb-proxy-client)
to_remove=()

for pkg in "${packages_to_remove[@]}"; do
    if dpkg -s $pkg &> /dev/null; then
        echo -e "${RED}Le paquet $pkg sera désinstallé.${NC}"
        to_remove+=($pkg)
    else
        echo -e "${BLUE}Le paquet $pkg n'est pas installé.${NC}"
    fi
done

if [ ${#to_remove[@]} -gt 0 ]; then
    echo -e "${YELLOW}Désinstallation des paquets: ${to_remove[*]}${NC}"
    sudo apt remove -y "${to_remove[@]}"
    echo -e "${GREEN}Désinstallation terminée.${NC}"
else
    echo -e "${GREEN}Aucun paquet à désinstaller.${NC}"
fi

# Étape 3: Installation des nouveaux paquets
echo -e "${YELLOW}Étape 3: Installation des nouveaux paquets${NC}"
# Liste des paquets à installer
packages=(vim bat fd-find zsh fzf sqlite3 git curl wget htop tree ncdu aptitude tmux haveged openssh-server auto-apt-proxy lsd python3-rich)
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
    echo -e "${YELLOW}Installation des paquets: ${to_install[*]}${NC}"
    sudo apt install -y "${to_install[@]}"
    echo -e "${GREEN}Installation des paquets terminée.${NC}"
else
    echo -e "${GREEN}Aucun nouveau paquet à installer.${NC}"
fi

echo -e "${YELLOW}Script terminé.${NC}"
