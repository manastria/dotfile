#!/usr/bin/env bash
# NAME
#     uninstall-atuin.sh — désinstalle Atuin (binaire, reçu d'installation, données en option)
#
# SYNOPSIS
#     uninstall-atuin.sh [--purge-data] [-y] [-h]
#
# DESCRIPTION
#     Supprime le binaire Atuin installé par install-atuin.sh (installeur
#     officiel setup.atuin.sh : ~/.atuin/bin, ~/.cargo/bin ou ~/.local/bin)
#     ainsi que le reçu d'installation (atuin-receipt.json).
#
#     Par défaut, l'historique local (base SQLite, clé de chiffrement,
#     session) est CONSERVÉ : seul le programme disparaît, une
#     réinstallation retrouve tout. --purge-data supprime aussi ces données.
#
#     Le script ne touche jamais à ~/.config/atuin/config.toml (suivi par
#     yadm) ni aux fichiers shellrc : l'intégration shell est protégée par
#     « command -v atuin » et devient inerte sans le binaire. Un compte
#     de synchronisation éventuel reste actif côté serveur (voir
#     « atuin logout » / « atuin delete » avant la désinstallation).
#
#     Si le binaire appartient à un paquet (dpkg), le script s'arrête et
#     indique la commande apt à utiliser.
#
# OPTIONS
#     --purge-data   Supprime aussi l'historique et les clés locales
#                    (~/.local/share/atuin, ~/.atuin). Irréversible.
#     -y, --yes      Ne demande aucune confirmation.
#     -h, --help     Affiche cette aide.
#
# EXAMPLES
#     uninstall-atuin.sh               # retire le programme, garde l'historique
#     uninstall-atuin.sh --purge-data  # retire tout, après confirmation
#     uninstall-atuin.sh --purge-data -y
#
# EXIT CODES
#     0   Désinstallation terminée (ou rien à désinstaller)
#     1   Erreur (option inconnue, exécuté en root, paquet dpkg, annulé)

set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
readonly DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
readonly LEGACY_DIR="$HOME/.atuin"
readonly RECEIPT="${CONFIG_DIR}/atuin-receipt.json"

# Emplacements possibles du binaire selon la version de l'installeur
readonly BIN_CANDIDATES=(
    "$HOME/.atuin/bin/atuin"
    "${CARGO_HOME:-$HOME/.cargo}/bin/atuin"
    "$HOME/.local/bin/atuin"
)

PURGE_DATA="no"
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
# Tier 3 : un script qui touche à $HOME ne doit pas tourner en root
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
# Retourne les binaires atuin à supprimer (un par ligne), sans doublon
find_binaries() {
    local path found=()
    for path in "${BIN_CANDIDATES[@]}" "$(command -v atuin 2>/dev/null || true)"; do
        [ -n "$path" ] && [ -e "$path" ] || continue
        # readlink -f : évite de lister deux fois un même fichier via un lien
        found+=("$(readlink -f "$path")")
    done
    [ "${#found[@]}" -gt 0 ] && printf '%s\n' "${found[@]}" | sort -u
    return 0
}

remove_binaries() {
    local bin removed=0
    while IFS= read -r bin; do
        [ -n "$bin" ] || continue
        # Un binaire fourni par un paquet doit être retiré par apt, pas à la main
        if dpkg -S "$bin" &>/dev/null; then
            die "$bin appartient à un paquet. Utilisez : sudo apt remove atuin"
        fi
        info "Suppression du binaire : $bin"
        rm -f -- "$bin"
        removed=$((removed + 1))
    done < <(find_binaries)

    if [ "$removed" -eq 0 ]; then
        warn "Aucun binaire atuin trouvé."
    else
        success "Binaire supprimé."
    fi
}

remove_receipt() {
    if [ -f "$RECEIPT" ]; then
        rm -f -- "$RECEIPT"
        success "Reçu d'installation supprimé : $RECEIPT"
    fi
}

purge_data() {
    local dir existing=()
    for dir in "$DATA_DIR" "$LEGACY_DIR"; do
        [ -d "$dir" ] && existing+=("$dir")
    done

    if [ "${#existing[@]}" -eq 0 ]; then
        info "Aucune donnée locale à supprimer."
        return 0
    fi

    warn "Historique et clés locales à supprimer (irréversible) :"
    printf '           - %s\n' "${existing[@]}"
    confirm "Supprimer ces données ?" || { info "Données conservées."; return 0; }

    rm -rf -- "${existing[@]}"
    success "Données supprimées."
}

report_leftovers() {
    if [ "$PURGE_DATA" != "yes" ]; then
        [ -d "$DATA_DIR" ] && info "Historique conservé : $DATA_DIR (--purge-data pour le supprimer)."
    fi
    [ -f "$CONFIG_DIR/config.toml" ] && info "Configuration conservée (gérée par yadm) : $CONFIG_DIR/config.toml"
    return 0
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge-data) PURGE_DATA="yes"; shift ;;
            -y|--yes)     ASSUME_YES="yes"; shift ;;
            -h|--help)    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) die "Option inconnue : $1" ;;
        esac
    done
}

main() {
    parse_args "$@"
    check_not_root

    echo -e "\n${BOLD}=== Désinstallation d'Atuin ===${RESET}\n"

    if [ -z "$(find_binaries)" ] && [ ! -f "$RECEIPT" ] && [ ! -d "$DATA_DIR" ] && [ ! -d "$LEGACY_DIR" ]; then
        info "Atuin n'est pas installé : rien à faire."
        exit 0
    fi

    confirm "Désinstaller Atuin ?" || die "Annulé."

    remove_binaries
    remove_receipt
    [ "$PURGE_DATA" = "yes" ] && purge_data
    report_leftovers

    success "Désinstallation terminée. Ouvrez un nouveau shell pour recharger l'environnement."
}

main "$@"
