#!/bin/bash

# ==============================================================================
#
#   Titre : Script de mise à jour complète et non-interactive pour Ubuntu
#   Auteur: Votre Nom (adapté par Gemini)
#   Date :   25/06/2025
#
#   Description :
#   Ce script effectue une mise à jour complète du système (APT, Snap, Firmware)
#   de manière totalement autonome. Il est idéal pour être lancé en début
#   de session de travail ou de cours.
#
#   Fonctionnalités :
#   - Détection et configuration automatique du proxy réseau.
#   - Mise à jour des paquets APT (update, upgrade, dist-upgrade).
#   - Nettoyage des paquets obsolètes (autoremove, autoclean).
#   - Mise à jour des paquets Snap.
#   - Mise à jour des firmwares système via fwupd.
#   - Exécution non-interactive garantie.
#   - Journalisation détaillée dans un fichier de log.
#
# ==============================================================================

# --- Configuration ---
set -euo pipefail # Script robuste : arrête en cas d'erreur

# Proxy du lycée (à adapter si besoin)
PROXY_HOST="172.16.0.1"
PROXY_PORT="3128"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

# Fichier de log pour le suivi
LOG_FILE="/var/log/system-update-script.log"

# Couleurs pour la console
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m' # Pas de couleur


# --- Fonctions ---

# Fonction pour logger les messages sur la console et dans le fichier de log
log_message() {
    local message="$1"
    # Affiche sur la console avec la date
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${message}"
    # Ajoute au fichier de log (sans les couleurs)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $(echo -e "$message" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')" >> "$LOG_FILE"
}

# Gère la configuration du proxy pour APT et Snap
manage_proxy() {
    log_message "${C_BLUE}Vérification de la disponibilité du proxy ${PROXY_HOST}:${PROXY_PORT}...${C_NC}"
    
    # Teste la connexion au proxy avec un timeout de 5 secondes
    if nc -z -w 5 "$PROXY_HOST" "$PROXY_PORT"; then
        log_message "${C_GREEN}Proxy détecté. Configuration pour APT et Snap...${C_NC}"
        # Configuration pour APT
        echo "Acquire::http::Proxy \"${PROXY_URL}\";" > /etc/apt/apt.conf.d/99proxy.conf
        echo "Acquire::https::Proxy \"${PROXY_URL}\";" >> /etc/apt/apt.conf.d/99proxy.conf
        # Configuration pour Snap
        snap set system proxy.http="${PROXY_URL}"
        snap set system proxy.https="${PROXY_URL}"
    else
        log_message "${C_YELLOW}Proxy non disponible. Suppression de la configuration...${C_NC}"
        # Suppression de la configuration pour APT
        rm -f /etc/apt/apt.conf.d/99proxy.conf
        # Suppression de la configuration pour Snap
        snap unset system proxy.http
        snap unset system proxy.https
    fi
}

# Met à jour les paquets APT
update_apt() {
    log_message "${C_BLUE}--- DÉBUT MISE À JOUR APT ---${C_NC}"
    export DEBIAN_FRONTEND=noninteractive # Garantit l'absence de questions
    
    log_message "Mise à jour de la liste des paquets (apt update)..."
    apt-get update -y >> "$LOG_FILE" 2>&1

    log_message "Mise à niveau des paquets installés (apt upgrade)..."
    apt-get upgrade -y >> "$LOG_FILE" 2>&1

    log_message "Mise à niveau de la distribution (apt dist-upgrade)..."
    apt-get dist-upgrade -y >> "$LOG_FILE" 2>&1

    log_message "Nettoyage des dépendances obsolètes (apt autoremove)..."
    apt-get autoremove -y >> "$LOG_FILE" 2>&1

    log_message "Nettoyage du cache des paquets (apt autoclean)..."
    apt-get autoclean -y >> "$LOG_FILE" 2>&1

    log_message "${C_GREEN}--- FIN MISE À JOUR APT ---${C_NC}"
}

# Met à jour les paquets Snap
update_snap() {
    log_message "${C_BLUE}--- DÉBUT MISE À JOUR SNAP ---${C_NC}"
    if command -v snap &> /dev/null; then
        snap refresh >> "$LOG_FILE" 2>&1
        log_message "${C_GREEN}--- FIN MISE À JOUR SNAP ---${C_NC}"
    else
        log_message "${C_YELLOW}Snap n'est pas installé. Étape ignorée.${C_NC}"
    fi
}

# Met à jour les firmwares
update_firmware() {
    log_message "${C_BLUE}--- DÉBUT MISE À JOUR FIRMWARE ---${C_NC}"
    if command -v fwupdmgr &> /dev/null; then
        log_message "Rafraîchissement des sources firmwares..."
        fwupdmgr refresh --force >> "$LOG_FILE" 2>&1
        
        log_message "Installation des mises à jour firmwares..."
        fwupdmgr update -y >> "$LOG_FILE" 2>&1
        
        log_message "${C_GREEN}--- FIN MISE À JOUR FIRMWARE ---${C_NC}"
    else
        log_message "${C_YELLOW}fwupdmgr n'est pas installé. Étape ignorée.${C_NC}"
    fi
}


# --- Exécution Principale ---

# 1. Vérification des prérequis
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${C_RED}ERREUR : Ce script doit être exécuté avec les privilèges root (utilisez sudo).${C_NC}" >&2
   exit 1
fi
if ! command -v nc &> /dev/null; then
    echo -e "${C_RED}ERREUR : La commande 'nc' (netcat) est requise. Veuillez l'installer (sudo apt install netcat-openbsd).${C_NC}" >&2
    exit 1
fi

# 2. Initialisation du log
# Crée le fichier de log s'il n'existe pas et s'assure que root en est le propriétaire
touch "$LOG_FILE"
chown root:root "$LOG_FILE"
echo "" >> "$LOG_FILE" # Ligne de séparation
log_message "${C_YELLOW}========= DÉBUT DU SCRIPT DE MISE À JOUR SYSTÈME =========${C_NC}"

# 3. Lancement des tâches
manage_proxy
update_apt
update_snap
update_firmware

# 4. Message final
log_message "${C_GREEN}========= SCRIPT DE MISE À JOUR TERMINÉ AVEC SUCCÈS =========${C_NC}"
log_message "Un journal détaillé est disponible dans : ${LOG_FILE}"

# Vérifie si un redémarrage est nécessaire
if [ -f /var/run/reboot-required ]; then
    log_message "${C_YELLOW}ATTENTION : Un redémarrage du système est recommandé pour appliquer toutes les mises à jour.${C_NC}"
fi

exit 0
