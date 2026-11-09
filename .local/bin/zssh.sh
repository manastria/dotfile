#!/usr/bin/env bash
# NAME
#     zssh.sh — connexion SSH vers une machine dotfile, avec tmux et profil zsh
#
# SYNOPSIS
#     zssh.sh [-e PROFIL] [-D] [OPTIONS_SSH...] HOTE
#     zssh.sh -h | --help
#
# DESCRIPTION
#     Ouvre une session SSH et y lance, côté distant, la session tmux « main »
#     avec le profil zsh demandé (variable ZSH_PROFILE). La session est créée
#     si elle n'existe pas, sinon on s'y rattache : après une coupure réseau,
#     relancer la même commande retrouve le travail en cours.
#
#     La machine distante doit disposer des dotfiles et de tmux. Pour lancer
#     un profil sur la machine LOCALE, utiliser « zenv » (voir zenv.sh).
#
#     Les options propres à zssh.sh se placent AVANT toutes les options ssh ;
#     dès le premier argument non reconnu, tout le reste est transmis tel
#     quel à ssh. Un « -D » placé après est donc l'option ssh -D (redirection
#     de port dynamique), pas celle de zssh.sh.
#
# OPTIONS
#     -e, --profile PROFIL   Profil zsh distant (défaut : ssh).
#     -D, --detach           Détache d'abord les autres clients déjà attachés
#                            à la session « main » (reprise d'une session
#                            restée ouverte ailleurs) : tmux new-session -D.
#     -h, --help             Affiche cette aide.
#     OPTIONS_SSH            Toute option ssh (-p, -i, -J, -o…), puis l'hôte.
#
# EXAMPLES
#     # Profil par défaut (ssh)
#     zssh.sh user@host
#
#     # Autre profil, port et clé SSH personnalisés
#     zssh.sh -e writer -p 2222 -i ~/.ssh/id_ed25519 user@host
#
#     # Reprendre la session restée ouverte sur un autre poste
#     zssh.sh -D user@host
#
# EXIT CODES
#     0   Session terminée normalement.
#     1   Erreur d'exécution : ssh absent.
#     2   Erreur d'usage : option inconnue, valeur manquante, hôte absent.
#     *   Sinon, code de retour de ssh (255 : échec de connexion).
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly DEFAULT_PROFILE="ssh"
readonly TMUX_SESSION="main"

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
    # Réimprime l'en-tête manpage sans le préfixe « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
PROFILE="$DEFAULT_PROFILE"
DETACH=""
SSH_ARGS=()

parse_args() {
    # Seules les options de zssh sont lues ici ; au premier argument inconnu
    # (option ssh ou hôte), la boucle s'arrête et le reste part vers ssh.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--profile)
                [[ -n "${2:-}" ]] || usage_error "$1 attend une valeur."
                PROFILE="$2"; shift 2 ;;
            -D|--detach) DETACH="-D"; shift ;;
            -h|--help)   usage; exit 0 ;;
            --)          shift; break ;;
            *)           break ;;
        esac
    done

    [[ $# -gt 0 ]] || usage_error "Hôte manquant."
    SSH_ARGS=("$@")

    # Le profil est inséré dans une commande exécutée par le shell distant :
    # on le restreint à des caractères sûrs plutôt que d'échapper.
    [[ "$PROFILE" =~ ^[A-Za-z0-9._-]+$ ]] \
        || usage_error "Nom de profil invalide : $PROFILE"
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_ssh() {
    command -v ssh >/dev/null 2>&1 || die "ssh introuvable dans le PATH."
}

# -----------------------------------------------------------------------------
# Connexion
# -----------------------------------------------------------------------------
connect() {
    # -t : pseudo-terminal obligatoire pour tmux.
    # new-session -A : crée la session ou s'y rattache ; avec -D, détache
    # aussi les autres clients. ${DETACH:+ …} évite un double espace si absent.
    # exec : le code de retour de ssh devient celui du script.
    exec ssh -t "${SSH_ARGS[@]}" \
        "TERM=xterm-256color ZSH_PROFILE='${PROFILE}' tmux new-session -A${DETACH:+ $DETACH} -s ${TMUX_SESSION}"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_ssh
    connect
}

main "$@"
