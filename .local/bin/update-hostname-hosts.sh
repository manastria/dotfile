#!/bin/bash

# Récupération du nom d'hôte court
SHORT_HOSTNAME=$(hostname -s 2>/dev/null || hostname)

# Récupération du domaine, avec une valeur par défaut si vide
DOMAIN=$(hostname -d 2>/dev/null)
if [ -z "$DOMAIN" ]; then
    DOMAIN="localdomain"
fi

# Construction du FQDN
FQDN="${SHORT_HOSTNAME}.${DOMAIN}"
HOSTS_FILE="/etc/hosts"

# La ligne au format standard à insérer
EXPECTED_LINE="127.0.1.1\t$FQDN\t$SHORT_HOSTNAME"

# 1. Vérification stricte (idempotence pour les lancements multiples)
if grep -q "^127\.0\.1\.1[[:space:]]\+$FQDN[[:space:]]\+$SHORT_HOSTNAME$" "$HOSTS_FILE"; then
    echo "Opération ignorée : le fichier hosts est déjà à jour pour « $FQDN »."
    exit 0
fi

# 2. Mise à jour ou ajout
if grep -q "^127\.0\.1\.1" "$HOSTS_FILE"; then
    # Remplacement si l'IP de loopback est présente mais avec de mauvaises valeurs
    sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$FQDN\t$SHORT_HOSTNAME/" "$HOSTS_FILE"
    echo "Le fichier hosts a été mis à jour avec le FQDN : « $FQDN »."
else
    # Ajout de la nouvelle ligne à la fin du fichier
    echo -e "$EXPECTED_LINE" | sudo tee -a "$HOSTS_FILE" > /dev/null
    echo "Le nom d'hôte et le FQDN « $FQDN » ont été ajoutés."
fi
