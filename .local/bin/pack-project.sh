#!/usr/bin/env bash
# ─── pack_project : archive tar.zst portable d'un projet de dev ──────────────
# Usage:
#   pack_project                    → archive le répertoire courant
#   pack_project /chemin/projet     → archive le projet spécifié
#   pack_project /chemin/projet /destination

set -eo pipefail

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

SRC="${1:-.}"
DEST="${2:-$(dirname "$(realpath "$SRC")")}"
SRC_REAL=$(realpath "$SRC")
PROJECT_NAME=$(basename "$SRC_REAL")
TIMESTAMP=$(date +%Y%m%d_%H%M)
ARCHIVE="${DEST}/${PROJECT_NAME}_${TIMESTAMP}.tar.zst"
ZSTD_LEVEL="${PACK_ZSTD_LEVEL:-3}"

EXCLUDES=(
    # Python
    ".venv" "venv" "env" ".env" "__pycache__" ".mypy_cache"
    ".pytest_cache" "*.pyc" "*.pyo" ".tox" "dist" "build" "*.egg-info" ".ruff_cache"
    # Node.js
    "node_modules" ".npm" ".yarn" ".pnp"
    # Java / Kotlin / Scala
    "target" ".gradle" "*.class" "*.jar" "*.war"
    # Go / PHP / Composer
    "vendor"
    # Divers
    ".DS_Store" "Thumbs.db"
)

# Les patterns sans '/' matchent le basename à n'importe quelle profondeur dans GNU tar.
EXCLUDE_ARGS=()
for pattern in "${EXCLUDES[@]}"; do
    EXCLUDE_ARGS+=(--exclude="${pattern}")
done

cleanup() {
    rm -f "$ARCHIVE"
    error "Interruption ou erreur — archive incomplète supprimée."
    exit 1
}
trap cleanup ERR INT TERM

info "Source      : $SRC_REAL"
info "Archive     : $ARCHIVE"
if [[ "$ZSTD_LEVEL" -ge 15 ]]; then
    warn "Niveau zstd ${BOLD}${ZSTD_LEVEL}${RESET} — très lent. Utilisez PACK_ZSTD_LEVEL=3 à 9 pour un usage quotidien."
else
    info "Compression : zstd niveau ${BOLD}${ZSTD_LEVEL}${RESET}  (PACK_ZSTD_LEVEL pour modifier)"
fi
echo ""

# Archivage avec progression
info "Compression en cours..."
if command -v pv &>/dev/null; then
    tar --create --ignore-failed-read "${EXCLUDE_ARGS[@]}" \
        -C "$(dirname "$SRC_REAL")" "./${PROJECT_NAME}" \
        | pv -N "Pack" \
        | zstd -T0 -${ZSTD_LEVEL} --long > "$ARCHIVE"
else
    warn "Installez 'pv' (apt install pv) pour une barre de progression."
    tar --create \
        --ignore-failed-read \
        --file="$ARCHIVE" \
        --use-compress-program="zstd -T0 -${ZSTD_LEVEL} --long" \
        --checkpoint=500 \
        --checkpoint-action='ttyout=    → bloc %d\r' \
        "${EXCLUDE_ARGS[@]}" \
        -C "$(dirname "$SRC_REAL")" \
        "./${PROJECT_NAME}"
    echo ""
fi

trap - ERR INT TERM

SIZE=$(du -sh "$ARCHIVE" | cut -f1)
success "Archive : ${BOLD}${ARCHIVE}${RESET} (${SIZE})"
