# ─── pack_project : archive tar.zst portable d'un projet de dev ──────────────
pack_project() {
    # Usage:
    #   pack_project                    → archive le répertoire courant
    #   pack_project /chemin/projet     → archive le projet spécifié
    #   pack_project /chemin/projet /destination
    
    local SRC="${1:-.}"
    local DEST="${2:-$(dirname "$(realpath "$SRC")")}"
    local PROJECT_NAME
    PROJECT_NAME=$(basename "$(realpath "$SRC")")
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M)
    local ARCHIVE="${DEST}/${PROJECT_NAME}_${TIMESTAMP}.tar.zst"

    # Répertoires à exclure (dev artifacts)
    local EXCLUDES=(
        # Python
        ".venv" "venv" "env" ".env" "__pycache__" ".mypy_cache"
        ".pytest_cache" "*.pyc" "*.pyo" ".tox" "dist" "build" "*.egg-info"
        # Node.js
        "node_modules" ".npm" ".yarn" ".pnp"
        # Java / Kotlin / Scala
        "target" ".gradle" "*.class" "*.jar" "*.war"
        # Rust
        "target"          # déjà listé, sans effet double
        # Go
        "vendor"
        # PHP / Composer
        "vendor"
        # Divers
        ".DS_Store" "Thumbs.db" ".idea" ".vscode"
    )

    # Construire les arguments --exclude
    local EXCLUDE_ARGS=()
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
        --use-compress-program="zstd -T0 -19 --long" \
        "${EXCLUDE_ARGS[@]}" \
        -C "$(dirname "$(realpath "$SRC")")" \
        "./${PROJECT_NAME}"

    if [[ $? -eq 0 ]]; then
        local SIZE
        SIZE=$(du -sh "$ARCHIVE" | cut -f1)
        echo "✅ Archive créée : ${ARCHIVE} (${SIZE})"
    else
        echo "❌ Erreur lors de la création de l'archive."
        return 1
    fi
}

# Alias court
alias packp='pack_project'
