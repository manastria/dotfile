#!/bin/bash
# install.sh - Installation environnement prof pour dépannage
# Utilisation : `curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/main/install.sh | bash`
set -e  # Arrêt en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$USER" != "prof" ]; then
    echo -e "${YELLOW}=== Configuration environnement prof ===${NC}"
    
    # Phase 1 : créer le compte prof avec mot de passe
    if id "prof" &>/dev/null; then
        echo -e "${GREEN}✓ Compte prof existe déjà${NC}"
    else
        echo -e "${YELLOW}Création du compte prof...${NC}"
        sudo useradd -m -s /bin/bash prof
        echo -e "${GREEN}✓ Compte créé${NC}"
    fi
    
    # Définir le mot de passe
    echo "prof:netlab123" | sudo chpasswd 2>/dev/null
    
    # Relancer le script en tant que prof
    echo -e "${YELLOW}Bascule vers session prof...${NC}"
    su - prof -c "export http_proxy=http://172.16.0.1:3128; curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/dev1/install_prof.sh | bash"
    
else
    # Phase 2 : installer la config yadm
    echo -e "${YELLOW}=== Installation dotfiles prof ===${NC}"
    
    export http_proxy=http://172.16.0.1:3128
    
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
