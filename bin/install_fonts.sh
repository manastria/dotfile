#!/bin/bash

# Répertoire source : premier argument ou répertoire courant (.) par défaut
SRC_DIR="${1:-.}"
# Répertoire cible pour l'utilisateur
DEST_DIR="$HOME/.local/share/fonts"

echo "--- Installation de polices pour l'utilisateur ---"

# Vérifier si le répertoire source existe
if [ ! -d "$SRC_DIR" ]; then
    echo "Erreur : Le répertoire '$SRC_DIR' n'existe pas."
    exit 1
fi

# Créer le répertoire de destination s'il n'existe pas
mkdir -p "$DEST_DIR"

echo "Recherche de polices dans : $SRC_DIR"

# Trouver et copier les fichiers .ttf et .otf
# On utilise find pour gérer les sous-dossiers éventuels
find "$SRC_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp -v {} "$DEST_DIR/" \;

echo "Mise à jour du cache des polices..."
fc-cache -f

echo "Terminé ! Les polices sont installées dans $DEST_DIR."
