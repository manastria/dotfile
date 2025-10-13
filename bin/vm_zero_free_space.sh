#!/bin/bash

# ==============================================================================
#  Script de nettoyage de l'espace disque libre pour optimisation de VM
#  Auteur : Votre Nom
#  Date   : 13/10/2025
#  Version: 1.1
# ==============================================================================

# --- Configuration ---
# Fichier de log pour suivre l'exécution du script.
LOG_FILE="/var/log/vm_cleanup.log"
# Point de montage à nettoyer. Pour plusieurs partitions, voir la section "Pour aller plus loin".
TARGET_MOUNT="/"
# Nom du fichier temporaire. '$$' est l'ID du processus pour un nom unique.
TEMP_FILE_PATH="${TARGET_MOUNT%/}/EMPTY_$$"


# --- Fonctions ---
# Fonction pour enregistrer les messages dans le log et sur la console.
log() {
    # Formate le message avec la date et l'heure.
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Fonction de nettoyage, exécutée à la fin du script ou en cas d'interruption.
cleanup() {
    log "INFO: Fin du script ou interruption détectée. Lancement du nettoyage..."
    if [ -f "$TEMP_FILE_PATH" ]; then
        log "INFO: Suppression du fichier temporaire '$TEMP_FILE_PATH'..."
        rm -f "$TEMP_FILE_PATH"
        sync
        log "INFO: Fichier temporaire supprimé."
    else
        log "INFO: Aucun fichier temporaire à supprimer."
    fi
}


# --- Script principal ---

# 'trap' : exécute la fonction 'cleanup' lorsque le script se termine (EXIT)
# ou est interrompu (INT, TERM). C'est une sécurité cruciale.
trap cleanup EXIT INT TERM

# Redirige toute la sortie (stdout et stderr) vers la fonction de logging.
# exec > >(tee -a "$LOG_FILE") 2>&1 # Décommenter pour une journalisation complète

log "--- Début du script de nettoyage de disque ---"

# 1. Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   log "ERREUR: Ce script doit être exécuté avec les privilèges root (sudo)."
   exit 1
fi

# 2. Lancer fstrim (pour SSD et disques 'thin provisioned')
# Informe l'hyperviseur des blocs qui peuvent être libérés.
log "INFO: Exécution de 'fstrim -av'..."
fstrim -av

# 3. Remplir l'espace libre avec des zéros
log "INFO: Création du fichier temporaire '$TEMP_FILE_PATH' pour remplir l'espace libre."
log "INFO: Cette opération va continuer jusqu'à ce que le disque soit plein. C'est le comportement attendu."

# La commande 'dd' va échouer avec une erreur "No space left on device".
# C'est notre condition de succès ! On ignore donc cette erreur spécifique.
# 'oflag=direct' contourne le cache du système pour de meilleures performances.
dd if=/dev/zero of="$TEMP_FILE_PATH" bs=16M oflag=direct status=progress || true

# 4. Synchronisation des caches
# Force l'écriture de toutes les données en mémoire cache sur le disque.
log "INFO: Synchronisation des données sur le disque (sync)..."
sync

log "--- Script terminé avec succès ---"

# La fonction 'cleanup' enregistrée par 'trap' s'exécutera automatiquement ici pour supprimer le fichier.
