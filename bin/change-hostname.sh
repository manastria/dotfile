#!/bin/bash
#
# Fichier : change-hostname.sh
# Description : Script pour changer le hostname d'une machine Debian 12
#              et mettre à jour le fichier /etc/hosts
# 
# Usage : sudo ./change-hostname.sh <nouveau_hostname>
#

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Fonction pour afficher les erreurs en rouge
error_message() {
    echo -e "${RED}Erreur: $1${NC}" >&2
}

# Vérifie que le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    error_message "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérifie qu'un argument a été fourni
if [ $# -ne 1 ]; then
    error_message "Usage: $0 <nouveau_hostname>"
    echo "Example: $0 debian-tp01"
    exit 1
fi

NEW_HOSTNAME="$1"
OLD_HOSTNAME=$(hostname)

# Valide le format du hostname (lettres, chiffres, tirets)
if ! [[ $NEW_HOSTNAME =~ ^[a-zA-Z0-9-]+$ ]]; then
    error_message "Le hostname ne peut contenir que des lettres, des chiffres et des tirets"
    exit 1
fi

# Change le hostname immédiatement
hostnamectl set-hostname "$NEW_HOSTNAME"

# Crée le backup avec timestamp ISO
BACKUP_FILE="/etc/hosts.backup.$(date -I'seconds')"
cp /etc/hosts "$BACKUP_FILE"

# Met à jour /etc/hosts
# Remplace l'ancien hostname par le nouveau dans /etc/hosts
sed -i "s/\b$OLD_HOSTNAME\b/$NEW_HOSTNAME/g" /etc/hosts

# Vérifie si localhost est présent, sinon l'ajoute
if ! grep -q "127.0.0.1.*localhost" /etc/hosts; then
    echo "127.0.0.1 localhost" >> /etc/hosts
fi

# Vérifie si le nouveau hostname est présent, sinon l'ajoute
if ! grep -q "127.0.1.1.*$NEW_HOSTNAME" /etc/hosts; then
    echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
fi

# Vérifie que les changements ont été appliqués
NEW_HOSTNAME_CHECK=$(hostname)
if [ "$NEW_HOSTNAME_CHECK" = "$NEW_HOSTNAME" ]; then
    echo -e "${GREEN}Le hostname a été changé avec succès en: $NEW_HOSTNAME${NC}"
    echo -e "${GREEN}Le fichier /etc/hosts a été mis à jour${NC}"
    echo -e "${GREEN}Une sauvegarde de l'ancien fichier hosts a été créée: $BACKUP_FILE${NC}"
else
    error_message "Le changement de hostname a échoué"
    exit 1
fi
