#!/bin/bash
#
# Fichier : change-hostname.sh
# Description : Script pour changer le hostname d'une machine Debian 12
#              et mettre à jour le fichier /etc/hosts
#
# Usage : ./change-hostname.sh <nouveau_hostname>
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

if [ $# -ne 1 ]; then
    die "Usage: $0 <nouveau_hostname>  —  Exemple : $0 debian-tp01"
fi

NEW_HOSTNAME="$1"
OLD_HOSTNAME=$(hostname)

if ! [[ $NEW_HOSTNAME =~ ^[a-zA-Z0-9-]+$ ]]; then
    die "Le hostname ne peut contenir que des lettres, des chiffres et des tirets"
fi

info "Changement du hostname : ${OLD_HOSTNAME} → ${NEW_HOSTNAME}"
hostnamectl set-hostname "$NEW_HOSTNAME"
success "Hostname système mis à jour"

BACKUP_FILE="/etc/hosts.backup.$(date -I'seconds')"
cp /etc/hosts "$BACKUP_FILE"
info "Sauvegarde créée : ${BACKUP_FILE}"

sed -i "s/\b$OLD_HOSTNAME\b/$NEW_HOSTNAME/g" /etc/hosts

if ! grep -q "127.0.0.1.*localhost" /etc/hosts; then
    echo "127.0.0.1 localhost" >> /etc/hosts
fi

if ! grep -q "127.0.1.1.*$NEW_HOSTNAME" /etc/hosts; then
    echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
fi

if [ "$(hostname)" = "$NEW_HOSTNAME" ]; then
    success "/etc/hosts mis à jour"
    success "Hostname changé avec succès en : ${BOLD}${NEW_HOSTNAME}${RESET}"
else
    die "Le changement de hostname a échoué"
fi
