#!/bin/bash

# --- Configuration des couleurs ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Fonctions de log ---
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
error() { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

info "Début de l'installation « omnipotente » de eza..."

# 1. Installation des dépendances nécessaires
info "Vérification des dépendances (gpg, wget)..."
apt update -qq
apt install -y gpg wget > /dev/null 2>&1
success "Dépendances prêtes."

# 2. Gestion de la clé GPG
KEYRING_PATH="/etc/apt/keyrings/gierens.gpg"
if [ ! -f "$KEYRING_PATH" ]; then
    info "Téléchargement et installation de la clé GPG..."
    mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o "$KEYRING_PATH"
    success "Clé GPG installée dans $KEYRING_PATH."
else
    warn "La clé GPG existe déjà. Passage à l'étape suivante."
fi

# 3. Ajout du dépôt APT
LIST_PATH="/etc/apt/sources.list.d/gierens.list"
if [ ! -f "$LIST_PATH" ]; then
    info "Ajout du dépôt eza dans les sources APT..."
    echo "deb [signed-by=$KEYRING_PATH] http://deb.gierens.de stable main" > "$LIST_PATH"
    chmod 644 "$KEYRING_PATH" "$LIST_PATH"
    success "Dépôt ajouté avec succès."
else
    warn "Le dépôt est déjà configuré."
fi

# 4. Installation finale
info "Mise à jour des index et installation de eza..."
apt update -qq
if apt install -y eza > /dev/null 2>&1; then
    success "Félicitations ! « eza » est maintenant installé."
    eza --version | head -n 1
else
    error "Échec de l'installation du paquet eza."
fi

echo -e "\n${GREEN}--- Installation terminée avec succès ---${NC}"
