#!/bin/bash

# Vérification de l'argument
if [ -z "$1" ]; then
    echo "Usage: $0 <nom_du_fichier_crypt>"
    exit 1
fi

SOURCE="$1"
# Logique de suffixe : retire _crypt si présent, puis ajoute _uncrypt
BASE_NAME="${SOURCE%_crypt}"
DESTINATION="${BASE_NAME}_uncrypt"

# Vérification si la destination existe
if [ -f "$DESTINATION" ]; then
    echo -n "Le fichier « $DESTINATION » existe déjà. Voulez-vous l'écraser ? (o/n) : "
    read -r choice
    if [ "$choice" != "o" ]; then
        echo "Opération annulée."
        exit 1
    fi
fi

# Déchiffrement
if gpg -d --output "$DESTINATION" "$SOURCE"; then
    echo "---"
    echo "Succès : « $SOURCE » a été déchiffré vers « $DESTINATION »."
else
    echo "Erreur lors du déchiffrement."
    exit 1
fi
