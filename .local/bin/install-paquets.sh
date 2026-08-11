#!/usr/bin/env bash
# install-paquets.sh — Installation et mise à jour des paquets système
# Usage : bash install-paquets.sh
set -euo pipefail

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
# Élévation des privilèges (Tier 1 : auto-relaunch sans -E)
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Détection de l'OS
# -----------------------------------------------------------------------------

# Variables globales remplies par detect_os()
OS_ID=""
OS_VERSION_ID=""
OS_CODENAME=""
OS_VERSION_MAJOR=0

detect_os() {
    [[ -f /etc/os-release ]] || die "/etc/os-release introuvable — OS non supporté."

    OS_ID="$(. /etc/os-release && printf '%s' "${ID:-unknown}")"
    OS_VERSION_ID="$(. /etc/os-release && printf '%s' "${VERSION_ID:-0}")"
    OS_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-unknown}")"
    local pretty
    pretty="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-$OS_ID $OS_VERSION_ID}")"

    # Extrait la partie entière majeure (ex. "12.1" → 12, "24.04" → 24)
    OS_VERSION_MAJOR="${OS_VERSION_ID%%.*}"
    OS_VERSION_MAJOR="${OS_VERSION_MAJOR:-0}"

    readonly OS_ID OS_VERSION_ID OS_CODENAME OS_VERSION_MAJOR

    info "OS détecté : ${BOLD}${pretty}${RESET} (id=${OS_ID}, version=${OS_VERSION_ID}, codename=${OS_CODENAME})"
}

# -----------------------------------------------------------------------------
# Listes de paquets
# -----------------------------------------------------------------------------

# Disponibles sur toutes les distributions et versions supportées
packages_communs=(
    aptitude
    bash-completion
    bat
    byobu
    ccze
    curl
    direnv
    dos2unix
    eza
    fd-find
    git
    git-lfs
    htop
    jq
    libnss3-tools
    lnav
    lsd
    micro
    most
    multitail
    ncdu
    openssh-server
    python3-rich
    reptyr
    rsync
    screen
    screenfetch
    sqlite3
    sshfs
    sudo
    tmux
    tree
    unzip
    vim
    wget
    zip
    zsh
    zstd
)

# Disponibles uniquement sous Ubuntu (absents des dépôts Debian)
packages_ubuntu=(
    # Ajouter ici les paquets Ubuntu-spécifiques
    # Exemple : nala
)

# Disponibles sous Debian ≤ 12 (bookworm), supprimés ou remplacés dans Debian 13+
packages_debian_12=(
    unrar
    haveged   # Remplacé par l'entropie noyau dans Debian 13+
    mlocate   # Remplacé par plocate dans Debian 13+
)

# Disponibles sous Debian uniquement (absents des dépôts Ubuntu)
packages_debian=(
    # Ajouter ici les paquets Debian-spécifiques
)

# Paquets pour les invités VirtualBox
packages_virtualbox=(
    build-essential
    dkms
    module-assistant
)

# Paquets nécessitant un environnement graphique
packages_graphiques=(
    gvfs-backends
    terminator
)

# -----------------------------------------------------------------------------
# Construction de la liste finale
# -----------------------------------------------------------------------------
packages=()

build_package_list() {
    packages=("${packages_communs[@]}")

    case "$OS_ID" in
        ubuntu)
            if [[ ${#packages_ubuntu[@]} -gt 0 ]]; then
                info "Ajout des paquets spécifiques Ubuntu."
                packages+=("${packages_ubuntu[@]}")
            fi
            ;;
        debian)
            if [[ ${#packages_debian[@]} -gt 0 ]]; then
                info "Ajout des paquets spécifiques Debian."
                packages+=("${packages_debian[@]}")
            fi
            if [[ "$OS_VERSION_MAJOR" -le 12 && ${#packages_debian_12[@]} -gt 0 ]]; then
                info "Ajout des paquets spécifiques Debian ≤ 12."
                packages+=("${packages_debian_12[@]}")
            fi
            ;;
        *)
            warn "Distribution non reconnue : '${OS_ID}'. Seuls les paquets communs seront installés."
            ;;
    esac

    packages+=("${packages_virtualbox[@]}")

    if dpkg -l 2>/dev/null | grep -q xserver-common; then
        info "Environnement graphique détecté. Ajout des paquets graphiques."
        packages+=("${packages_graphiques[@]}")
    fi
}

# -----------------------------------------------------------------------------
# Étapes
# -----------------------------------------------------------------------------
step_update() {
    info "Mise à jour de la liste des paquets et mise à niveau..."
    apt-get update -q
    apt-get upgrade -y
    success "Mise à jour terminée."
}

step_remove() {
    local packages_to_remove=(squid-deb-proxy-client)
    local to_remove=()

    for pkg in "${packages_to_remove[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            to_remove+=("$pkg")
        fi
    done

    if [[ ${#to_remove[@]} -gt 0 ]]; then
        info "Désinstallation : ${to_remove[*]}"
        apt-get remove -y "${to_remove[@]}"
        success "Désinstallation terminée."
    else
        info "Aucun paquet obsolète à désinstaller."
    fi
}

step_install() {
    build_package_list

    local to_install=()
    local skipped=()

    for pkg in "${packages[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            : # Déjà installé
        elif apt-cache show "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            skipped+=("$pkg")
        fi
    done

    if [[ ${#skipped[@]} -gt 0 ]]; then
        warn "Paquets introuvables dans les dépôts (ignorés) : ${skipped[*]}"
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installation : ${to_install[*]}"
        apt-get install -y "${to_install[@]}"
        success "Installation terminée."
    else
        success "Tous les paquets sont déjà installés."
    fi
}

step_cleanup() {
    info "Nettoyage des dépendances inutiles..."
    apt-get autoremove -y
    success "Nettoyage terminé."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    echo -e "\n${BOLD}=== Installation des paquets système ===${RESET}\n"

    detect_os

    echo -e "\n${BOLD}--- Étape 1 : Mise à jour ---${RESET}"
    step_update

    echo -e "\n${BOLD}--- Étape 2 : Désinstallation des paquets obsolètes ---${RESET}"
    step_remove

    echo -e "\n${BOLD}--- Étape 3 : Installation des paquets ---${RESET}"
    step_install

    echo -e "\n${BOLD}--- Étape 4 : Nettoyage ---${RESET}"
    step_cleanup

    echo ""
    success "Script terminé avec succès."
}

main "$@"
