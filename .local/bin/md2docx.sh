#!/usr/bin/env bash
# NAME
#     md2docx.sh — convertit un fichier Markdown en .docx via le profil pandoc "bts-sio"
#
# SYNOPSIS
#     md2docx.sh FICHIER.md [options pandoc...]
#     md2docx.sh -h|--help
#
# DESCRIPTION
#     Convertit FICHIER.md en .docx avec pandoc, en appliquant systématiquement
#     le defaults file "bts-sio" (-d bts-sio) et en déduisant le fichier de
#     sortie du nom d'entrée : "SEANCE.md" -> "SEANCE.docx".
#
#     Équivaut à :
#         pandoc -d bts-sio -o SEANCE.docx SEANCE.md
#
#     Toute option ajoutée après le fichier est transmise telle quelle à
#     pandoc, insérée avant le fichier d'entrée. Pandoc ne retenant que la
#     dernière occurrence d'une option, cela permet de surcharger -o ou -d
#     au besoin (ex: -d autre-profil).
#
# OPTIONS
#     FICHIER.md   Fichier Markdown à convertir (obligatoire, extension .md).
#     -h, --help   Affiche cette aide. Doit être le premier argument, sinon
#                  transmis à pandoc comme les autres options.
#     ...          Toute autre option est transmise à pandoc.
#
# EXAMPLES
#     # Conversion simple : produit SEANCE.docx
#     md2docx.sh SEANCE.md
#
#     # Ajout d'une option pandoc (table des matières)
#     md2docx.sh SEANCE.md --toc
#
#     # Surcharge du fichier de sortie
#     md2docx.sh SEANCE.md -o /tmp/brouillon.docx
#
# EXIT CODES
#     0   Conversion réussie.
#     1   Erreur d'exécution : pandoc absent ou échec de la conversion.
#     2   Erreur d'usage : pas d'argument, fichier introuvable, extension
#         différente de .md.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PANDOC_PROFILE="bts-sio"

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
    # Réimprime le bloc d'en-tête manpage (voir pack-bundle.sh pour la même
    # convention) : l'aide reste juste même si l'en-tête grossit.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
INPUT=""
OUTPUT=""
PANDOC_ARGS=()

parse_args() {
    [[ $# -gt 0 ]] || usage_error "Fichier Markdown manquant."

    case "$1" in
        -h|--help) usage; exit 0 ;;
    esac

    INPUT="$1"
    shift
    PANDOC_ARGS=("$@")
}

# -----------------------------------------------------------------------------
# Validation et résolution du fichier de sortie
# -----------------------------------------------------------------------------
validate_input() {
    [[ -f "$INPUT" ]] || usage_error "Fichier introuvable : $INPUT"
    [[ "$INPUT" == *.md ]] || usage_error "Le fichier doit avoir l'extension .md : $INPUT"
}

resolve_output() {
    OUTPUT="${INPUT%.md}.docx"
}

# -----------------------------------------------------------------------------
# Conversion
# -----------------------------------------------------------------------------
convert() {
    command -v pandoc >/dev/null 2>&1 || die "'pandoc' n'est pas installé."

    info "Entrée  : $INPUT"
    info "Sortie  : $OUTPUT"
    info "Profil  : $PANDOC_PROFILE"

    pandoc -d "$PANDOC_PROFILE" -o "$OUTPUT" "${PANDOC_ARGS[@]}" "$INPUT" \
        || die "Échec de la conversion pandoc."

    success "Document généré : ${BOLD}${OUTPUT}${RESET}"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    validate_input
    resolve_output
    convert
}

main "$@"
