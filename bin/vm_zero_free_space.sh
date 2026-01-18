#!/bin/bash

# ==============================================================================
#  Script de nettoyage et d'optimisation (Zero-Fill) pour export OVA
#  Auteur : Manastria
#  Date   : 13/10/2025
#  Version: 2.0
# ==============================================================================

# --- Configuration ---
LOG_FILE="/var/log/vm_cleanup.log"
TARGET_MOUNT="/"
TEMP_FILE_PATH="${TARGET_MOUNT%/}/EMPTY_$$"

# --- Fonctions ---

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

cleanup() {
    echo "" # Saut de ligne pour la lisibilité après la barre de progression dd
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

clean_system() {
    log "INFO: [1/5] Nettoyage des paquets apt (clean & autoremove)..."
    apt-get clean
    apt-get autoremove -y > /dev/null 2>&1

    log "INFO: [2/5] Nettoyage des logs (journalctl & /var/log)..."
    journalctl --vacuum-time=1s > /dev/null 2>&1
    find /var/log -type f -exec truncate -s 0 {} \;

    log "INFO: [3/5] Nettoyage des fichiers temporaires..."
    rm -rf /tmp/* /var/tmp/*
    rm -rf /root/.cache
}

# --- Script principal ---

trap cleanup EXIT INT TERM

log "--- Début de l'optimisation de la VM ---"

# Vérification root
if [[ $EUID -ne 0 ]]; then
   log "ERREUR: Ce script doit être exécuté avec les privilèges root (sudo)."
   exit 1
fi

# 1. Nettoyage système
clean_system

# 2. Gestion du Swap
log "INFO: [4/5] Désactivation du swap pour maximiser le zero-fill..."
swapoff -a

# 3. Trim (SSD/Thin Provisioning)
log "INFO: Exécution de fstrim..."
fstrim -av

# 4. Remplissage par zéros (Avec Fallback)
log "INFO: [5/5] Remplissage de l'espace libre avec des zéros..."
log "NOTE: Ignorez le message 'No space left on device', c'est le but recherché."

# Explication de la commande ci-dessous :
# 1. Tente dd avec accès direct (rapide).
# 2. Si ça échoue (ou disque plein), tente dd standard (lent mais compatible).
# 3. '|| true' garantit que le script ne plante pas à la fin.
dd if=/dev/zero of="$TEMP_FILE_PATH" bs=16M oflag=direct status=progress 2> /dev/null \
|| dd if=/dev/zero of="$TEMP_FILE_PATH" bs=1M status=progress \
|| true

# 5. Nettoyage final
log "INFO: Nettoyage de l'historique Bash..."
cat /dev/null > /root/.bash_history
history -c

log "--- Optimisation terminée. Vous pouvez éteindre la VM et exporter l'OVA. ---"
