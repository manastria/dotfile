#!/bin/bash
# -*- mode: bash -*-

# --- Configuration et Préparation ---

# Arête immédiatement le script si une commande échoue
set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Pas de couleur

# --- Vérification des privilèges ---
# Le script doit être lancé avec des privilèges root (sudo)
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Erreur : Ce script doit être exécuté avec les privilèges root (utilisez sudo).${NC}"
    exit 1
fi

# --- Exécution principale ---

# Garantit que les commandes apt ne seront jamais interactives
export DEBIAN_FRONTEND=noninteractive

# Étape 1: Mise à jour de la liste des paquets et mise à niveau des paquets existants
echo -e "${YELLOW}Étape 1: Mise à jour et mise à niveau des paquets${NC}"
apt update && apt upgrade -y
echo -e "${GREEN}Mise à jour et mise à niveau terminées.${NC}\n"

# Étape 2: Désinstallation des paquets obsolètes
echo -e "${YELLOW}Étape 2: Désinstallation des paquets obsolètes${NC}"
packages_to_remove=(squid-deb-proxy-client)
to_remove=()

for pkg in "${packages_to_remove[@]}"; do
    if dpkg -s "$pkg" &> /dev/null; then
        echo -e "${BLUE}Le paquet $pkg sera désinstallé.${NC}"
        to_remove+=("$pkg")
    else
        echo -e "${BLUE}Le paquet $pkg n'est pas installé.${NC}"
    fi
done

if [ ${#to_remove[@]} -gt 0 ]; then
    echo -e "${YELLOW}Désinstallation des paquets: ${to_remove[*]}${NC}"
    apt remove -y "${to_remove[@]}"
    echo -e "${GREEN}Désinstallation terminée.${NC}"
else
    echo -e "${GREEN}Aucun paquet à désinstaller.${NC}"
fi
echo "" # Ajoute un saut de ligne pour la lisibilité

# Étape 3: Installation des nouveaux paquets
echo -e "${YELLOW}Étape 3: Installation des nouveaux paquets${NC}"
packages=(
    aptitude
    auto-apt-proxy
    bat
    curl
    direnv
    fd-find
    fzf
    gh
    git
    git-lfs
    haveged
    htop
    lsd
    ncdu
    openssh-server
    python3-rich
    sqlite3
    tmux
    tree
    vim
    wget
    zsh
)
packages+=(
    build-essential
    dkms
    module-assistant
) # Pour VirtualBox Addons
to_install=()

if dpkg -l | grep -q xserver-common; then # Légère amélioration du test
    echo -e "${BLUE}Environnement graphique détecté. Ajout de paquets spécifiques.${NC}"
    packages+=(terminator)
else
    echo -e "${BLUE}Aucun environnement graphique détecté.${NC}"
fi

for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" &> /dev/null; then
        echo -e "${BLUE}Le paquet $pkg est déjà installé.${NC}"
    else
        if apt-cache show "$pkg" &> /dev/null; then
            echo -e "${GREEN}Le paquet $pkg sera installé.${NC}"
            to_install+=("$pkg")
        else
            echo -e "${RED}Attention : Le paquet $pkg n'existe pas dans les dépôts et sera ignoré.${NC}"
        fi
    fi
done

if [ ${#to_install[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installation des paquets: ${to_install[*]}${NC}"
    apt install -y "${to_install[@]}"
    echo -e "${GREEN}Installation des paquets terminée.${NC}"
else
    echo -e "${GREEN}Aucun nouveau paquet à installer.${NC}"
fi
echo ""

# Étape 4: Nettoyage du système
echo -e "${YELLOW}Étape 4: Nettoyage des dépendances inutiles${NC}"
apt autoremove -y
echo -e "${GREEN}Nettoyage terminé.${NC}\n"

echo -e "${YELLOW}Script terminé avec succès.${NC}"
