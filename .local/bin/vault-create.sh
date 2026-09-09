#!/usr/bin/env bash
# NAME
#     vault-create.sh — crée le coffre chiffré LUKS pour les profils navigateur
#
# SYNOPSIS
#     vault-create.sh [--size TAILLE] [-h]
#
# DESCRIPTION
#     Crée le conteneur LUKS attendu par vault-open.sh / vault-close.sh :
#     fichier conteneur (fallocate), luksFormat, ouverture, formatage ext4,
#     puis délègue le montage et la mise en place des bind mounts des
#     profils navigateur (Vivaldi, Brave, Firefox) à vault-open.sh.
#
#     La passphrase du vault et le mot de passe sudo sont demandés une seule
#     fois, en tout début d'exécution : le reste du script tourne ensuite
#     sans aucune interaction.
#
#     Ne migre PAS un profil navigateur existant. Les points de montage
#     (~/.config/vivaldi, etc.) démarrent vides côté vault ; un profil déjà
#     présent à ces emplacements est seulement masqué tant que le vault est
#     monté, pas déplacé dedans. Voir docs/vault-create.md.
#
# OPTIONS
#     --size TAILLE   Taille du conteneur, syntaxe fallocate (ex: 15G, 500M).
#                     Défaut : 15G.
#     -h, --help      Affiche cette aide.
#
# EXAMPLES
#     # Création avec la taille par défaut (15G)
#     vault-create.sh
#
#     # Conteneur plus petit
#     vault-create.sh --size 5G
#
# EXIT CODES
#     0   Vault créé, monté, binds en place.
#     1   Erreur d'exécution : conteneur déjà ouvert, confirmation refusée,
#         échec cryptsetup/mkfs/mount.
#     2   Erreur d'usage : option inconnue.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly IMG="$HOME/vault.img"
readonly MAP_NAME="vault_prof"
readonly MNT="$HOME/Vault"
readonly DEFAULT_SIZE="15G"

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
SIZE="$DEFAULT_SIZE"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --size)
                SIZE="${2:-}"
                [[ -n "$SIZE" ]] || usage_error "--size requiert une valeur"
                shift 2
                ;;
            -h|--help) usage; exit 0 ;;
            *)         usage_error "Option inconnue : $1" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Nettoyage (efface la passphrase de l'environnement du script, coupe le
# rafraîchissement sudo en tâche de fond) — exécuté sur toute sortie, y
# compris avant que warmup_sudo ou read_passphrase n'aient tourné.
# -----------------------------------------------------------------------------
_SUDO_PID=""
cleanup() {
    if [[ -n "$_SUDO_PID" ]]; then
        kill "$_SUDO_PID" 2>/dev/null || true
    fi
    unset VAULT_PASSPHRASE || true
}
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_not_open() {
    if [[ -e "/dev/mapper/$MAP_NAME" ]]; then
        die "/dev/mapper/$MAP_NAME existe déjà : le vault semble ouvert. Lancez vault-close.sh avant de recréer le conteneur."
    fi
}

check_existing_container() {
    if [[ -e "$IMG" ]]; then
        warn "Un conteneur existe déjà : $IMG"
        warn "Continuer va l'ÉCRASER DÉFINITIVEMENT, avec tout ce qu'il contient."
        read -r -p "$(echo -e "${YELLOW}Tapez SUPPRIMER pour confirmer :${RESET} ")" answer
        [[ "$answer" == "SUPPRIMER" ]] || die "Annulé."
        rm -f "$IMG"
    fi
}

# -----------------------------------------------------------------------------
# Saisie de la passphrase (une seule fois, avant tout traitement)
# -----------------------------------------------------------------------------
read_passphrase() {
    local p1 p2

    info "Passphrase du vault (différente du mot de passe de session)."
    while true; do
        read -r -s -p "$(echo -e "${CYAN}Passphrase :${RESET} ")" p1; echo
        read -r -s -p "$(echo -e "${CYAN}Confirmation :${RESET} ")" p2; echo

        if [[ -z "$p1" ]]; then
            warn "Passphrase vide, réessayez."
        elif [[ "$p1" != "$p2" ]]; then
            warn "Les deux saisies ne correspondent pas, réessayez."
        else
            VAULT_PASSPHRASE="$p1"
            break
        fi
    done
}

# -----------------------------------------------------------------------------
# Sudo (Tier 2 : préchauffage + keep-alive, cf. CLAUDE.md)
# -----------------------------------------------------------------------------
warmup_sudo() {
    info "Droits administrateur nécessaires pour la suite (cryptsetup, mkfs, mount)."
    sudo -v
    ( while true; do sudo -n true; sleep 50; done ) &
    _SUDO_PID=$!
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
ensure_cryptsetup() {
    if dpkg -s cryptsetup &>/dev/null; then
        return
    fi
    info "Installation de cryptsetup..."
    sudo apt-get update -q
    sudo apt-get install -y cryptsetup
}

# -----------------------------------------------------------------------------
# Création du conteneur LUKS
# -----------------------------------------------------------------------------
create_container() {
    info "Création du conteneur ($SIZE) : $IMG"
    fallocate -l "$SIZE" "$IMG"
}

init_luks() {
    info "Initialisation LUKS..."
    # --batch-mode : saute la confirmation "Type YES". --key-file=- : lit la
    # passphrase sur stdin plutôt que sur le terminal (mode non interactif).
    printf '%s' "$VAULT_PASSPHRASE" | sudo cryptsetup luksFormat --batch-mode --key-file=- "$IMG"
}

open_luks() {
    info "Ouverture du volume..."
    printf '%s' "$VAULT_PASSPHRASE" | sudo cryptsetup open --key-file=- "$IMG" "$MAP_NAME"
}

format_fs() {
    info "Formatage en ext4..."
    sudo mkfs.ext4 -q "/dev/mapper/$MAP_NAME"
}

mount_and_bind() {
    local script_dir
    script_dir="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
    info "Montage et mise en place des binds (délégué à vault-open.sh)..."
    "$script_dir/vault-open.sh"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo -e "\n${BOLD}=== Création du Vault ===${RESET}\n"

    check_not_open
    check_existing_container
    read_passphrase
    warmup_sudo

    ensure_cryptsetup
    create_container
    init_luks
    open_luks
    format_fs
    mount_and_bind

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET} Vault créé et monté sur ${CYAN}$MNT${RESET}, binds en place.\n"
    info "Vérification : vault-status.sh"
}

main "$@"
