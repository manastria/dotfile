#!/usr/bin/env bash

# Script pour installer et configurer Atuin, un gestionnaire d'historique de shell avancé.
# Site officiel : https://atuin.sh/
# Documentation : https://docs.atuin.sh/

set -e # Arrête le script si une commande échoue

# --- Fonctions utilitaires ---

# Affiche un message d'information
info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Affiche un message de succès
success() {
    echo -e "\033[1;32m[SUCCÈS]\033[0m $1"
}

# Affiche un message d'erreur et quitte
error() {
    echo -e "\033[1;31m[ERREUR]\033[0m $1" >&2
    exit 1
}

# --- Vérification des prérequis ---

if ! command -v curl &> /dev/null; then
    error "La commande 'curl' est introuvable. Veuillez l'installer avant de continuer."
fi

# --- Installation d'Atuin ---

info "Installation d'Atuin..."
if command -v atuin &> /dev/null; then
    info "Atuin est déjà installé. Mise à jour..."
    # La commande d'installation gère aussi la mise à jour
    bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
else
    bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
fi
success "Atuin a été installé avec succès."

info "Vous pouvez configurer la synchronisation avec :"
info "atuin register -u <VOTRE_NOM_UTILISATEUR> -e <VOTRE_EMAIL>"
info "atuin import auto"
info "atuin sync"
