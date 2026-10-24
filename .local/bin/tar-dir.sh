#!/usr/bin/env bash
# NAME
#     tar-dir.sh — archive un ou plusieurs répertoires en fichiers .tar, avec
#                  barre de progression
#
# SYNOPSIS
#     tar-dir.sh REPERTOIRE... [-o DIR] [-h]
#
# DESCRIPTION
#     Crée « NOM.tar » pour chaque répertoire NOM donné, sans compression :
#     le contenu est regroupé tel quel dans un seul fichier. C'est l'étape
#     qui précède pack-split.sh, qui sait compresser et découper un fichier
#     mais pas un répertoire :
#
#         tar-dir.sh TP && pack-split.sh pack TP.tar
#
#     Plusieurs répertoires peuvent être passés, listés un à un ou par
#     joker. Le shell développe « TP* » avant l'appel ; un motif protégé par
#     des guillemets ('TP*') est développé par le script lui-même, ce qui
#     évite la limite de longueur d'une ligne de commande. Un argument qui
#     existe mais n'est pas un répertoire (cas de « * » dans un dossier
#     mêlant fichiers et répertoires) est ignoré.
#
#     Chaque archive est écrite dans le répertoire parent de sa source (ou
#     dans DIR avec -o). Si le fichier .tar existe déjà, ce répertoire est
#     sauté sans toucher au fichier, et le traitement continue avec le
#     suivant. Les erreurs sont rappelées toutes ensemble à la fin.
#
#     Chaque archive est d'abord écrite sous « NOM.tar.partial » puis
#     renommée : un « NOM.tar » est donc toujours complet.
#
#     La barre de progression est approximative : la taille totale est
#     estimée avant de commencer (contenu + en-têtes tar), la barre peut
#     donc s'arrêter un peu avant 100 %.
#
# OPTIONS
#     -o, --output DIR   Répertoire de sortie, créé au besoin
#                        (défaut : parent de chaque répertoire).
#     -h, --help         Affiche cette aide.
#
# EXAMPLES
#     # ~/projets/TP  →  ~/projets/TP.tar
#     tar-dir.sh ~/projets/TP
#
#     # Une archive par répertoire, sélection par joker
#     tar-dir.sh ~/projets/TP*
#
#     # Plusieurs répertoires, directement sur la clé USB
#     tar-dir.sh TP1 TP2 cours -o /media/usb
#
#     # Joker protégé : développé par le script (très grand nombre d'entrées)
#     tar-dir.sh 'logs-2026-*'
#
# EXIT CODES
#     0   Tous les répertoires ont été archivés (les arguments ignorés parce
#         qu'ils ne sont pas des répertoires ne sont pas des échecs).
#     1   Au moins un répertoire n'a pas été archivé : .tar déjà existant,
#         source introuvable ou motif sans résultat, échec de tar, disque
#         plein ; ou outil manquant (pv).
#     2   Erreur d'usage : option inconnue, aucun argument.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly TAR_EXT=".tar"
# Octets ajoutés par tar à chaque entrée (en-tête de 512 o + remplissage
# jusqu'au bloc suivant) : majorant volontaire, voir « barre approximative ».
readonly TAR_ENTRY_OVERHEAD=1024

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
    # Réimprime l'en-tête manpage (commentaires après le shebang) sans « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# Refuse une option à valeur laissée sans argument : sans ce garde-fou, le
# « shift 2 » échouerait et set -e ferait sortir le script sans message.
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Nettoyage en cas d'erreur ou d'interruption
# -----------------------------------------------------------------------------
PARTIAL=""

cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && -n "$PARTIAL" && -e "$PARTIAL" ]]; then
        warn "Échec ou interruption : suppression de l'archive incomplète."
        rm -f -- "$PARTIAL"
    fi
}
trap cleanup EXIT
# Ctrl-C et kill passent par exit pour déclencher le trap EXIT ci-dessus.
trap 'exit 130' INT
trap 'exit 143' TERM

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
ARGS=()             # arguments tels que reçus (répertoires ou motifs)
OUTDIR=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) value_of "$1" "${2-}"; OUTDIR="$2"; shift 2 ;;
            -h|--help)   usage; exit 0 ;;
            --)          shift; ARGS+=("$@"); break ;;
            -*)          usage_error "Option inconnue : $1" ;;
            *)           ARGS+=("$1"); shift ;;
        esac
    done

    [[ ${#ARGS[@]} -gt 0 ]] || usage_error "Argument manquant : REPERTOIRE."
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_tools() {
    command -v pv >/dev/null 2>&1 || die "'pv' est requis pour la barre de progression : sudo apt install pv"
}

human() { numfmt --to=iec --suffix=B "$1"; }

# -----------------------------------------------------------------------------
# Sélection des répertoires
# -----------------------------------------------------------------------------
TARGETS=()          # répertoires à archiver, après développement des jokers
FAILURES=()         # « source : raison », affichés au bilan
SKIPPED=()          # arguments ignorés (pas des répertoires)

collect_targets() {
    local arg match
    local matches=()
    for arg in "${ARGS[@]}"; do
        if [[ -d "$arg" ]]; then
            TARGETS+=("$arg")
        elif [[ -e "$arg" ]]; then
            SKIPPED+=("$arg")
        elif [[ "$arg" == *[*?[]* ]]; then
            # Joker protégé par des guillemets : le shell ne l'a pas développé.
            # compgen -G applique le même globbing que le shell, sans passer
            # par la ligne de commande.
            mapfile -t matches < <(compgen -G "$arg" | LC_ALL=C sort || true)
            if [[ ${#matches[@]} -eq 0 ]]; then
                FAILURES+=("$arg : aucun résultat pour ce motif")
                continue
            fi
            for match in "${matches[@]}"; do
                if [[ -d "$match" ]]; then
                    TARGETS+=("$match")
                else
                    SKIPPED+=("$match")
                fi
            done
        else
            FAILURES+=("$arg : introuvable")
        fi
    done
}

# -----------------------------------------------------------------------------
# Archivage
# -----------------------------------------------------------------------------
# Taille estimée de l'archive : somme des fichiers + majorant des en-têtes.
# Sert uniquement de total à pv ; une erreur de quelques Mo n'a pas de
# conséquence.
estimate_size() {
    find "$1" -printf '%y %s\n' 2>/dev/null \
        | awk -v ovh="$TAR_ENTRY_OVERHEAD" '
            { n++; if ($1 == "f") s += $2 }
            END { print s + n * ovh + 10240 }'
}

# Archive un répertoire. Renvoie 1 en enregistrant la raison dans FAILURES
# au lieu de quitter : le lot continue avec le répertoire suivant.
#
# Appelée dans un « if », la fonction s'exécute sans set -e : chaque étape
# qui peut échouer est donc testée explicitement.
archive_one() {
    local src_abs name parent out total

    src_abs=$(realpath -- "$1") || { FAILURES+=("$1 : chemin illisible"); return 1; }
    name=$(basename -- "$src_abs")
    if [[ "$src_abs" == "/" ]]; then
        FAILURES+=("$1 : refus d'archiver la racine du système")
        return 1
    fi

    parent="${OUTDIR:-$(dirname -- "$src_abs")}"
    mkdir -p -- "$parent" || { FAILURES+=("$1 : sortie inaccessible : $parent"); return 1; }
    parent=$(realpath -- "$parent")
    out="$parent/${name}${TAR_EXT}"

    if [[ -e "$out" ]]; then
        warn "Le fichier existe déjà, répertoire sauté : $out"
        FAILURES+=("$1 : le fichier existe déjà : $out")
        return 1
    fi

    info "Répertoire : $src_abs"
    info "Archive    : $out"
    total=$(estimate_size "$src_abs")
    info "Environ $(human "$total") à archiver."

    # -C parent + nom relatif : l'archive contient « NOM/… » et non le chemin
    # absolu, elle s'extrait donc n'importe où.
    PARTIAL="$out.partial"
    if ! tar -cf - -C "$(dirname -- "$src_abs")" -- "$name" \
            | pv -N "tar" -s "$total" > "$PARTIAL"; then
        rm -f -- "$PARTIAL"
        PARTIAL=""
        FAILURES+=("$1 : échec de tar ou d'écriture vers $out")
        return 1
    fi

    if ! mv -- "$PARTIAL" "$out"; then
        rm -f -- "$PARTIAL"
        PARTIAL=""
        FAILURES+=("$1 : impossible de renommer l'archive en $out")
        return 1
    fi
    PARTIAL=""

    success "Archive créée : ${BOLD}${out}${RESET} ($(human "$(stat -c %s -- "$out")"))"
}

# -----------------------------------------------------------------------------
# Bilan
# -----------------------------------------------------------------------------
report() {
    local created="$1" item
    echo -e "\n${BOLD}=== Bilan ===${RESET}"
    success "${created} archive(s) créée(s)."

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        warn "${#SKIPPED[@]} argument(s) ignoré(s), ce ne sont pas des répertoires :"
        for item in "${SKIPPED[@]}"; do echo "    - $item"; done
    fi

    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        error "${#FAILURES[@]} échec(s) :"
        for item in "${FAILURES[@]}"; do echo "    - $item" >&2; done
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_tools
    collect_targets

    local i=0 created=0 total=${#TARGETS[@]} dir
    for dir in ${TARGETS[@]+"${TARGETS[@]}"}; do
        i=$((i + 1))
        echo -e "\n${BOLD}[${i}/${total}]${RESET}"
        if archive_one "$dir"; then
            created=$((created + 1))
        fi
    done

    report "$created"
}

main "$@"
