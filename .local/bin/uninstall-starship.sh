#!/usr/bin/env bash
# NAME
#     uninstall-starship.sh — désinstalle le prompt Starship
#
# SYNOPSIS
#     uninstall-starship.sh [-y] [-h]
#
# DESCRIPTION
#     Supprime le binaire Starship installé par l'installeur officiel
#     (starship.rs/install.sh, qui dépose le binaire dans /usr/local/bin
#     par défaut) ou par install-starship.sh, quel que soit son
#     emplacement : /usr/local/bin, ~/.local/bin, ~/.cargo/bin, PATH.
#     Supprime aussi le cache ~/.cache/starship.
#
#     Sans le binaire, .shellrc/bashrc.d/10_prompt.bash bascule seul sur
#     le prompt Bash coloré de secours : aucun fichier shellrc n'est modifié.
#     Les profils ~/.config/starship (suivis par yadm) sont conservés.
#
#     Si le binaire appartient à un paquet (dpkg, snap, Homebrew), le
#     script s'arrête et indique la commande de désinstallation adaptée.
#     Le droit administrateur (sudo) n'est demandé que si le binaire se
#     trouve dans un répertoire non modifiable par l'utilisateur.
#
# OPTIONS
#     -y, --yes      Ne demande aucune confirmation.
#     -h, --help     Affiche cette aide.
#
# EXAMPLES
#     uninstall-starship.sh
#     uninstall-starship.sh -y
#
# EXIT CODES
#     0   Désinstallation terminée (ou rien à désinstaller)
#     1   Erreur (option inconnue, root, binaire géré par un gestionnaire
#         de paquets, annulation)

set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/starship"

# Emplacements possibles du binaire selon la méthode d'installation
readonly BIN_CANDIDATES=(
    "/usr/local/bin/starship"
    "$HOME/.local/bin/starship"
    "${CARGO_HOME:-$HOME/.cargo}/bin/starship"
)

ASSUME_YES="no"

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
# Lancé en root, ce script verrait un $HOME différent : on refuse (sudo est
# utilisé en interne, uniquement pour la suppression du binaire système)
check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
        echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
        exit 1
    fi
}

# Pose une question o/N ; réponse automatique « oui » avec --yes
confirm() {
    [ "$ASSUME_YES" = "yes" ] && return 0
    local answer
    read -r -p "$(echo -e "${YELLOW}$1${RESET} [o/N] ")" answer
    [[ "$answer" =~ ^[oOyY]$ ]]
}

# -----------------------------------------------------------------------------
# Désinstallation
# -----------------------------------------------------------------------------
# Liste les binaires starship (un par ligne), sans doublon
find_binaries() {
    local path found=()
    for path in "${BIN_CANDIDATES[@]}" "$(command -v starship 2>/dev/null || true)"; do
        [ -n "$path" ] && [ -e "$path" ] || continue
        # readlink -f : un lien et sa cible ne comptent qu'une fois
        found+=("$(readlink -f "$path")")
    done
    [ "${#found[@]}" -gt 0 ] && printf '%s\n' "${found[@]}" | sort -u
    return 0
}

# Refuse de supprimer à la main un binaire géré par un gestionnaire de paquets
check_not_packaged() {
    local bin="$1"
    if command -v dpkg &>/dev/null && dpkg -S "$bin" &>/dev/null; then
        die "$bin appartient à un paquet. Utilisez : sudo apt remove starship"
    fi
    case "$bin" in
        /snap/*|*/snap/bin/*) die "Installé via snap. Utilisez : sudo snap remove starship" ;;
        */Cellar/*|*/linuxbrew/*) die "Installé via Homebrew. Utilisez : brew uninstall starship" ;;
    esac
}

remove_binaries() {
    local bin removed=0 need_sudo=0
    local bins=()
    while IFS= read -r bin; do
        [ -n "$bin" ] && bins+=("$bin")
    done < <(find_binaries)

    # Vérifier tous les binaires avant de supprimer quoi que ce soit
    for bin in "${bins[@]}"; do
        check_not_packaged "$bin"
        [ -w "$(dirname "$bin")" ] || need_sudo=1
    done

    # Tier 2 : un seul mot de passe, demandé seulement si nécessaire
    if [ "$need_sudo" -eq 1 ]; then
        info "Des droits administrateur sont nécessaires pour supprimer un binaire système."
        sudo -v
    fi

    for bin in "${bins[@]}"; do
        info "Suppression du binaire : $bin"
        if [ -w "$(dirname "$bin")" ]; then
            rm -f -- "$bin"
        else
            sudo rm -f -- "$bin"
        fi
        removed=$((removed + 1))
    done

    if [ "$removed" -eq 0 ]; then
        warn "Aucun binaire starship trouvé."
    else
        success "Binaire supprimé."
    fi
}

remove_cache() {
    if [ -d "$CACHE_DIR" ]; then
        rm -rf -- "$CACHE_DIR"
        success "Cache supprimé : $CACHE_DIR"
    fi
}

report_leftovers() {
    [ -d "$CONFIG_DIR" ] && info "Profils conservés (gérés par yadm) : $CONFIG_DIR"
    info "Le prompt Bash de secours sera utilisé à la prochaine ouverture de shell."
    return 0
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)  ASSUME_YES="yes"; shift ;;
            -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) die "Option inconnue : $1" ;;
        esac
    done
}

main() {
    parse_args "$@"
    check_not_root

    echo -e "\n${BOLD}=== Désinstallation de Starship ===${RESET}\n"

    if [ -z "$(find_binaries)" ] && [ ! -d "$CACHE_DIR" ]; then
        info "Starship n'est pas installé : rien à faire."
        exit 0
    fi

    confirm "Désinstaller Starship ?" || die "Annulé."

    remove_binaries
    remove_cache
    report_leftovers

    success "Désinstallation terminée. Lancez « exec \$SHELL » pour recharger le prompt."
}

main "$@"
