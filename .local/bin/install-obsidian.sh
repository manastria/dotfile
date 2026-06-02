#!/usr/bin/env bash
# =============================================================================
# install-obsidian.sh — Installation d'Obsidian via .deb depuis GitHub Releases
# Auteur  : Jean-Philippe
# Usage   : bash install-obsidian.sh
#           bash install-obsidian.sh 1.8.10   # version spécifique
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PACKAGE="obsidian"
readonly GITHUB_REPO="obsidianmd/obsidian-releases"
readonly GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases"

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

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        die "Ne pas lancer ce script en root. Il utilisera sudo si nécessaire."
    fi
}

check_dependencies() {
    local missing=()
    for cmd in curl jq dpkg apt-get; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Dépendances manquantes : ${missing[*]}\n       Installer avec : sudo apt-get install -y ${missing[*]}"
    fi
}

check_architecture() {
    ARCH=$(dpkg --print-architecture)
    case "$ARCH" in
        amd64|arm64) ;;
        *) die "Architecture non supportée : $ARCH (supportées : amd64, arm64)" ;;
    esac
    info "Architecture détectée : $ARCH"
}

check_already_installed() {
    if dpkg -s "$PACKAGE" &>/dev/null; then
        local current_version
        current_version=$(dpkg -s "$PACKAGE" | awk '/^Version:/ { print $2 }')
        warn "Obsidian est déjà installé (version $current_version)."
        read -r -p "$(echo -e "${YELLOW}Mettre à jour / réinstaller ?${RESET} [o/N] ")" answer
        if [[ ! "$answer" =~ ^[oOyY]$ ]]; then
            info "Installation annulée."
            exit 0
        fi
    fi
}

# -----------------------------------------------------------------------------
# Récupération de la version cible
# -----------------------------------------------------------------------------
get_target_version() {
    if [[ -n "${1:-}" ]]; then
        TARGET_VERSION="$1"
        info "Version demandée : $TARGET_VERSION"
    else
        info "Récupération de la dernière version disponible..."
        TARGET_VERSION=$(curl -fsSL "${GITHUB_API}/latest" | jq -r '.tag_name' | sed 's/^v//')
        if [[ -z "$TARGET_VERSION" ]]; then
            die "Impossible de récupérer la version depuis GitHub.\n       Vérifiez votre connexion ou consultez : https://github.com/${GITHUB_REPO}/releases"
        fi
        success "Dernière version disponible : $TARGET_VERSION"
    fi
}

# -----------------------------------------------------------------------------
# Téléchargement et installation
# -----------------------------------------------------------------------------
download_and_install() {
    local deb_name="obsidian_${TARGET_VERSION}_${ARCH}.deb"
    local deb_url="https://github.com/${GITHUB_REPO}/releases/download/v${TARGET_VERSION}/${deb_name}"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local deb_path="${tmp_dir}/${deb_name}"

    info "Téléchargement : $deb_url"
    if ! curl -fSL --progress-bar -o "$deb_path" "$deb_url"; then
        rm -rf "$tmp_dir"
        die "Échec du téléchargement. Vérifiez la version et l'architecture.\n       Releases : https://github.com/${GITHUB_REPO}/releases"
    fi
    success "Téléchargement terminé."

    info "Installation du paquet..."
    sudo apt-get install -y "$deb_path"

    rm -rf "$tmp_dir"
}

# -----------------------------------------------------------------------------
# Vérification post-installation
# -----------------------------------------------------------------------------
verify_install() {
    if dpkg -s "$PACKAGE" &>/dev/null; then
        local installed_version
        installed_version=$(dpkg -s "$PACKAGE" | awk '/^Version:/ { print $2 }')
        success "Obsidian installé avec succès : ${BOLD}$installed_version${RESET}"
    else
        die "Obsidian introuvable après installation."
    fi
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    echo -e "\n${BOLD}=== Installation d'Obsidian ===${RESET}\n"

    check_not_root
    check_dependencies
    check_architecture
    check_already_installed

    info "Des droits administrateur sont nécessaires pour l'installation."
    sudo -v

    get_target_version "${1:-}"
    download_and_install
    verify_install

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET} Lance Obsidian depuis le menu des applications ou avec : ${CYAN}obsidian${RESET}\n"
}

main "$@"
