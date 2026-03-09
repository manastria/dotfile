#!/bin/bash

# Vérification de l'argument
if [ -z "$1" ]; then
    echo "Usage: $0 <nom_du_fichier>"
    exit 1
fi

SOURCE="$1"
# Logique de suffixe : retire _uncrypt si présent, puis ajoute _crypt
BASE_NAME="${SOURCE%_uncrypt}"
DESTINATION="${BASE_NAME}_crypt"

# Vérification si la destination existe
if [ -f "$DESTINATION" ]; then
    echo -n "Le fichier « $DESTINATION » existe déjà. Voulez-vous l'écraser ? (o/n) : "
    read -r choice
    if [ "$choice" != "o" ]; then
        echo "Opération annulée."
        exit 1
    fi
fi

# Chiffrement symétrique
# L'absence de l'option --batch force GPG à demander le mot de passe de manière sécurisée
if gpg -c --output "$DESTINATION" "$SOURCE"; then
    echo "---"
    echo "Succès : « $SOURCE » a été chiffré vers « $DESTINATION »."
else
    echo "Erreur lors du chiffrement."
    exit 1
fi
