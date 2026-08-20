#!/usr/bin/env bash
# NAME
#     pack-bundle.sh — archive un dépôt Git complet dans un fichier .bundle
#
# SYNOPSIS
#     pack-bundle.sh [DEPOT] [-b NOM] [-o DIR] [-r REF]... [-T] [-f] [-h]
#
# DESCRIPTION
#     Crée un « git bundle » du dépôt DEPOT (défaut : répertoire courant) et
#     l'écrit dans le répertoire parent du dépôt, à la manière de
#     pack-dir.sh et pack-project.sh.
#
#     Un bundle est un fichier unique contenant l'historique Git (commits,
#     branches, tags). Il se clone directement :
#
#         git clone mon-projet_20260820_1030.bundle mon-projet
#
#     C'est donc une sauvegarde ou un transfert hors-ligne du dépôt, à la
#     différence d'une archive tar qui ne capture que l'arborescence de
#     travail à un instant donné. En contrepartie, le bundle ne contient
#     QUE ce qui est commité : modifications non commitées, fichiers non
#     suivis et fichiers ignorés (.env, artefacts de build…) en sont
#     absents. Le script prévient si l'arbre de travail n'est pas propre.
#
#     Par défaut le bundle embarque toutes les références (« --all ») plus
#     HEAD, ce qui le rend clonable tel quel. L'option -r restreint le
#     contenu à des références précises (branche, tag, plage de révisions).
#
# OPTIONS
#     -b, --base NOM     Nom de base du fichier (défaut : nom du dépôt).
#     -o, --output DIR   Répertoire de sortie (défaut : parent du dépôt).
#     -r, --ref REF      Référence à inclure, répétable. Remplace le
#                        « --all HEAD » par défaut. Accepte tout ce que
#                        comprend git-rev-list : main, v1.0, --branches,
#                        origin/main..main…
#     -T, --no-timestamp Ne pas ajouter « _AAAAMMJJ_HHMM » au nom.
#     -f, --force        Écrase un bundle existant du même nom.
#     -h, --help         Affiche cette aide.
#
# EXAMPLES
#     # Sauvegarde complète du dépôt courant dans le répertoire parent
#     pack-bundle.sh
#
#     # Sauvegarde d'un dépôt précis vers une clé USB
#     pack-bundle.sh ~/projets/dotfile -o /media/usb/backup
#
#     # Nom fixe, sans horodatage : pratique pour un rsync incrémental
#     pack-bundle.sh -T -b dotfile-backup
#
#     # Bundle d'une seule branche, pour transmettre un travail en cours
#     pack-bundle.sh -r dev1
#
#     # Bundle incrémental : uniquement ce qui manque au collègue
#     pack-bundle.sh -r origin/main..main -b delta
#
#     # Restauration
#     git clone dotfile_20260820_1030.bundle dotfile
#
# EXIT CODES
#     0   Bundle créé et vérifié.
#     1   Erreur d'exécution (pas un dépôt Git, dépôt vide, échec de git).
#     2   Erreur d'usage : option inconnue, argument manquant, chemin
#         introuvable, ou bundle déjà existant sans --force.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly BUNDLE_EXT="bundle"

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
    # Réimprime le bloc d'en-tête manpage (toutes les lignes de commentaire
    # qui suivent le shebang) en retirant le préfixe « # ». Extraction par
    # motif plutôt que par numéros de ligne : l'aide reste juste même si
    # l'en-tête grossit.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# Refuse une option à valeur laissée sans argument : sans ce garde-fou, le
# « shift 2 » correspondant échouerait et set -e ferait sortir le script
# silencieusement.
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
SRC="."
BASE=""
OUTDIR=""
REFS=()
ADD_TIMESTAMP="yes"
FORCE="no"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--base)         value_of "--base" "${2-}";   BASE="$2";   shift 2 ;;
            -o|--output)       value_of "--output" "${2-}"; OUTDIR="$2"; shift 2 ;;
            -r|--ref)          value_of "--ref" "${2-}";    REFS+=("$2"); shift 2 ;;
            -T|--no-timestamp) ADD_TIMESTAMP="no"; shift ;;
            -f|--force)        FORCE="yes"; shift ;;
            -h|--help)         usage; exit 0 ;;
            -*)                usage_error "Option inconnue : $1" ;;
            *)                 SRC="$1"; shift ;;
        esac
    done

    [[ -d "$SRC" ]] || usage_error "Répertoire introuvable : $SRC"
}

# -----------------------------------------------------------------------------
# Résolution du dépôt et du fichier de sortie
# -----------------------------------------------------------------------------
REPO_ROOT=""     # racine de l'arbre de travail, ou du dépôt nu
IS_BARE="no"
BUNDLE=""

resolve_repo() {
    command -v git >/dev/null 2>&1 || die "'git' n'est pas installé."

    git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 \
        || die "'$SRC' n'est pas un dépôt Git (ni un sous-dossier d'un dépôt)."

    IS_BARE=$(git -C "$SRC" rev-parse --is-bare-repository)
    if [[ "$IS_BARE" == "true" ]]; then
        # Un dépôt nu n'a pas d'arbre de travail : on se rabat sur le
        # répertoire .git lui-même (souvent « projet.git »).
        # --absolute-git-dir plutôt que --git-dir, qui renvoie « . » pour un
        # dépôt nu et serait résolu depuis le répertoire courant, pas depuis SRC.
        REPO_ROOT=$(git -C "$SRC" rev-parse --absolute-git-dir)
    else
        REPO_ROOT=$(git -C "$SRC" rev-parse --show-toplevel)
    fi

    # Un dépôt sans aucune référence produirait un bundle vide et illisible.
    [[ -n "$(git -C "$REPO_ROOT" for-each-ref --count=1 refs/)" ]] \
        || die "Dépôt sans aucune référence (aucun commit) : rien à empaqueter."
}

resolve_output() {
    OUTDIR="${OUTDIR:-$(dirname "$REPO_ROOT")}"
    mkdir -p "$OUTDIR" || die "Impossible de créer le répertoire de sortie : $OUTDIR"
    OUTDIR=$(realpath "$OUTDIR")

    # Le suffixe « .git » d'un dépôt nu ne doit pas se retrouver dans le nom.
    local default_base
    default_base=$(basename "$REPO_ROOT")
    default_base="${default_base%.git}"
    BASE="${BASE:-$default_base}"

    local suffix=""
    [[ "$ADD_TIMESTAMP" == "yes" ]] && suffix="_$(date +%Y%m%d_%H%M)"

    BUNDLE="${OUTDIR}/${BASE}${suffix}.${BUNDLE_EXT}"

    if [[ -e "$BUNDLE" && "$FORCE" != "yes" ]]; then
        error "Le fichier existe déjà : $BUNDLE"
        echo "Utilisez --force pour l'écraser, ou -b pour changer de nom." >&2
        exit 2
    fi

    # Écrire dans le dépôt lui-même pollue le statut Git et, sans horodatage,
    # ferait grossir le bundle suivant de la copie du précédent.
    case "$OUTDIR/" in
        "$REPO_ROOT"/*) warn "Le bundle est écrit à l'intérieur du dépôt : pensez à l'ignorer." ;;
    esac
}

# -----------------------------------------------------------------------------
# Contrôles avant empaquetage
# -----------------------------------------------------------------------------
check_worktree() {
    [[ "$IS_BARE" == "true" ]] && return 0

    local dirty
    dirty=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | wc -l)
    if [[ "$dirty" -gt 0 ]]; then
        warn "Arbre de travail non propre : ${BOLD}${dirty}${RESET} entrée(s) modifiée(s) ou non suivie(s)."
        warn "Un bundle ne contient que les commits — ces changements ne seront PAS sauvegardés."
    fi

    # Les sous-modules ont leur propre historique : le bundle du dépôt parent
    # n'enregistre que le commit pointé, pas les objets du sous-module.
    if [[ -f "$REPO_ROOT/.gitmodules" ]]; then
        warn "Le dépôt a des sous-modules : leur historique n'est pas inclus dans le bundle."
    fi
}

# -----------------------------------------------------------------------------
# Création du bundle
# -----------------------------------------------------------------------------
create_bundle() {
    # Sans -r explicite : toutes les refs plus HEAD, ce qui rend le bundle
    # directement clonable (git clone a besoin de HEAD pour choisir la
    # branche à extraire).
    local refs=("--all" "HEAD")
    [[ ${#REFS[@]} -gt 0 ]] && refs=("${REFS[@]}")

    info "Dépôt      : $REPO_ROOT"
    info "Bundle     : $BUNDLE"
    info "Références : ${BOLD}${refs[*]}${RESET}"
    echo ""

    # Un bundle interrompu est un fichier tronqué que git refusera : on le
    # supprime plutôt que de le laisser passer pour une sauvegarde valide.
    cleanup() {
        rm -f "$BUNDLE"
        error "Interruption ou erreur — bundle incomplet supprimé."
        exit 1
    }
    trap cleanup ERR INT TERM

    info "Création du bundle..."
    git -C "$REPO_ROOT" bundle create "$BUNDLE" "${refs[@]}"

    trap - ERR INT TERM
}

verify_bundle() {
    info "Vérification..."
    # git bundle verify relit le fichier et contrôle que les prérequis
    # (commits attendus côté destinataire) sont satisfaits — c'est la seule
    # garantie que la sauvegarde est exploitable.
    git bundle verify "$BUNDLE" >/dev/null 2>&1 \
        || die "Le bundle créé est invalide : $BUNDLE"

    local size heads
    size=$(du -sh "$BUNDLE" | cut -f1)
    heads=$(git bundle list-heads "$BUNDLE" | wc -l)
    success "Bundle : ${BOLD}${BUNDLE}${RESET} (${size}, ${heads} référence(s))"
    info "Restauration : git clone \"$(basename "$BUNDLE")\" ${BASE}"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    resolve_repo
    resolve_output
    check_worktree
    create_bundle
    verify_bundle
}

main "$@"
