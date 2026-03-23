#!/usr/bin/env bash
set -euo pipefail

# Configuration
SOURCE_BRANCH="dev"
TARGET_BRANCH="main"

# Vérifications préalables
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT" != "$SOURCE_BRANCH" ]; then
    echo "❌ Tu dois être sur la branche $SOURCE_BRANCH (actuellement sur $CURRENT)"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working tree pas propre. Commit ou stash d'abord."
    exit 1
fi

# Message de commit
MSG="${1:-}"
if [ -z "$MSG" ]; then
    read -rp "📦 Message de publication : " MSG
fi

# Capture le SHA source avant de changer de branche
SOURCE_SHA=$(git rev-parse --short HEAD)

# Synchronise avec GitHub
echo "⬇️  Pull $SOURCE_BRANCH..."
git pull origin "$SOURCE_BRANCH" --rebase

# Publication
echo "🚀 Publication sur $TARGET_BRANCH..."
git checkout "$TARGET_BRANCH"
git pull origin "$TARGET_BRANCH" 2>/dev/null || true
git rm -rf . --quiet
git checkout "$SOURCE_BRANCH" -- .
git commit -m "📦 Publish: $MSG

Source: $SOURCE_BRANCH@$SOURCE_SHA"
git push origin "$TARGET_BRANCH"

# Retour
git checkout "$SOURCE_BRANCH"
echo "✅ Publié ($SOURCE_BRANCH@$SOURCE_SHA → $TARGET_BRANCH)"
