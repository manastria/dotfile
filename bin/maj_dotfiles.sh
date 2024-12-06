#!/bin/bash
set -euo pipefail

# Si nous ne sommes pas déjà dans une copie temporaire
if [ "${TEMP_COPY:-}" != "true" ]; then
    # Création d'un répertoire temporaire
    TEMP_DIR=$(mktemp -d)
    SCRIPT_NAME=$(basename "$0")
    SCRIPT_PATH=$(readlink -f "$0")

    cleanup() {
        rm -rf "$TEMP_DIR"
    }
    trap cleanup EXIT

    # Copie du script dans le répertoire temporaire
    cp "$SCRIPT_PATH" "$TEMP_DIR/$SCRIPT_NAME"
    chmod +x "$TEMP_DIR/$SCRIPT_NAME"

    # Relance le script depuis la copie temporaire
    export TEMP_COPY=true
    exec "$TEMP_DIR/$SCRIPT_NAME"
fi

# À partir d'ici, nous travaillons depuis la copie temporaire
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Début de la mise à jour des dotfiles"

# Sauvegarde des modifications locales si nécessaire
if ! yadm diff --quiet; then
    log "Des modifications locales ont été détectées"
    log "Sauvegarde des modifications locales"
    yadm stash
    STASHED=true
else
    STASHED=false
fi

# Mise à jour depuis le dépôt distant
log "Récupération des mises à jour depuis le dépôt distant"
yadm pull

# Reset hard vers origin/master
log "Application des modifications avec reset --hard"
yadm reset --hard origin/master

# Restauration des modifications locales si nécessaire
if [ "$STASHED" = true ]; then
    log "Restauration des modifications locales"
    yadm stash pop
fi

log "Mise à jour terminée avec succès"
