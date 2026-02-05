#!/bin/bash
# git-squash-merge.sh
# Usage: ./git-squash-merge.sh [source_branch] [target_branch]
# Example: ./git-squash-merge.sh dev main
#          ./git-squash-merge.sh feature release

set -e  # Arrêt en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Détection de la branche par défaut
detect_default_branch() {
    # Essaie de détecter via remote
    local default=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)
    
    # Si ça ne marche pas, cherche dans les branches locales
    if [ -z "$default" ]; then
        if git show-ref --verify --quiet refs/heads/main; then
            default="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            default="master"
        fi
    fi
    
    echo "$default"
}

# Paramètres
SOURCE_BRANCH="${1:-dev}"
DEFAULT_BRANCH=$(detect_default_branch)
TARGET_BRANCH="${2:-$DEFAULT_BRANCH}"

# Vérifications initiales
info "Configuration du squash merge:"
echo "  Source: $SOURCE_BRANCH"
echo "  Target: $TARGET_BRANCH"
echo ""

# Vérifier qu'on est dans un repo git
git rev-parse --git-dir > /dev/null 2>&1 || error "Pas dans un repository Git"

# Vérifier que les branches existent
git show-ref --verify --quiet refs/heads/$SOURCE_BRANCH || error "La branche '$SOURCE_BRANCH' n'existe pas"
git show-ref --verify --quiet refs/heads/$TARGET_BRANCH || error "La branche '$TARGET_BRANCH' n'existe pas"

# Vérifier qu'il n'y a pas de modifications non commitées
if ! git diff-index --quiet HEAD --; then
    error "Vous avez des modifications non commitées. Commitez ou stash d'abord."
fi

# Sauvegarder la branche actuelle
CURRENT_BRANCH=$(git branch --show-current)

# Passer sur la branche source pour récupérer le HEAD
info "Récupération du HEAD de $SOURCE_BRANCH..."
git checkout $SOURCE_BRANCH > /dev/null 2>&1
SOURCE_HEAD=$(git rev-parse HEAD)
SOURCE_HEAD_SHORT=$(git rev-parse --short HEAD)

# Créer un tag sur le HEAD de la branche source
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TAG_NAME="squash/${SOURCE_BRANCH}-${TIMESTAMP}"

info "Création du tag '$TAG_NAME' sur $SOURCE_BRANCH@$SOURCE_HEAD_SHORT..."
git tag -a "$TAG_NAME" -m "Squash point: $SOURCE_BRANCH before merge to $TARGET_BRANCH"
success "Tag créé: $TAG_NAME"

# Passer sur la branche cible
info "Passage sur la branche $TARGET_BRANCH..."
git checkout $TARGET_BRANCH > /dev/null 2>&1

# Effectuer le squash merge
info "Squash merge de $SOURCE_BRANCH dans $TARGET_BRANCH..."
if git merge --squash --ff $SOURCE_BRANCH; then
    success "Squash effectué"
else
    error "Échec du squash merge. Résolvez les conflits manuellement."
fi

# Créer le message de commit avec la référence
COMMIT_MESSAGE="Squashed from ${SOURCE_BRANCH}@${SOURCE_HEAD_SHORT}

Tag: ${TAG_NAME}
Original HEAD: ${SOURCE_HEAD}
Source branch: ${SOURCE_BRANCH}
"

info "Création du commit..."
git commit -m "$COMMIT_MESSAGE"
success "Commit créé avec référence au HEAD d'origine"

# Afficher le résultat
echo ""
success "Squash merge terminé avec succès !"
echo ""
info "Résumé:"
echo "  • Tag créé: $TAG_NAME"
echo "  • HEAD d'origine: $SOURCE_HEAD_SHORT"
echo "  • Branche $SOURCE_BRANCH conservée"
echo ""
info "Pour retrouver le point de squash dans dev:"
echo "  git checkout $TAG_NAME"
echo ""
info "Pour pousser les changements:"
echo "  git push origin $TARGET_BRANCH"
echo "  git push origin $TAG_NAME"
echo ""

# Retourner sur la branche d'origine si ce n'était pas la target
if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ] && [ -n "$CURRENT_BRANCH" ]; then
    info "Retour sur la branche $CURRENT_BRANCH..."
    git checkout $CURRENT_BRANCH > /dev/null 2>&1
fi
