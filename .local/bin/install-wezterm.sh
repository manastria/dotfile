#!/usr/bin/env bash
# =============================================================================
# NAME
#     install-wezterm.sh — installe WezTerm via le dépôt APT officiel (fury.io)
#
# SYNOPSIS
#     install-wezterm.sh [-h|--help]
#
# DESCRIPTION
#     Ajoute la clé GPG et le dépôt APT de WezTerm (apt.fury.io/wez), installe
#     le paquet `wezterm`, puis compile l'entrée terminfo `wezterm` dans
#     ~/.terminfo/ de l'utilisateur qui a lancé le script.
#     Le script se relance automatiquement via sudo (Tier 1) : inutile de
#     taper `sudo` soi-même. Il peut être relancé sans risque (idempotent).
#     La configuration (~/.wezterm.lua) n'est PAS gérée ici : elle vient du
#     dépôt dotfiles (yadm).
#
# OPTIONS
#     -h, --help    Affiche cet en-tête et quitte (sans demander sudo).
#
# EXAMPLES
#     install-wezterm.sh
#
# EXIT CODES
#     0    WezTerm installé et terminfo en place
#     1    Erreur (téléchargement, apt, tic) ou option inconnue
#
# NOTES
#     Dépôt au sélecteur générique `* *` : indépendant de la version d'Ubuntu
#     (testé sur XUbuntu 25.10). Documentation : docs/install-wezterm.md
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly GPG_KEY_URL="https://apt.fury.io/wez/gpg.key"
readonly KEYRING="/usr/share/keyrings/wezterm-fury.gpg"
readonly APT_LIST="/etc/apt/sources.list.d/wezterm.list"
readonly TERMINFO_URL="https://raw.githubusercontent.com/wezterm/wezterm/main/termwiz/data/wezterm.terminfo"

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
# Arguments et privilèges
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Affiche l'en-tête (lignes 2 à la fin du bloc de commentaires)
            -h|--help) sed -n '2,/^# =====*$/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
            *) die "Option inconnue : $1" ;;
        esac
    done
}

# Tier 1 : tout le script est système. Pas de -E (cf. CLAUDE.md).
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$(readlink -f "$0")" "$@"
    fi
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
add_repository() {
    info "Ajout de la clé GPG WezTerm…"
    curl -fsSL "$GPG_KEY_URL" | gpg --yes --dearmor -o "$KEYRING"
    chmod 644 "$KEYRING"

    info "Ajout du dépôt APT WezTerm…"
    echo "deb [signed-by=${KEYRING}] https://apt.fury.io/wez/ * *" > "$APT_LIST"
}

install_package() {
    info "Mise à jour des dépôts…"
    apt-get update

    info "Installation de WezTerm…"
    apt-get install -y wezterm
    success "WezTerm installé : ${BOLD}$(wezterm --version)${RESET}"
}

# `wezterm` n'a pas de sous-commande pour exporter son terminfo : on récupère
# le fichier source officiel et on le compile avec tic.
install_terminfo() {
    local real_user real_home src
    real_user="${SUDO_USER:-root}"
    # $HOME peut désigner /root sous sudo : on résout le home de l'utilisateur réel
    real_home="$(getent passwd "$real_user" | cut -d: -f6)"

    info "Installation du terminfo wezterm pour ${real_user}…"
    src="$(mktemp)"
    trap 'rm -f "$src"' EXIT
    curl -fsSL -o "$src" "$TERMINFO_URL"
    sudo -u "$real_user" tic -x -o "${real_home}/.terminfo" "$src"
    success "Terminfo installé dans ${real_home}/.terminfo/"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    ensure_root "$@"

    echo -e "\n${BOLD}=== Installation de WezTerm ===${RESET}\n"
    add_repository
    install_package
    install_terminfo

    echo
    info "Configuration : ~/.wezterm.lua (fournie par le dépôt dotfiles)."
}

main "$@"
