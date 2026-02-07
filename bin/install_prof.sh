#!/bin/bash
# install.sh - Installation environnement prof pour dépannage
# Utilisation : `export http_proxy=http://172.16.0.1:3128; curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/refs/heads/dev1/bin/install_prof.sh | bash"`
set -e  # Arrêt en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Détection du proxy (hérite de l'environnement actuel ou utilise le défaut)
if [ -z "$http_proxy" ] && [ -z "$HTTP_PROXY" ]; then
    # Tenter de détecter si on est dans l'établissement
    if ping -c 1 -W 1 172.16.0.1 &>/dev/null; then
        export http_proxy=http://172.16.0.1:3128
        export https_proxy=http://172.16.0.1:3128
        echo -e "${YELLOW}Proxy détecté : $http_proxy${NC}"
    else
        echo -e "${GREEN}Pas de proxy détecté, connexion directe${NC}"
    fi
fi

if [ "$USER" != "prof" ]; then
    echo -e "${YELLOW}=== Configuration environnement prof ===${NC}"
    
    # Phase 1 : créer le compte prof avec mot de passe
    if id "prof" &>/dev/null; then
        echo -e "${GREEN}✓ Compte prof existe déjà${NC}"
        echo "prof:netlab123" | sudo chpasswd 2>/dev/null
    else
        echo -e "${YELLOW}Création du compte prof...${NC}"
        # IMPORTANT : grouper useradd et chpasswd dans le même sudo
        sudo sh -c 'useradd -m -s /bin/bash prof && echo "prof:netlab123" | chpasswd'
        echo -e "${GREEN}✓ Compte créé${NC}"
    fi
    
    # Relancer le script en tant que prof (propager le proxy)
    echo -e "${YELLOW}Bascule vers session prof...${NC}"
    PROXY_ENV=""
    [ -n "$http_proxy" ] && PROXY_ENV="export http_proxy=$http_proxy https_proxy=$https_proxy;"
    su - prof -c "$PROXY_ENV curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/refs/heads/dev1/bin/install_prof.sh | bash"
    
else
    # Phase 2 : installer la config yadm
    echo -e "${YELLOW}=== Installation dotfiles prof ===${NC}"
    
    # Installer yadm si nécessaire
    if ! command -v yadm &>/dev/null; then
        echo -e "${YELLOW}Installation de yadm...${NC}"
        sudo -E apt update -qq && sudo -E apt install -y yadm
        echo -e "${GREEN}✓ yadm installé${NC}"
    else
        echo -e "${GREEN}✓ yadm déjà installé${NC}"
    fi
    
    # Cloner la configuration
    if [ -d "$HOME/.local/share/yadm/repo.git" ]; then
        echo -e "${YELLOW}Mise à jour de la configuration existante...${NC}"
        yadm pull
    else
        echo -e "${YELLOW}Clonage de la configuration...${NC}"
        yadm clone https://github.com/manastria/dotfile.git
    fi
    
    yadm reset --hard @{u}
    
    echo -e "${GREEN}=== ✓ Configuration prof prête ! ===${NC}"
    echo -e "${YELLOW}Vous êtes maintenant dans la session prof.${NC}"
    echo -e "${YELLOW}Pour revenir à la session étudiant : exit${NC}"
fi
