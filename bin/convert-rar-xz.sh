#!/bin/bash

# --- CONFIGURATION ---
# Définition de la variable d'environnement pour xz
# -T0 : Utilise tous les cœurs CPU disponibles (Multithreading)
# -6  : Niveau de compression (moyen-haut, bon compromis vitesse/taille)
export XZ_OPT="-T0 -6"

# --- FONCTION D'AIDE ---
usage() {
    echo "Usage: $0 [-t] fichier.rar"
    echo "  -t : Ajoute un horodatage (date/heure) au nom du fichier de sortie"
    exit 1
}

# --- GESTION DES ARGUMENTS (PARSING) ---
USE_TIMESTAMP=false

# Analyse des options (flags)
while getopts "t" opt; do
    case ${opt} in
        t) USE_TIMESTAMP=true ;;
        *) usage ;;
    esac
done
# Décale les arguments pour accéder au nom du fichier après les options
shift $((OPTIND -1))

# Vérification de la présence du fichier d'entrée
INPUT_FILE="$1"
if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo "Erreur : Fichier '$INPUT_FILE' introuvable."
    usage
fi

# --- PRÉPARATION DES NOMS ---
# Extraction du nom de fichier sans l'extension .rar ni le chemin
BASENAME=$(basename "$INPUT_FILE" .rar)
DIRNAME=$(dirname "$INPUT_FILE")

if [ "$USE_TIMESTAMP" = true ]; then
    # Format : AAAA-MM-JJ_HHMMSS
    TIMESTAMP="_$(date +%Y-%m-%d_%H%M%S)"
else
    TIMESTAMP=""
fi

OUTPUT_FILE="${DIRNAME}/${BASENAME}${TIMESTAMP}.tar.xz"

# --- GESTION DU RÉPERTOIRE TEMPORAIRE ---
# Création sécurisée d'un dossier temporaire
TEMP_DIR=$(mktemp -d -t rar2xz-XXXXXXXXXX)

# 'trap' assure la suppression du dossier temporaire même en cas d'erreur ou d'interruption (CTRL+C)
trap "rm -rf '$TEMP_DIR'" EXIT

echo "« Traitement de $INPUT_FILE... »"

# --- EXTRACTION ---
# On extrait dans le dossier temporaire
# -inul : Désactive l'affichage des noms de fichiers (moins de bruit dans le terminal)
unrar x -inul "$INPUT_FILE" "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo "Erreur lors de l'extraction de l'archive RAR."
    exit 1
fi

# --- COMPRESSION ---
# On compresse le contenu du dossier temporaire
# -C : Change de répertoire avant de compresser (évite d'inclure le chemin /tmp/...)
tar -cJf "$OUTPUT_FILE" -C "$TEMP_DIR" .

if [ $? -eq 0 ]; then
    echo "Succès ! Archive créée : « $OUTPUT_FILE »"
else
    echo "Erreur lors de la création de l'archive TAR.XZ."
    exit 1
fi
