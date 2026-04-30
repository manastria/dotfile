#!/bin/bash

# ==============================================================================
# Script pour mettre à jour les dépôts Git locaux connectés à GitHub.
#
# Objectif: Parcourir les sous-répertoires, identifier les dépôts Git
#           pointant vers un remote GitHub, exécuter 'git fetch', et
#           signaler les commits locaux non poussés.
#
# Prérequis: La CLI GitHub 'gh' doit être installée.
#            (sudo apt install gh) et authentifiée ('gh auth login').
# ==============================================================================

# --- Configuration ---
# Répertoire contenant vos dépôts Git.
# Mettez "." pour le répertoire courant, ou un chemin absolu/relatif.
BASE_DIR="."

# --- Couleurs et fonctions de log ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

# --- Tableau des dépôts avec commits non poussés ---
unpushed_repos=()

# --- Début du script ---
echo -e "${BOLD}Lancement de la mise à jour des dépôts Git...${RESET}"
echo ""

# 1. Vérification de l'authentification GitHub
info "Vérification de l'authentification GitHub..."
if ! gh auth status &> /dev/null; then
    die "Vous n'êtes pas authentifié sur GitHub. Exécutez 'gh auth login' pour vous connecter."
fi
success "Authentification réussie."
echo ""

# Vérifier si le répertoire de base existe
if [ ! -d "$BASE_DIR" ]; then
    die "Le répertoire de base '$BASE_DIR' n'existe pas."
fi

# Se déplacer dans le répertoire de base pour simplifier les chemins
cd "$BASE_DIR" || exit

# 2. Parcours des sous-répertoires
for d in */; do
    # Vérifier si l'élément est bien un répertoire
    if [ ! -d "$d" ]; then
        continue
    fi

    repo_name=${d%/} # Enlève le '/' final pour un affichage propre

    # 3. Vérifier si c'est un dépôt Git
    if [ -d "$d.git" ]; then
        # 4. Vérifier si un remote pointe vers github.com
        if git -C "$d" remote -v | grep -q "github.com"; then
            info "Mise à jour de '$repo_name'..."
            # 5. Exécution du fetch
            #    --prune supprime les branches locales qui n'existent plus sur le remote
            #    --all récupère depuis tous les remotes
            if git -C "$d" fetch --all --prune 2>&1; then
                success "Fetch réussi."
            else
                error "Échec du fetch pour '$repo_name'."
            fi

            # 6. Détecter les commits locaux non poussés (toutes branches confondues)
            unpushed=$(git -C "$d" log --branches --not --remotes --oneline 2>/dev/null)
            if [ -n "$unpushed" ]; then
                count=$(echo "$unpushed" | wc -l)
                warn "$count commit(s) non poussé(s) détecté(s) dans '$repo_name'."
                unpushed_repos+=("$repo_name ($count commit(s))")
            fi
        else
            warn "Ignoré : '$repo_name' n'est pas connecté à GitHub (dépôt local)."
        fi
    else
        warn "Ignoré : '$repo_name' n'est pas un dépôt Git."
    fi
    echo "-----------------------------------------------------"
done

# 7. Résumé final
echo ""
echo -e "${BOLD}=== RÉSUMÉ ===${RESET}"
if [ ${#unpushed_repos[@]} -eq 0 ]; then
    success "Tous les dépôts sont synchronisés. Aucun commit non poussé détecté."
else
    warn "${#unpushed_repos[@]} dépôt(s) contiennent des commits non poussés :"
    for repo in "${unpushed_repos[@]}"; do
        echo -e "  ${YELLOW}→${RESET} $repo"
    done
fi
echo ""
success "Script terminé ! Tous les dépôts GitHub ont été vérifiés."
