#!/bin/bash
set -euo pipefail

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

BACKUP_DIR="docker_images_backup"
SCRIPT_NAME="$(basename "$0")"

usage() {
    echo -e "${BOLD}Usage :${RESET} ${SCRIPT_NAME} <commande>"
    echo ""
    echo "Commandes :"
    echo "  pack      Sauvegarde les images Docker et crée une archive portable du projet"
    echo "  restore   Charge les images Docker depuis une sauvegarde existante"
    echo "  help      Affiche cette aide"
    echo ""
    echo "Exemples :"
    echo "  ${SCRIPT_NAME} pack      # depuis la racine d'un projet Docker Compose"
    echo "  ${SCRIPT_NAME} restore   # depuis la racine du projet décompressé"
}

check_docker() {
    command -v docker >/dev/null 2>&1 \
        || die "Docker n'est pas installé ou introuvable dans le PATH."
    docker info >/dev/null 2>&1 \
        || die "Le daemon Docker n'est pas accessible (vérifiez qu'il est démarré et que vous êtes dans le groupe 'docker')."
}

check_compose_file() {
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        die "Aucun fichier 'docker-compose.yml' trouvé. Lancez ce script depuis la racine d'un projet Docker Compose."
    fi
}

cmd_pack() {
    check_docker
    check_compose_file
    command -v zstd >/dev/null 2>&1 \
        || die "zstd n'est pas installé. Installez-le avec : sudo apt install zstd"

    PROJECT_DIR_NAME=$(basename "$PWD")

    # Nettoyage garanti même en cas d'erreur ou d'interruption
    trap 'rm -rf "${BACKUP_DIR}"' EXIT INT TERM

    # --- Étape 1 : Récupération des images ---
    info "Récupération des images déclarées dans Docker Compose..."

    # $2 = REPOSITORY, $3 = TAG dans la sortie de 'docker compose images'
    IMAGE_LIST=$(docker compose images 2>/dev/null \
        | awk 'NR>1 && $2!="" && $2!="<none>" && $3!="<none>" {print $2":"$3}' \
        | sort -u) || true

    if [ -z "$IMAGE_LIST" ]; then
        die "Aucune image trouvée. Lancez 'docker compose build' ou 'docker compose pull' au préalable."
    fi

    # --- Étape 2 : Sauvegarde des images ---
    info "--- 1/3 : Sauvegarde des images Docker ---"
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    while IFS= read -r IMAGE; do
        FILENAME=$(echo "$IMAGE" | tr '/:' '_').tar
        info "Sauvegarde de '${IMAGE}'..."
        docker save -o "${BACKUP_DIR}/${FILENAME}" "$IMAGE" \
            || die "Échec de la sauvegarde de l'image '${IMAGE}'."
        success "'${IMAGE}' → ${BACKUP_DIR}/${FILENAME}"
    done <<< "$IMAGE_LIST"

    # --- Étape 3 : Création de l'archive du projet ---
    info "--- 2/3 : Création de l'archive du projet ---"
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H%M%SZ")
    ARCHIVE_NAME="${PROJECT_DIR_NAME}_${TIMESTAMP}.tar.zst"

    info "Compression de '${PROJECT_DIR_NAME}' vers '../${ARCHIVE_NAME}'..."
    (
        cd .. && \
        tar -c -I 'zstd -T0' -f "$ARCHIVE_NAME" "$PROJECT_DIR_NAME" \
            || { rm -f "$ARCHIVE_NAME"; exit 1; }
    )

    ARCHIVE_SIZE=$(du -sh "../${ARCHIVE_NAME}" 2>/dev/null | cut -f1 || echo "?")

    # --- Étape 4 : Nettoyage ---
    info "--- 3/3 : Nettoyage du dossier temporaire ---"
    trap - EXIT INT TERM
    rm -rf "${BACKUP_DIR}"

    echo ""
    success "Opération terminée avec succès !"
    info "Archive créée : ../${ARCHIVE_NAME} (${ARCHIVE_SIZE})"
    info "Les destinataires devront lancer : ${SCRIPT_NAME} restore"
}

cmd_restore() {
    check_docker

    [ -d "$BACKUP_DIR" ] \
        || die "Dossier '${BACKUP_DIR}' introuvable. Lancez ce script depuis la racine du projet décompressé."

    shopt -s nullglob
    TAR_FILES=("${BACKUP_DIR}"/*.tar)
    shopt -u nullglob

    [ ${#TAR_FILES[@]} -gt 0 ] \
        || die "Aucun fichier .tar trouvé dans '${BACKUP_DIR}'."

    info "--- Chargement des images Docker (${#TAR_FILES[@]} fichier(s)) ---"
    for ARCHIVE in "${TAR_FILES[@]}"; do
        info "Chargement depuis '${ARCHIVE}'..."
        docker load -i "$ARCHIVE" \
            || die "Échec du chargement de l'image depuis '${ARCHIVE}'."
        success "Image chargée depuis '${ARCHIVE}'."
    done

    echo ""
    success "Restauration terminée — ${#TAR_FILES[@]} image(s) chargée(s)."
    echo ""
    info "Pour démarrer le projet :"
    if [ -f "docker-compose.offline.yml" ]; then
        echo "   docker compose -f docker-compose.offline.yml up -d"
    else
        echo "   docker compose up -d"
    fi
}

COMMAND="${1:-}"

case "$COMMAND" in
    pack)           cmd_pack ;;
    restore)        cmd_restore ;;
    help|--help|-h) usage ;;
    "")             usage; exit 1 ;;
    *)              error "Commande inconnue : '${COMMAND}'"; echo ""; usage; exit 1 ;;
esac
