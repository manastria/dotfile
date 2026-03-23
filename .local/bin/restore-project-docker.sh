#!/bin/bash
set -e

BACKUP_DIR="docker_images_backup"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "❌ Erreur : Dossier '$BACKUP_DIR' introuvable."
  echo "Assurez-vous de lancer ce script depuis la racine du projet décompressé."
  exit 1
fi

echo "--- Chargement des images Docker depuis la sauvegarde ---"

for ARCHIVE in "$BACKUP_DIR"/*.tar; do
  echo "🚢 Chargement de l'image depuis '$ARCHIVE'..."
  docker load -i "$ARCHIVE"
done

echo ""
echo "✅ Restauration des images terminée."
echo "Les images sont maintenant disponibles dans votre cache Docker local."
echo ""
echo "➡️  Pour démarrer le projet, utilisez la commande suivante :"
# Rappel de l'importance du fichier offline
if [ -f "docker-compose.offline.yml" ]; then
    echo "   docker compose -f docker-compose.offline.yml up -d"
else
    echo "   docker compose up -d"
    echo "   (N'oubliez pas de supprimer la section 'build:' de votre docker-compose.yml si nécessaire)"
fi
