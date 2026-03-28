#!/usr/bin/env bash
# =============================================================================
# install-ghostty.sh — Installation de Ghostty via PPA (Ubuntu 25.10)
# Auteur  : Jean-Philippe
# Usage   : bash install-ghostty.sh
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PPA="ppa:mkasberg/ghostty-ubuntu"
readonly PACKAGE="ghostty"
readonly MIN_UBUNTU="24.10"

# -----------------------------------------------------------------------------
# Couleurs
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_root() {
    if [[ $EUID -eq 0 ]]; then
        die "Ne pas lancer ce script en root. Il utilisera sudo si nécessaire."
    fi
}

check_ubuntu() {
    if ! command -v lsb_release &>/dev/null; then
        die "lsb_release introuvable. Ce script est prévu pour Ubuntu/XUbuntu."
    fi

    local distro version
    distro=$(lsb_release -is)
    version=$(lsb_release -rs)

    if [[ "$distro" != "Ubuntu" ]]; then
        die "Distribution détectée : $distro. Ce script est prévu pour Ubuntu."
    fi

    info "Distribution : $distro $version"

    # Vérification version minimale (comparaison flottante)
    if ! awk "BEGIN { exit !($version >= $MIN_UBUNTU) }"; then
        die "Ubuntu $version détecté. Version minimale requise : $MIN_UBUNTU"
    fi
}

check_already_installed() {
    if dpkg -s "$PACKAGE" &>/dev/null; then
        local current_version
        current_version=$(dpkg -s "$PACKAGE" | awk '/^Version:/ { print $2 }')
        warn "Ghostty est déjà installé (version $current_version)."
        read -r -p "$(echo -e "${YELLOW}Mettre à jour / réinstaller ?${RESET} [o/N] ")" answer
        if [[ ! "$answer" =~ ^[oOyY]$ ]]; then
            info "Installation annulée."
            exit 0
        fi
    fi
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
install_dependencies() {
    info "Vérification de software-properties-common..."
    if ! dpkg -s software-properties-common &>/dev/null; then
        info "Installation de software-properties-common..."
        sudo apt-get install -y software-properties-common
    else
        success "software-properties-common déjà présent."
    fi
}

add_ppa() {
    info "Ajout du PPA : $PPA"
    if grep -rq "mkasberg/ghostty-ubuntu" /etc/apt/sources.list.d/ 2>/dev/null; then
        success "PPA déjà présent, passage à la mise à jour."
    else
        sudo add-apt-repository -y "$PPA"
        success "PPA ajouté."
    fi
}

update_and_install() {
    info "Mise à jour des sources apt..."
    sudo apt-get update -q

    info "Installation de Ghostty..."
    sudo apt-get install -y "$PACKAGE"
}

# -----------------------------------------------------------------------------
# Vérification post-installation
# -----------------------------------------------------------------------------
verify_install() {
    if command -v ghostty &>/dev/null; then
        local installed_version
        installed_version=$(ghostty --version 2>/dev/null | head -1 || echo "inconnue")
        success "Ghostty installé avec succès : ${BOLD}$installed_version${RESET}"
    else
        die "Ghostty introuvable dans le PATH après installation."
    fi
}

# -----------------------------------------------------------------------------
# Configuration minimale par défaut
# -----------------------------------------------------------------------------
setup_config() {
    local config_dir="$HOME/.config/ghostty"
    local config_file="$config_dir/config"

    if [[ -f "$config_file" ]]; then
        warn "Fichier de config existant : $config_file — non modifié."
        return
    fi

    read -r -p "$(echo -e "${CYAN}Créer une configuration de base ?${RESET} [O/n] ")" answer
    if [[ "$answer" =~ ^[nN]$ ]]; then
        info "Configuration ignorée."
        return
    fi

    mkdir -p "$config_dir"
    cat > "$config_file" <<'EOF'
# ~/.config/ghostty/config
# Documentation : https://ghostty.org/docs/config

# Police
font-family = FiraMono Nerd Font
font-size = 11

# Thème
theme = dark

# Comportement
shell-integration = detect
copy-on-select = true

# Clic milieu pour coller (primary selection)
# mouse-binding = middle-click=paste_selection

# Fenêtre
window-padding-x = 4
window-padding-y = 4
EOF

    success "Configuration créée : $config_file"
    info "Editer ce fichier pour personnaliser. Doc : https://ghostty.org/docs/config"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    echo -e "\n${BOLD}=== Installation de Ghostty ===${RESET}\n"

    check_root
    check_ubuntu
    check_already_installed
    install_dependencies
    add_ppa
    update_and_install
    verify_install
    setup_config

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET} Lance Ghostty avec : ${CYAN}ghostty${RESET}\n"
}

main "$@"
