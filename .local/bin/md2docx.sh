#!/usr/bin/env bash
# NAME
#     md2docx.sh — convertit un ou plusieurs fichiers Markdown en .docx via le profil pandoc "bts-sio"
#
# SYNOPSIS
#     md2docx.sh FICHIER.md... [options pandoc...]
#     md2docx.sh -h|--help
#
# DESCRIPTION
#     Convertit un ou plusieurs FICHIER.md en .docx avec pandoc, en appliquant
#     systématiquement le defaults file "bts-sio" (-d bts-sio) et en déduisant
#     le fichier de sortie de chaque entrée : "SEANCE.md" -> "SEANCE.docx".
#
#     Accepte plusieurs fichiers en argument, en les nommant explicitement
#     (seance1.md seance2.md) ou via un joker shell (*.md) : chaque fichier
#     est converti séparément, avec le même jeu d'options pandoc.
#
#     Équivaut, pour chaque fichier, à :
#         pandoc -d bts-sio -o SEANCE.docx SEANCE.md
#
#     Tous les arguments se terminant par .md et placés en tête de ligne de
#     commande sont traités comme fichiers d'entrée ; tout ce qui suit est
#     transmis tel quel à pandoc, pour chaque conversion. Pandoc ne retenant
#     que la dernière occurrence d'une option, cela permet de surcharger -d
#     au besoin (ex: -d autre-profil) — mais pas -o/--output, refusée dès que
#     plusieurs fichiers sont fournis (toutes les sorties collisionneraient
#     sur un seul nom).
#
# OPTIONS
#     FICHIER.md...  Un ou plusieurs fichiers Markdown à convertir (obligatoire,
#                    extension .md), en arguments explicites ou via un joker
#                    (*.md).
#     -h, --help     Affiche cette aide. Doit être le premier argument, sinon
#                    transmis à pandoc comme les autres options.
#     ...            Toute autre option est transmise à pandoc pour chaque
#                    fichier. -o/--output est refusée dès que plusieurs
#                    fichiers sont fournis.
#
# EXAMPLES
#     # Conversion simple : produit SEANCE.docx
#     md2docx.sh SEANCE.md
#
#     # Plusieurs fichiers explicites
#     md2docx.sh seance1.md seance2.md seance3.md
#
#     # Tous les Markdown du répertoire courant
#     md2docx.sh *.md
#
#     # Ajout d'une option pandoc (table des matières), appliquée à chaque fichier
#     md2docx.sh *.md --toc
#
#     # Surcharge du fichier de sortie (un seul fichier à la fois)
#     md2docx.sh SEANCE.md -o /tmp/brouillon.docx
#
# EXIT CODES
#     0   Conversion(s) réussie(s).
#     1   Erreur d'exécution : pandoc absent, ou échec d'au moins une conversion.
#     2   Erreur d'usage : aucun fichier .md, fichier introuvable, ou
#         -o/--output combiné à plusieurs fichiers.
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
INPUTS=()
PANDOC_ARGS=()

parse_args() {
    [[ $# -gt 0 ]] || usage_error "Fichier(s) Markdown manquant(s)."

    case "$1" in
        -h|--help) usage; exit 0 ;;
    esac

    # Les arguments se terminant par .md, en tête de ligne de commande, sont
    # les fichiers d'entrée ; le premier argument qui ne correspond plus à ce
    # motif marque le début des options pandoc.
    while [[ $# -gt 0 && "$1" == *.md ]]; do
        INPUTS+=("$1")
        shift
    done

    [[ ${#INPUTS[@]} -gt 0 ]] || usage_error "Aucun fichier .md fourni."

    PANDOC_ARGS=("$@")
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
validate_inputs() {
    local f
    for f in "${INPUTS[@]}"; do
        [[ -f "$f" ]] || usage_error "Fichier introuvable : $f"
    done
}

check_output_override() {
    # -o/--output n'a de sens que pour un fichier unique : avec plusieurs
    # entrées, toutes les sorties écraseraient le même nom.
    [[ ${#INPUTS[@]} -gt 1 ]] || return 0

    local a
    for a in "${PANDOC_ARGS[@]}"; do
        [[ "$a" == "-o" || "$a" == --output* ]] \
            && usage_error "-o/--output n'est pas compatible avec plusieurs fichiers en entrée."
    done
    return 0
}

# -----------------------------------------------------------------------------
# Conversion
# -----------------------------------------------------------------------------
convert_one() {
    local input="$1"
    local output="${input%.md}.docx"

    info "Entrée  : $input"
    info "Sortie  : $output"
    info "Profil  : $PANDOC_PROFILE"

    if pandoc -d "$PANDOC_PROFILE" -o "$output" "${PANDOC_ARGS[@]}" "$input"; then
        success "Document généré : ${BOLD}${output}${RESET}"
    else
        error "Échec de la conversion pandoc : $input"
        return 1
    fi
}

convert_all() {
    command -v pandoc >/dev/null 2>&1 || die "'pandoc' n'est pas installé."

    local failures=0
    for input in "${INPUTS[@]}"; do
        convert_one "$input" || failures=$((failures + 1))
    done

    [[ $failures -eq 0 ]] || die "$failures conversion(s) échouée(s) sur ${#INPUTS[@]}."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    validate_inputs
    check_output_override
    convert_all
}

main "$@"
