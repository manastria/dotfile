#!/usr/bin/env bash
# NAME
#     install-paquets.sh — installation et mise à jour des paquets système
#
# SYNOPSIS
#     install-paquets.sh [--dry-run] [--os <id>:<version_majeure>] [-h]
#
# DESCRIPTION
#     Met à jour la liste des paquets, désinstalle les paquets obsolètes,
#     installe la liste de paquets définie pour la distribution détectée
#     (Debian/Ubuntu, avec variantes selon la version), puis nettoie les
#     dépendances inutiles. Se relance automatiquement avec sudo si
#     nécessaire — sauf en --dry-run ou --os, qui ne modifient rien et ne
#     requièrent donc pas les droits root.
#
#     Certains paquets changent de nom selon la distribution/version : voir
#     package_overrides et resolve_package_name() dans le script.
#
# OPTIONS
#     --dry-run             Affiche l'OS détecté et la liste des paquets
#                           concernés (avec leur statut : installé / à
#                           installer / introuvable) sans effectuer aucune
#                           modification.
#     --os <id>:<version>   Simule un OS différent de la machine locale
#                           (ex. ubuntu:24, debian:12) pour n'afficher que
#                           la liste des paquets qui lui correspond, sans
#                           vérifier leur statut d'installation (implique
#                           --dry-run).
#     -h, --help            Affiche cette aide.
#
# EXAMPLES
#     sudo install-paquets.sh
#     install-paquets.sh --dry-run
#     install-paquets.sh --os ubuntu:24
#     install-paquets.sh --os debian:12
#
# EXIT CODES
#     0   Terminé avec succès (ou mode --dry-run / --os).
#     1   Erreur d'exécution (apt, OS non supporté...).
#     2   Erreur d'usage : option inconnue ou --os mal formé.
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

usage() {
    # Réimprime le bloc d'en-tête manpage en retirant le préfixe « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
DRY_RUN=0
OS_OVERRIDE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=1; shift ;;
            --os)
                OS_OVERRIDE="${2:-}"
                [[ -n "$OS_OVERRIDE" ]] || usage_error "--os requiert une valeur (<id>:<version_majeure>, ex. ubuntu:24)."
                shift 2
                ;;
            -h|--help) usage; exit 0 ;;
            *)         usage_error "Option inconnue : $1" ;;
        esac
    done

    # --os n'a de sens qu'en lecture seule : il ne correspond pas forcément
    # à la machine locale sur laquelle tourne le script.
    if [[ -n "$OS_OVERRIDE" ]]; then
        DRY_RUN=1
    fi
}

# Analysé avant l'élévation (contrairement aux scripts Tier 3, qui le font
# en tête de main()) : --dry-run et --help ne doivent pas exiger sudo.
parse_args "$@"

# -----------------------------------------------------------------------------
# Élévation des privilèges (Tier 1 : auto-relaunch sans -E)
# -----------------------------------------------------------------------------
# Le mode --dry-run ne modifie rien : il n'a pas besoin des droits root.
if [[ "$DRY_RUN" -eq 0 && "$(id -u)" -ne 0 ]]; then
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
    # --os simule un OS cible au lieu de lire la machine locale : la liste
    # de paquets reflète alors cette cible, pas la machine sur laquelle
    # tourne le script (voir step_report).
    if [[ -n "$OS_OVERRIDE" ]]; then
        [[ "$OS_OVERRIDE" == *:* ]] \
            || usage_error "Format invalide pour --os : '${OS_OVERRIDE}' (attendu <id>:<version_majeure>, ex. ubuntu:24)."

        OS_ID="${OS_OVERRIDE%%:*}"
        OS_VERSION_MAJOR="${OS_OVERRIDE#*:}"
        [[ -n "$OS_ID" && "$OS_VERSION_MAJOR" =~ ^[0-9]+$ ]] \
            || usage_error "Format invalide pour --os : '${OS_OVERRIDE}' (attendu <id>:<version_majeure>, ex. ubuntu:24)."

        OS_VERSION_ID="$OS_VERSION_MAJOR"
        OS_CODENAME="simulé"
        readonly OS_ID OS_VERSION_ID OS_CODENAME OS_VERSION_MAJOR

        warn "OS simulé (--os) : ${BOLD}${OS_ID} ${OS_VERSION_MAJOR}${RESET} — ne reflète pas forcément cette machine."
        return 0
    fi

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
    util-linux-extra
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
# Correspondance des noms de paquets par distribution/version
# -----------------------------------------------------------------------------
# Certains paquets changent de nom selon la distribution ou sa version
# (ex. netcat -> netcat-openbsd sur les versions récentes). Les listes
# ci-dessus utilisent le nom canonique ; resolve_package_name() le traduit
# vers le nom réel à installer pour l'OS détecté.
#
# Clé  : "<nom_canonique>:<os_id>:<version_majeure>" (priorité la plus haute)
#     ou "<nom_canonique>:<os_id>"                   (toutes versions de l'OS)
# Valeur : nom réel du paquet dans les dépôts de cette distribution.
#
# Exemple : ["netcat:ubuntu:24"]="netcat-openbsd"
declare -A package_overrides=(
    # Ajouter ici les correspondances nécessaires, après vérification avec
    # `apt-cache search <nom>` sur la distribution/version concernée.
)

resolve_package_name() {
    local canonical="$1"
    local key_version="${canonical}:${OS_ID}:${OS_VERSION_MAJOR}"
    local key_os="${canonical}:${OS_ID}"

    if [[ -n "${package_overrides[$key_version]:-}" ]]; then
        printf '%s' "${package_overrides[$key_version]}"
    elif [[ -n "${package_overrides[$key_os]:-}" ]]; then
        printf '%s' "${package_overrides[$key_os]}"
    else
        printf '%s' "$canonical"
    fi
}

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
step_report() {
    build_package_list

    echo ""
    info "Paquets concernés pour cet OS (${#packages[@]}) :"

    local pkg real_pkg suffix status
    for pkg in "${packages[@]}"; do
        real_pkg="$(resolve_package_name "$pkg")"
        suffix=""
        [[ "$real_pkg" != "$pkg" ]] && suffix=" (-> ${real_pkg})"

        # --os simule un OS potentiellement différent de la machine locale :
        # dpkg/apt-cache ne renseigneraient que sur l'état de CETTE machine,
        # pas sur celui de la cible simulée. On se limite donc à la liste.
        if [[ -n "$OS_OVERRIDE" ]]; then
            echo "  - ${pkg}${suffix}"
            continue
        fi

        if dpkg -s "$real_pkg" &>/dev/null; then
            status="${GREEN}installé${RESET}"
        elif apt-cache show "$real_pkg" &>/dev/null; then
            status="${YELLOW}à installer${RESET}"
        else
            status="${RED}introuvable${RESET}"
        fi

        echo -e "  - ${pkg}${suffix} : ${status}"
    done
    echo ""
}

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
    local real_pkg

    for pkg in "${packages[@]}"; do
        real_pkg="$(resolve_package_name "$pkg")"
        if [[ "$real_pkg" != "$pkg" ]]; then
            info "Correspondance : ${pkg} -> ${real_pkg} (${OS_ID} ${OS_VERSION_ID})"
        fi

        if dpkg -s "$real_pkg" &>/dev/null; then
            : # Déjà installé
        elif apt-cache show "$real_pkg" &>/dev/null; then
            to_install+=("$real_pkg")
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

    if [[ "$DRY_RUN" -eq 1 ]]; then
        [[ -z "$OS_OVERRIDE" ]] && warn "Mode --dry-run : aucune modification ne sera effectuée."
        step_report
        exit 0
    fi

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
