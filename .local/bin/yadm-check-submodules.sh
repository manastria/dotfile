#!/usr/bin/env bash
# NAME
#     yadm-check-submodules.sh — synchronise les submodules du dépôt yadm
#
# SYNOPSIS
#     yadm-check-submodules.sh [-n] [-h]
#
# DESCRIPTION
#     Vérifie que les submodules du dépôt dotfiles géré par yadm (oh-my-zsh,
#     powerlevel10k, plugins zsh…) sont bien au commit épinglé par le dépôt,
#     et les synchronise sinon. Conçu pour être appelé après un « yadm pull »,
#     ou depuis l'initialisation du shell.
#
#     Le script ne fait que SYNCHRONISER vers le commit épinglé ; il ne tire
#     jamais la dernière version upstream d'un submodule. Voir
#     docs/mise-a-jour-submodules-zsh.md pour cette opération.
#
#     yadm stocke ses données dans un dépôt dont l'arbre de travail est $HOME.
#     git-submodule refuse de s'exécuter si le répertoire courant est hors de
#     cet arbre (« cannot be used without a working tree ») : le script se
#     place donc dans $HOME avant tout appel à git. Il est ainsi lançable
#     depuis n'importe où, y compris depuis /mnt/c sous WSL.
#
# OPTIONS
#     -n, --dry-run   Signale les submodules désynchronisés sans rien
#                     modifier.
#     -h, --help      Affiche cette aide.
#
# ENVIRONMENT
#     YADM_REPO   Chemin du dépôt yadm.
#                 Défaut : ~/.local/share/yadm/repo.git
#
# EXAMPLES
#     # Usage courant, après un yadm pull
#     yadm-check-submodules.sh
#
#     # Diagnostic seul
#     yadm-check-submodules.sh --dry-run
#
# EXIT CODES
#     0   Submodules à jour, ou synchronisation réussie.
#     1   Erreur d'exécution : dépôt yadm introuvable, échec de git,
#         ou conflit de fusion dans un submodule.
#     2   Erreur d'usage : option inconnue.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly YADM_REPO="${YADM_REPO:-$HOME/.local/share/yadm/repo.git}"

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
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

usage() {
    # Réimprime le bloc d'en-tête manpage en retirant le préfixe « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
DRY_RUN="no"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run) DRY_RUN="yes"; shift ;;
            -h|--help)    usage; exit 0 ;;
            *)            usage_error "Option inconnue : $1" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Accès au dépôt yadm
# -----------------------------------------------------------------------------
# yadm utilise un dépôt séparé : git-submodule requiert --git-dir et
# --work-tree explicites, ET un répertoire courant situé dans l'arbre de
# travail — d'où le « cd $HOME ».
yadm_git() {
    git --git-dir="$YADM_REPO" --work-tree="$HOME" "$@"
}

check_repo() {
    command -v git >/dev/null 2>&1 || die "'git' n'est pas installé."
    [ -d "$YADM_REPO" ] || die "Dépôt yadm introuvable : $YADM_REPO"
    cd "$HOME" || die "Impossible d'accéder à $HOME"
}

# -----------------------------------------------------------------------------
# Vérification et synchronisation
# -----------------------------------------------------------------------------
check_submodules() {
    local status

    info "Vérification de l'état des submodules..."

    # Affectation séparée de la déclaration : « local status=$(...) » masque
    # le code de retour de la commande et ferait passer un échec de git pour
    # un succès (c'était le cas avec le pipe vers grep utilisé auparavant).
    status="$(yadm_git submodule status --recursive)" \
        || die "Échec de « git submodule status » sur $YADM_REPO"

    # Préfixes : « - » non initialisé, « + » commit local différent de celui
    # épinglé, « U » conflit de fusion (non réparable automatiquement).
    if grep -q '^U' <<< "$status"; then
        grep '^U' <<< "$status" | while read -r line; do warn "  $line"; done
        die "Conflit de fusion dans un submodule : intervention manuelle requise."
    fi

    if ! grep -q '^[-+]' <<< "$status"; then
        success "Tous les submodules sont déjà à jour."
        return 0
    fi

    warn "Mise à jour des submodules requise :"
    grep '^[-+]' <<< "$status" | while read -r line; do warn "  $line"; done

    if [ "$DRY_RUN" = "yes" ]; then
        info "Simulation — aucune modification. Relancez sans --dry-run."
        return 0
    fi

    info "Téléchargement et mise à jour en cours..."
    yadm_git submodule update --init --recursive \
        || die "Échec de « git submodule update »."
    success "Submodules synchronisés."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_repo
    check_submodules
}

main "$@"
