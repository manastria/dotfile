#!/bin/bash
# =============================================================================
# Configuration avancée des alias pour la gestion de l'historique Bash
# Auteur: Claude
# Version: 1.0.0
# 
# Description:
# Collection d'alias et fonctions pour gérer efficacement l'historique des
# commandes bash. Ce script permet de :
# - Gérer des historiques séparés par session
# - Consulter et rechercher dans l'historique
# - Sauvegarder et restaurer des historiques
# - Analyser l'utilisation des commandes
# 
# Usage:
# 1. Sauvegardez ce script dans ~/.bash_history_aliases
# 2. Ajoutez dans votre .bashrc : source ~/.bash_history_aliases
# =============================================================================

# -----------------------------------------------------------------------------
# GESTION DES SESSIONS
# -----------------------------------------------------------------------------

#
# create_session_history()
# 
# Crée un fichier d'historique unique pour le terminal actuel.
# Le fichier est nommé .bash_history_SESSION_ID où SESSION_ID est le PID
# du shell courant.
#
# Usage:
#   new-session
#
# Effets:
# - Crée un nouveau fichier d'historique
# - Redirige toutes les nouvelles commandes vers ce fichier
# - Isole l'historique des autres terminaux
#
create_session_history() {
    local session_id=$$
    export HISTFILE="$HOME/.bash_history_$session_id"
    echo "Historique de session activé: $HISTFILE"
}
alias new-session='create_session_history'

#
# restore_global_history()
#
# Restaure l'utilisation de l'historique global standard.
#
# Usage:
#   global-history
#
# Effets:
# - Réinitialise HISTFILE vers ~/.bash_history
# - Fusionne l'historique de session avec l'historique global
#
restore_global_history() {
    export HISTFILE="$HOME/.bash_history"
    echo "Retour à l'historique global: $HISTFILE"
}
alias global-history='restore_global_history'

# -----------------------------------------------------------------------------
# CONSULTATION DE L'HISTORIQUE
# -----------------------------------------------------------------------------

#
# Alias: hist
# Affiche l'historique complet avec pagination via less
# Avantages:
# - Navigation facile avec les touches de less (↑, ↓, /, q)
# - Recherche possible dans less avec '/'
# - Sortie avec 'q'
#
alias hist='history | less'

#
# Alias: hist10
# Affiche uniquement les 10 dernières commandes
# Utile pour un aperçu rapide des dernières actions
#
alias hist10='history 10'

#
# Alias: h
# Recherche dans l'historique (insensible à la casse)
#
# Usage:
#   h <mot-clé>
#
# Exemples:
#   h git         # recherche toutes les commandes git
#   h "git push"  # recherche les git push
#
alias h='history | grep -i'

# -----------------------------------------------------------------------------
# SAUVEGARDE ET MAINTENANCE
# -----------------------------------------------------------------------------

#
# backup_history()
#
# Crée une sauvegarde horodatée de l'historique actuel
#
# Usage:
#   save-history
#
# Effets:
# - Crée le dossier ~/.history_backups si nécessaire
# - Copie l'historique avec un timestamp dans le nom
# - Conserve toutes les sauvegardes précédentes
#
# Note: Utile avant des manipulations risquées de l'historique
#
backup_history() {
    local backup_dir="$HOME/.history_backups"
    local date_suffix=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$backup_dir"
    cp "$HISTFILE" "$backup_dir/bash_history_$date_suffix"
    echo "Historique sauvegardé dans: $backup_dir/bash_history_$date_suffix"
}
alias save-history='backup_history'

#
# top_commands()
#
# Analyse et affiche les commandes les plus fréquemment utilisées
#
# Usage:
#   top-commands [nombre]
#
# Arguments:
#   nombre : Nombre de commandes à afficher (défaut: 10)
#
# Sortie:
#   Pour chaque commande:
#   - Nombre d'utilisations
#   - Pourcentage d'utilisation
#   - La commande elle-même
#
# Exemple:
#   top-commands 5  # affiche les 5 commandes les plus utilisées
#
top_commands() {
    local count=${1:-10}
    history | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | \
    grep -v "./" | column -c3 -s " " -t | sort -nr | nl | head -n "$count"
}
alias top-commands='top_commands'

#
# clean_history()
#
# Nettoie l'historique en supprimant les commandes dupliquées
# tout en préservant l'ordre chronologique
#
# Usage:
#   clean-hist
#
# Effets:
# - Conserve uniquement la dernière occurrence de chaque commande
# - Préserve l'ordre chronologique des commandes
# - Remplace le fichier d'historique original
#
# Note: Faire une sauvegarde avant avec save-history est recommandé
#
clean_history() {
    local tmp_file=$(mktemp)
    tac "$HISTFILE" | awk '!seen[$0]++' | tac > "$tmp_file"
    mv "$tmp_file" "$HISTFILE"
    echo "Historique nettoyé des doublons"
}
alias clean-hist='clean_history'

#
# merge_histories()
#
# Fusionne tous les fichiers d'historique de session en un seul fichier
#
# Usage:
#   merge-hist
#
# Effets:
# - Combine tous les fichiers .bash_history_* 
# - Trie les entrées par date
# - Crée un nouveau fichier .bash_history_merged
#
# Note: Les fichiers originaux ne sont pas modifiés
#
merge_histories() {
    local output_file="$HOME/.bash_history_merged"
    echo "Fusion des historiques de session..."
    cat "$HOME"/.bash_history_* | sort -k1,2 > "$output_file"
    echo "Historiques fusionnés dans: $output_file"
}
alias merge-hist='merge_histories'

#
# hist_info()
#
# Affiche des informations détaillées sur l'historique actuel
#
# Usage:
#   hist-info
#
# Informations affichées:
# - Chemin du fichier d'historique actuel
# - Nombre total de commandes
# - Taille du fichier d'historique
#
hist_info() {
    echo "Fichier d'historique actuel: $HISTFILE"
    echo "Nombre de commandes dans l'historique: $(history | wc -l)"
    echo "Taille du fichier d'historique: $(du -h "$HISTFILE" | cut -f1)"
}
alias hist-info='hist_info'

#
# hist_help()
#
# Affiche l'aide pour toutes les commandes disponibles
#
# Usage:
#   hist-help
#
hist_help() {
    echo "=== Commandes de gestion de l'historique Bash ==="
    echo
    echo "GESTION DES SESSIONS"
    echo "  new-session    : Crée un nouvel historique isolé pour la session courante"
    echo "  global-history : Revient à l'historique global partagé"
    echo
    echo "CONSULTATION"
    echo "  hist          : Affiche tout l'historique avec pagination (navigation avec less)"
    echo "  hist10        : Affiche les 10 dernières commandes"
    echo "  h <mot-clé>   : Recherche dans l'historique (ex: h git)"
    echo
    echo "MAINTENANCE"
    echo "  save-history  : Crée une sauvegarde horodatée de l'historique"
    echo "  clean-hist    : Supprime les commandes dupliquées"
    echo "  merge-hist    : Fusionne tous les historiques de session"
    echo
    echo "ANALYSE"
    echo "  top-commands [n] : Affiche les n commandes les plus utilisées"
    echo "  hist-info     : Affiche les statistiques de l'historique"
    echo
    echo "Pour plus de détails sur une commande, consultez le code source"
    echo "qui contient une documentation complète de chaque fonction."
}
alias hist-help='hist_help'

# Message d'information lors du chargement du script
echo "Aliases d'historique chargés. Tapez 'hist-help' pour voir les commandes disponibles."
