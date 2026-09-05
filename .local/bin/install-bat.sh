#!/usr/bin/env bash
# NAME
#     install-bat.sh — installe bat (cat/more avec coloration syntaxique)
#
# SYNOPSIS
#     install-bat.sh [-h]
#
# DESCRIPTION
#     Télécharge la dernière version de bat (https://github.com/sharkdp/bat)
#     depuis ses binaires GitHub officiels et l'installe dans ~/.local/bin,
#     sans droits root. bat remplace avantageusement cat/more : coloration
#     syntaxique, numérotation des lignes, et marquage Git des lignes
#     modifiées par rapport au dépôt.
#
#     Le paquet APT « bat » de Debian/Ubuntu installe le binaire sous le nom
#     « batcat » (conflit avec un paquet existant nommé « bat »). Ce script
#     installe le vrai nom « bat » et crée en plus un lien « batcat » à côté,
#     pour rester compatible avec la configuration fzf déjà présente dans ce
#     dépôt (.shellrc/zshrc.d/04_fzf.zsh, FZF_PREVIEW_ARGS) sans y toucher.
#
#     Idempotent : relancé, réinstalle/met à jour vers la dernière version.
#
# OPTIONS
#     -h, --help   Affiche cette aide.
#
# EXAMPLES
#     bash install-bat.sh
#
# EXIT CODES
#     0   bat installé (ou déjà à jour).
#     1   Erreur d'exécution : téléchargement, extraction, architecture non
#         supportée, binaire introuvable après installation.
#     2   Erreur d'usage : option inconnue.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly GITHUB_REPO="sharkdp/bat"
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

# bat ne publie pas de build musl pour toutes les architectures ; celles listées
# ici sont statiques (aucune dépendance à la version de glibc de la machine).
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  ARCH_TAG="x86_64-unknown-linux-musl" ;;
        aarch64) ARCH_TAG="aarch64-unknown-linux-musl" ;;
        armv7l)  ARCH_TAG="arm-unknown-linux-musleabihf" ;;
        *) die "Architecture non supportée : ${arch}" ;;
    esac
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
fetch_latest_tag() {
    info "Recherche de la dernière version de bat..."
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
    # Le tag bat inclut déjà le préfixe « v » (ex. v0.26.1) : on le réutilise
    # tel quel, sans le retirer ni le rajouter, pour coller exactement au nom
    # des fichiers publiés par le projet.
    asset="bat-${LATEST_TAG}-${ARCH_TAG}.tar.gz"
    url="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/${asset}"

    # TMP_DIR n'est PAS « local » : le trap EXIT reste actif pour tout le
    # reste du script (y compris un die() dans verify_install() plus tard),
    # et une variable locale déjà hors de portée y déclencherait un
    # « unbound variable » sous set -u au moment où le trap se déclenche.
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Téléchargement de bat ${LATEST_TAG} (${ARCH_TAG})..."
    curl -fsSL -o "${TMP_DIR}/${asset}" "$url" || die "Échec du téléchargement : ${url}"

    tar -xzf "${TMP_DIR}/${asset}" -C "$TMP_DIR" || die "Échec de l'extraction de ${asset}."

    extracted_dir="${TMP_DIR}/bat-${LATEST_TAG}-${ARCH_TAG}"
    [ -f "${extracted_dir}/bat" ] || die "Binaire bat introuvable dans l'archive téléchargée."

    mkdir -p "$INSTALL_DIR"
    install -m 0755 "${extracted_dir}/bat" "${INSTALL_DIR}/bat"

    # Compatibilité avec .shellrc/zshrc.d/04_fzf.zsh, qui appelle « batcat »
    # (nom du binaire du paquet APT Debian/Ubuntu) : lien relatif, valide quel
    # que soit l'emplacement de INSTALL_DIR.
    ln -sf bat "${INSTALL_DIR}/batcat"

    success "bat ${LATEST_TAG} installé dans ${INSTALL_DIR}/bat (lien batcat créé pour compatibilité fzf)."
}

# -----------------------------------------------------------------------------
# Vérification post-installation
# -----------------------------------------------------------------------------
verify_install() {
    command -v bat >/dev/null 2>&1 \
        || die "bat introuvable dans le PATH après installation (vérifier que ${INSTALL_DIR} y figure)."
    local version
    version="$(bat --version 2>/dev/null || echo inconnue)"
    success "Installation vérifiée : ${BOLD}${version}${RESET}"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo -e "\n${BOLD}=== Installation de bat ===${RESET}\n"

    check_not_root
    check_dependencies

    if command -v bat >/dev/null 2>&1; then
        info "bat déjà présent : $(bat --version 2>/dev/null | head -1). Mise à jour vers la dernière version..."
    fi

    detect_arch
    fetch_latest_tag
    install_binary
    verify_install

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET} Essayer avec : ${CYAN}bat <fichier>${RESET}\n"
}

main "$@"
