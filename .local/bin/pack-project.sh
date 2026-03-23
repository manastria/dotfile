#!/usr/bin/env bash
# ─── pack_project : archive tar.zst portable d'un projet de dev ──────────────
# Usage:
#   pack_project                    → archive le répertoire courant
#   pack_project /chemin/projet     → archive le projet spécifié
#   pack_project /chemin/projet /destination

SRC="${1:-.}"
DEST="${2:-$(dirname "$(realpath "$SRC")")}"
PROJECT_NAME=$(basename "$(realpath "$SRC")")
TIMESTAMP=$(date +%Y%m%d_%H%M)
ARCHIVE="${DEST}/${PROJECT_NAME}_${TIMESTAMP}.tar.zst"
ZSTD_LEVEL="${PACK_ZSTD_LEVEL:-19}"

EXCLUDES=(
    # Python
    ".venv" "venv" "env" ".env" "__pycache__" ".mypy_cache"
    ".pytest_cache" "*.pyc" "*.pyo" ".tox" "dist" "build" "*.egg-info"
    # Node.js
    "node_modules" ".npm" ".yarn" ".pnp"
    # Java / Kotlin / Scala
    "target" ".gradle" "*.class" "*.jar" "*.war"
    # Go / PHP / Composer
    "vendor"
    # Divers
    ".DS_Store" "Thumbs.db"
)

EXCLUDE_ARGS=()
for pattern in "${EXCLUDES[@]}"; do
    EXCLUDE_ARGS+=(--exclude="./${pattern}")
done

echo "📦 Archivage de : $(realpath "$SRC")"
echo "   → ${ARCHIVE}"
echo "   Exclusions : ${EXCLUDES[*]}"
echo ""

tar \
    --create \
    --file="$ARCHIVE" \
    --use-compress-program="zstd -T0 -${ZSTD_LEVEL} --long" \
    "${EXCLUDE_ARGS[@]}" \
    -C "$(dirname "$(realpath "$SRC")")" \
    "./${PROJECT_NAME}"

if [[ $? -eq 0 ]]; then
    SIZE=$(\du -s -h "$ARCHIVE" | cut -f1)
    echo "✅ Archive créée : ${ARCHIVE} (${SIZE})"
else
    echo "❌ Erreur lors de la création de l'archive."
    exit 1
fi
