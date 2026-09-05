#!/usr/bin/env bash
# NAME
#     install-delta.sh — installe delta (pager de diff Git colorisé)
#
# SYNOPSIS
#     install-delta.sh [-h]
#
# DESCRIPTION
#     Télécharge la dernière version de delta
#     (https://github.com/dandavison/delta) depuis ses binaires GitHub
#     officiels et l'installe dans ~/.local/bin, sans droits root. delta
#     remplace le pager de « git diff »/« git show » par un rendu avec
#     coloration syntaxique, numérotation des lignes et alignement côte à
#     côte.
#
#     Propose ensuite, avec confirmation, de configurer Git pour l'utiliser
#     (core.pager, interactive.diffFilter, delta.navigate) dans
#     ~/.gitconfig. Rien n'est modifié si la réponse est négative, ou si
#     delta est déjà le pager configuré.
#
#     Idempotent : relancé, réinstalle/met à jour vers la dernière version ;
#     la configuration Git n'est pas re-proposée si delta est déjà actif.
#
# OPTIONS
#     -h, --help   Affiche cette aide.
#
# EXAMPLES
#     bash install-delta.sh
#
# EXIT CODES
#     0   delta installé (ou déjà à jour).
#     1   Erreur d'exécution : téléchargement, extraction, architecture non
#         supportée, binaire introuvable après installation.
#     2   Erreur d'usage : option inconnue.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly GITHUB_REPO="dandavison/delta"
readonly INSTALL_DIR="${HOME}/.local/bin"

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
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            *)         usage_error "Option inconnue : $1" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        error "Ce script ne doit pas être lancé en root (installation dans \$HOME/.local/bin)."
        error "Relancez sans sudo, en tant qu'utilisateur normal."
        exit 1
    fi
}

check_dependencies() {
    command -v curl >/dev/null 2>&1 || die "curl est requis."
    command -v tar  >/dev/null 2>&1 || die "tar est requis."
}

# Contrairement à bat, delta ne publie pas de build musl pour aarch64/arm :
# on retombe sur les binaires gnu (liés à la glibc de la machine) pour ces
# deux architectures.
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  ARCH_TAG="x86_64-unknown-linux-musl" ;;
        aarch64) ARCH_TAG="aarch64-unknown-linux-gnu" ;;
        armv7l)  ARCH_TAG="arm-unknown-linux-gnueabihf" ;;
        *) die "Architecture non supportée : ${arch}" ;;
    esac
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
fetch_latest_tag() {
    info "Recherche de la dernière version de delta..."
    # Pas de « grep -m1 » : en s'arrêtant à la première correspondance, il
    # ferme le pipe avant que curl ait fini d'écrire toute la réponse, ce qui
    # produit une erreur d'écriture (23) que pipefail transforme en échec —
    # même si la donnée recherchée a bien été récupérée. Sans -m1, grep lit
    # jusqu'à l'EOF de curl ; l'API ne renvoie de toute façon qu'un seul
    # « tag_name » pour /releases/latest.
    LATEST_TAG="$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')" \
        || die "Impossible d'interroger l'API GitHub."
    [ -n "$LATEST_TAG" ] || die "Réponse de l'API GitHub inexploitable (limite de débit atteinte ?)."
}

install_binary() {
    local asset url extracted_dir
    # Contrairement à bat, le tag delta n'a pas de préfixe « v » (ex. 0.19.2) :
    # on le réutilise tel quel, sans le retirer ni le rajouter, pour coller
    # exactement au nom des fichiers publiés par le projet.
    asset="delta-${LATEST_TAG}-${ARCH_TAG}.tar.gz"
    url="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/${asset}"

    # TMP_DIR n'est PAS « local » : le trap EXIT reste actif pour tout le
    # reste du script (y compris un die() dans verify_install() plus tard),
    # et une variable locale déjà hors de portée y déclencherait un
    # « unbound variable » sous set -u au moment où le trap se déclenche.
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Téléchargement de delta ${LATEST_TAG} (${ARCH_TAG})..."
    curl -fsSL -o "${TMP_DIR}/${asset}" "$url" || die "Échec du téléchargement : ${url}"

    tar -xzf "${TMP_DIR}/${asset}" -C "$TMP_DIR" || die "Échec de l'extraction de ${asset}."

    extracted_dir="${TMP_DIR}/delta-${LATEST_TAG}-${ARCH_TAG}"
    [ -f "${extracted_dir}/delta" ] || die "Binaire delta introuvable dans l'archive téléchargée."

    mkdir -p "$INSTALL_DIR"
    install -m 0755 "${extracted_dir}/delta" "${INSTALL_DIR}/delta"

    success "delta ${LATEST_TAG} installé dans ${INSTALL_DIR}/delta."
}

# -----------------------------------------------------------------------------
# Vérification post-installation
# -----------------------------------------------------------------------------
verify_install() {
    command -v delta >/dev/null 2>&1 \
        || die "delta introuvable dans le PATH après installation (vérifier que ${INSTALL_DIR} y figure)."
    local version
    version="$(delta --version 2>/dev/null || echo inconnue)"
    success "Installation vérifiée : ${BOLD}${version}${RESET}"
}

# -----------------------------------------------------------------------------
# Configuration Git (optionnelle)
# -----------------------------------------------------------------------------
configure_git_pager() {
    local current_pager
    current_pager="$(git config --global core.pager 2>/dev/null || true)"

    if [ "$current_pager" = "delta" ]; then
        success "Git est déjà configuré pour utiliser delta comme pager."
        return 0
    fi

    if [ -n "$current_pager" ]; then
        warn "Pager Git actuel (core.pager) : ${current_pager}"
    fi

    read -r -p "$(echo -e "${CYAN}Configurer Git pour utiliser delta (core.pager, interactive.diffFilter) ?${RESET} [O/n] ")" answer
    if [[ "$answer" =~ ^[nN]$ ]]; then
        info "Configuration Git laissée inchangée."
        return 0
    fi

    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true

    success "Git configuré pour utiliser delta (~/.gitconfig)."
    info "Astuce : delta.side-by-side = true affiche le diff sur deux colonnes."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo -e "\n${BOLD}=== Installation de delta ===${RESET}\n"

    check_not_root
    check_dependencies

    if command -v delta >/dev/null 2>&1; then
        info "delta déjà présent : $(delta --version 2>/dev/null | head -1). Mise à jour vers la dernière version..."
    fi

    detect_arch
    fetch_latest_tag
    install_binary
    verify_install
    configure_git_pager

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET} Essayer avec : ${CYAN}git diff${RESET}\n"
}

main "$@"
