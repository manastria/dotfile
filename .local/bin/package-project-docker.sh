#!/bin/bash

# Arrête le script si une commande échoue ou si une variable n'est pas définie
set -euo pipefail

# --- Vérification initiale ---
if [ ! -f "docker-compose.yml" ]; then
  echo "❌ Erreur : Fichier 'docker-compose.yml' introuvable."
  echo "Veuillez lancer ce script depuis la racine d'un projet Docker Compose."
  exit 1
fi

PROJECT_DIR_NAME=$(basename "$PWD")
BACKUP_DIR="docker_images_backup"

# --- Étape 1 : Sauvegarde des images Docker ---
echo "--- 1/3 : Sauvegarde des images Docker locales ---"
mkdir -p "$BACKUP_DIR"
IMAGE_LIST=$(docker compose images | awk 'NR>1 {print $2":"$3}')

if [ -z "$IMAGE_LIST" ]; then
  echo "⚠️ Aucune image trouvée. Assurez-vous d'avoir lancé 'docker compose build'."
  rm -rf "$BACKUP_DIR" # Nettoyage
  exit 1
fi

for IMAGE in $IMAGE_LIST; do
  FILENAME=$(echo "$IMAGE" | tr '/:' '_').tar
  echo "💾 Sauvegarde de '$IMAGE'..."
  docker save -o "$BACKUP_DIR/$FILENAME" "$IMAGE"
done

# --- Étape 2 : Création de l'archive complète du projet ---
echo "--- 2/3 : Création de l'archive du projet ---"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H%M%SZ")
ARCHIVE_NAME="${PROJECT_DIR_NAME}_${TIMESTAMP}.tar.zst"

echo "📦 Compression de '$PROJECT_DIR_NAME' vers '../$ARCHIVE_NAME'..."
# On se place dans le répertoire parent pour créer une archive propre
(
  cd .. && \
  # zstd est un compresseur moderne et très rapide. Alternative : bzip2 -> -cjf
  tar -c -I 'zstd -T0' -f "$ARCHIVE_NAME" "$PROJECT_DIR_NAME"
)

# --- Étape 3 : Nettoyage ---
echo "--- 3/3 : Nettoyage du dossier temporaire ---"
rm -rf "$BACKUP_DIR"

echo ""
echo "✅ Opération terminée avec succès !"
echo "Votre projet a été archivé ici : ../$ARCHIVE_NAME"
echo "Vous pouvez maintenant distribuer ce fichier."
