#!/bin/bash
# -*- mode: bash -*-

# ==============================================================================
#
#   AUTEUR : Manastria
#   DATE :   25/06/2025
#   VERSION: 1.1
#
# ------------------------------------------------------------------------------
#
#   DESCRIPTION
#
#   Ce script a pour but de synchroniser de manière "forcée" les dotfiles
#   locaux gérés par l'outil 'yadm' avec leur version sur le dépôt distant.
#
#   Son objectif est de s'assurer que la configuration locale est strictement
#   identique à celle de la branche principale du dépôt, tout en essayant
#   de préserver les modifications locales non encore validées ("commitées").
#
# ------------------------------------------------------------------------------
#
#   FONCTIONNEMENT DÉTAILLÉ
#
#   1.  Sauvegarde : Détecte les modifications locales et, s'il y en a,
#       les met en réserve via `yadm stash`.
#   2.  Récupération : Récupère les dernières données du dépôt distant
#       avec `yadm fetch`.
#   3.  Synchronisation Forcée : Réinitialise la branche locale pour qu'elle
#       corresponde exactement à la branche distante (`yadm reset --hard`).
#       ATTENTION : Cette étape supprime tous les commits locaux qui
#       n'ont pas été poussés vers le dépôt distant.
#   4.  Restauration : Si des modifications avaient été mises en réserve,
#       le script tente de les réappliquer avec `yadm stash pop`.
#
# ------------------------------------------------------------------------------
#
#   PARTICULARITÉ : AUTO-MISE À JOUR SÉCURISÉE
#
#   Pour éviter un conflit où le script modifierait son propre fichier en cours
#   d'exécution (s'il est lui-même versionné dans les dotfiles), il implémente
#   un mécanisme de sécurité :
#     a. À son premier lancement, il se copie dans un répertoire temporaire.
#     b. Il se relance immédiatement depuis cette copie temporaire.
#   La suite des opérations s'effectue donc depuis un emplacement sûr,
#   permettant à la version originale du script d'être mise à jour sans risque.
#
# ------------------------------------------------------------------------------
#
#   DÉPENDANCES
#
#   - bash
#   - yadm (et donc git)
#   - coreutils (mktemp, readlink, basename...)
#
# ==============================================================================

# 'set -e': Arrête le script immédiatement si une commande échoue.
# 'set -u': Traite les variables non définies comme une erreur.
# 'set -o pipefail': Si une commande dans un pipe échoue, c'est toute la ligne qui est considérée comme en échec.
set -euo pipefail

# --- MÉCANISME D'AUTO-COPIE ---
# Ce bloc s'assure que le script s'exécute depuis un répertoire temporaire
# pour éviter les problèmes s'il se met à jour lui-même via yadm.

# On vérifie si la variable d'environnement TEMP_COPY est définie à "true".
# Si ce n'est pas le cas, cela signifie que c'est la première exécution du script.
# "${TEMP_COPY:-}" est une syntaxe pour éviter une erreur "unbound variable" si `set -u` est actif.
if [ "${TEMP_COPY:-}" != "true" ]; then
    # Crée un répertoire temporaire sécurisé et unique. La variable TEMP_DIR contiendra son chemin.
    TEMP_DIR=$(mktemp -d)
    # Récupère juste le nom du fichier du script (ex: "mon_script.sh").
    SCRIPT_NAME=$(basename "$0")
    # Récupère le chemin absolu et résolu du script (sans liens symboliques).
    SCRIPT_PATH=$(readlink -f "$0")

    # Définit une fonction 'cleanup' qui sera chargée de supprimer le répertoire temporaire.
    cleanup() {
        rm -rf "$TEMP_DIR"
    }
    # 'trap' est un mécanisme qui exécute une commande lors de la réception d'un signal.
    # Ici, la fonction 'cleanup' sera automatiquement appelée à la fin du script (EXIT),
    # que celui-ci se termine normalement ou sur une erreur. C'est une garantie de nettoyage.
    trap cleanup EXIT

    # Copie le script actuel vers le répertoire temporaire.
    cp "$SCRIPT_PATH" "$TEMP_DIR/$SCRIPT_NAME"
    # S'assure que la copie est exécutable.
    chmod +x "$TEMP_DIR/$SCRIPT_NAME"

    # Définit la variable d'environnement pour la future exécution.
    # Cela empêchera le script relancé d'entrer à nouveau dans cette boucle `if`.
    export TEMP_COPY=true
    
    # 'exec' remplace le processus shell actuel par la commande spécifiée.
    # Le script se relance donc depuis la copie temporaire. Le script original s'arrête ici.
    exec "$TEMP_DIR/$SCRIPT_NAME"
fi

# --- LOGIQUE PRINCIPALE DU SCRIPT ---
# À partir d'ici, nous sommes certains de travailler depuis la copie temporaire dans /tmp.

# Fonction simple pour logger les messages avec un horodatage.
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Début de la mise à jour des dotfiles"

# Détection de la branche principale pour plus de flexibilité (main vs master)
MAIN_BRANCH=$(yadm symbolic-ref --short HEAD)
log "Branche détectée : ${MAIN_BRANCH}"

# Vérifie s'il y a des modifications locales non commitées dans les dotfiles.
# `yadm diff --quiet` ne produit aucune sortie et renvoie un code de sortie 0 s'il n'y a pas de diff.
if ! yadm diff --quiet; then
    log "Des modifications locales ont été détectées. Mise en réserve (stash)..."
    # Met les modifications de côté dans le "stash" de git.
    yadm stash
    # Un drapeau pour se souvenir qu'on a mis des choses de côté.
    STASHED=true
else
    # Aucune modification locale, on ne fera rien avec le stash.
    STASHED=false
fi

# 1. Récupère les objets et les références depuis le dépôt distant
log "Récupération des objets depuis le dépôt distant (fetch)"
yadm fetch origin

# 2. Force la synchronisation
# C'est l'étape la plus "agressive". Elle force la copie de travail locale
# à être identique à celle de la branche 'master' sur 'origin'.
# Cela écrase tous les changements locaux et résout les conflits en faveur du distant.
log "Synchronisation forcée avec origin/${MAIN_BRANCH} (reset --hard)"
yadm reset --hard "origin/${MAIN_BRANCH}"

# Si on avait mis des modifications de côté au début...
if [ "$STASHED" = true ]; then
    log "Restauration des modifications locales depuis la réserve (stash pop)"
    # On désactive 'set -e' temporairement pour gérer l'échec potentiel
    set +e
    yadm stash pop
    # On vérifie le code de sortie de la dernière commande
    if [ $? -ne 0 ]; then
        set -e # On réactive le mode d'échec immédiat
        log "${RED}ERREUR : Conflit lors de l'application du stash.${NC}"
        log "Veuillez résoudre les conflits manuellement avec 'yadm status' et 'yadm stash apply'."
        exit 1
    fi
    set -e # On réactive le mode d'échec immédiat si tout s'est bien passé
fi

log "Mise à jour terminée avec succès"
