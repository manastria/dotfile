#!/bin/bash
set -e

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

# yadm utilise un dépôt bare : git-submodule requiert --git-dir et --work-tree explicites
YADM_REPO="${YADM_REPO:-$HOME/.local/share/yadm/repo.git}"
YADM_GIT="git --git-dir=$YADM_REPO --work-tree=$HOME"

[ -d "$YADM_REPO" ] || die "Dépôt yadm introuvable : $YADM_REPO"

info "Vérification de l'état des submodules..."

if $YADM_GIT submodule status --recursive | grep -q '^[-+]'; then
    warn "Mise à jour des submodules requise."
    info "Téléchargement et mise à jour en cours..."
    $YADM_GIT submodule update --init --recursive
    success "Submodules synchronisés."
else
    success "Tous les submodules sont déjà à jour."
fi
