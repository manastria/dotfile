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
readonly GITHUB_API_BASE="https://api.github.com/repos/${GITHUB_REPO}"
readonly GITHUB_RELEASES_URL="https://github.com/${GITHUB_REPO}/releases"
# Nombre de releases récentes explorées pour trouver un .deb (certaines
# releases ne publient pas de .deb, ex. release mobile-only ou arm64 absent).
readonly RELEASES_LOOKBACK=20

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
# Résolution de la version cible et de son .deb
# -----------------------------------------------------------------------------
# Certaines releases GitHub d'Obsidian ne publient pas de .deb pour toutes
# les architectures (ex. release mobile-only, ou .deb arm64 absent). On
# n'utilise donc jamais /releases/latest tel quel : on cherche la release
# la plus récente qui fournit effectivement un .deb pour $ARCH, quitte à
# reculer de quelques versions. Une version explicite (argument du script)
# reste vérifiée de la même façon plutôt que supposée valide.
resolve_release() {
    local requested_version="${1:-}"
    local asset_pattern="^obsidian_.*_${ARCH}\\.deb\$"

    if [[ -n "$requested_version" ]]; then
        info "Version demandée : $requested_version"
        local release_json
        release_json=$(curl -fsSL "${GITHUB_API_BASE}/releases/tags/v${requested_version}") \
            || die "Version introuvable sur GitHub : $requested_version\n       Releases : ${GITHUB_RELEASES_URL}"

        DEB_NAME=$(echo "$release_json" | jq -r --arg pat "$asset_pattern" '.assets[]? | select(.name | test($pat)) | .name' | head -n1)
        [[ -n "$DEB_NAME" ]] || die "Aucun .deb pour l'architecture $ARCH dans la version $requested_version.\n       Releases : ${GITHUB_RELEASES_URL}"

        DEB_URL=$(echo "$release_json" | jq -r --arg name "$DEB_NAME" '.assets[] | select(.name == $name) | .browser_download_url')
        TARGET_VERSION="$requested_version"
        return
    fi

    info "Recherche de la dernière version disposant d'un .deb pour $ARCH..."
    local releases_json
    releases_json=$(curl -fsSL "${GITHUB_API_BASE}/releases?per_page=${RELEASES_LOOKBACK}") \
        || die "Impossible de récupérer les releases depuis GitHub.\n       Vérifiez votre connexion ou consultez : ${GITHUB_RELEASES_URL}"

    local latest_tag found
    latest_tag=$(echo "$releases_json" | jq -r '[.[] | select(.draft==false and .prerelease==false)][0].tag_name')
    found=$(echo "$releases_json" | jq -r --arg pat "$asset_pattern" '
        [.[] | select(.draft==false and .prerelease==false and (any(.assets[]?; .name | test($pat))))]
        | .[0]
        | if . == null then empty else
            (.tag_name) as $tag
            | (.assets[] | select(.name | test($pat))) as $asset
            | [$tag, $asset.name, $asset.browser_download_url] | @tsv
          end
    ')
    [[ -n "$found" ]] || die "Aucune des $RELEASES_LOOKBACK dernières releases ne propose de .deb pour $ARCH.\n       Releases : ${GITHUB_RELEASES_URL}"

    local tag
    IFS=$'\t' read -r tag DEB_NAME DEB_URL <<< "$found"
    TARGET_VERSION="${tag#v}"

    if [[ "$tag" != "$latest_tag" ]]; then
        warn "La dernière version (${latest_tag#v}) ne fournit pas de .deb pour $ARCH ; utilisation de $TARGET_VERSION à la place."
    fi
    success "Version retenue : $TARGET_VERSION"
}

# -----------------------------------------------------------------------------
# Téléchargement et installation
# -----------------------------------------------------------------------------
download_and_install() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local deb_path="${tmp_dir}/${DEB_NAME}"

    info "Téléchargement : $DEB_URL"
    if ! curl -fSL --progress-bar -o "$deb_path" "$DEB_URL"; then
        rm -rf "$tmp_dir"
        die "Échec du téléchargement.\n       Releases : ${GITHUB_RELEASES_URL}"
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

    resolve_release "${1:-}"
    download_and_install
    verify_install

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET} Lance Obsidian depuis le menu des applications ou avec : ${CYAN}obsidian${RESET}\n"
}

main "$@"
