#!/bin/bash

# --- Configuration ---
# Adresse IP et port du proxy du lycée
PROXY_HOST="172.16.0.1"
PROXY_PORT="3128"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

# Liste des paquets snap à installer. Plus facile à maintenir !
SNAPS_TO_INSTALL=(
    "code --classic"
    "obsidian --classic"
    "brave"
    "vivaldi"
    "onlyoffice-desktopeditors"
)

# --- Couleurs pour l'affichage ---
# Pour rendre la sortie plus lisible
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # Pas de couleur

# --- Vérification des dépendances ---
# On s'assure que la commande `nc` (netcat) est disponible avant de continuer.
if ! command -v nc >/dev/null 2>&1; then
    echo -e "${C_RED}ERREUR CRITIQUE : La commande 'nc' (netcat) est introuvable.${C_NC}"
    echo "Cet outil est nécessaire pour la détection automatique du proxy."
    echo "Veuillez l'installer en utilisant le gestionnaire de paquets de votre distribution."
    echo "Exemples :"
    echo "  - Sur Debian/Ubuntu/Mint :   sudo apt update && sudo apt install netcat-openbsd"
    echo "  - Sur Fedora/CentOS/RHEL :   sudo dnf install nmap-ncat"
    echo "  - Sur Arch Linux :           sudo pacman -S openbsd-netcat"
    exit 1
fi


# --- Fonctions ---

# Affiche une aide simple
show_help() {
    echo "Usage: $(basename "$0") [OPTION]"
    echo "Installe ou met à jour une liste de logiciels via Snap."
    echo ""
    echo "Options:"
    echo "  --proxy        Force l'utilisation du proxy."
    echo "  --no-proxy     Force la désactivation du proxy."
    echo "  --help         Affiche cette aide."
    echo ""
    echo -e "Si aucune option n'est spécifiée, le script tentera de détecter le proxy automatiquement."
}

# Fonction pour tester si le proxy est accessible
# Utilise netcat (nc) pour un test rapide avec un timeout. C'est plus fiable que ping.
test_proxy() {
    echo -e "${C_BLUE}ℹ️  Tentative de connexion au proxy ${PROXY_HOST} sur le port ${PROXY_PORT}...${C_NC}"
    # nc -z: Zero-I/O mode (scan). -w 5: Timeout de 5 secondes.
    if nc -z -w 5 "$PROXY_HOST" "$PROXY_PORT"; then
        return 0 # Succès (le proxy est joignable)
    else
        return 1 # Échec (le proxy est injoignable)
    fi
}

# Fonction pour configurer le proxy pour Snap
configure_proxy() {
    echo -e "${C_YELLOW}🔧 Configuration du proxy Snap : ${PROXY_URL}${C_NC}"
    sudo snap set system proxy.http="${PROXY_URL}"
    sudo snap set system proxy.https="${PROXY_URL}"
    echo -e "${C_GREEN}✅ Proxy configuré avec succès.${C_NC}"
}

# Fonction pour désactiver le proxy pour Snap
disable_proxy() {
    echo -e "${C_YELLOW}🔧 Désactivation du proxy Snap...${C_NC}"
    sudo snap unset system proxy.http
    sudo snap unset system proxy.https
    echo -e "${C_GREEN}✅ Proxy désactivé avec succès.${C_NC}"
}

# Fonction principale pour installer les logiciels
install_snaps() {
    echo -e "\n${C_BLUE}--- DÉBUT DE L'INSTALLATION DES LOGICIELS SNAP ---${C_NC}"
    
    echo -e "${C_BLUE}🔄 Mise à jour de Snap...${C_NC}"
    snap refresh
    
    for snap_package in "${SNAPS_TO_INSTALL[@]}"; do
        # L'espace dans "code --classic" est intentionnel, on ne met pas de guillemets autour de $snap_package ici.
        echo -e "\n${C_BLUE}▶️  Installation de : ${snap_package}${C_NC}"
        sudo snap install $snap_package
        if [ $? -eq 0 ]; then
            echo -e "${C_GREEN}✅ ${snap_package} installé avec succès.${C_NC}"
        else
            echo -e "${C_RED}❌ Une erreur est survenue lors de l'installation de ${snap_package}.${C_NC}"
        fi
    done
    
    echo -e "\n${C_GREEN}--- INSTALLATION TERMINÉE ---${C_NC}"
}


# --- Exécution du Script ---

# Vérifier si l'utilisateur demande de l'aide
if [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

# Gestion du proxy basée sur les arguments ou la détection automatique
echo -e "${C_BLUE}--- GESTION DU PROXY ---${C_NC}"
if [ "$1" == "--proxy" ]; then
    echo -e "${C_YELLOW}⚠️  Argument --proxy détecté. Forçage de la configuration du proxy.${C_NC}"
    configure_proxy
elif [ "$1" == "--no-proxy" ]; then
    echo -e "${C_YELLOW}⚠️  Argument --no-proxy détecté. Forçage de la désactivation du proxy.${C_NC}"
    disable_proxy
else
    echo -e "${C_BLUE}ℹ️  Aucun argument spécifié, détection automatique du proxy...${C_NC}"
    if test_proxy; then
        echo -e "${C_GREEN}👍 Le proxy est accessible. Activation...${C_NC}"
        configure_proxy
    else
        echo -e "${C_RED}👎 Le proxy n'est pas accessible (timeout). Désactivation...${C_NC}"
        disable_proxy
    fi
fi

# Lancer l'installation
install_snaps

exit 0
