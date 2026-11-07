#!/usr/bin/env bash
# NAME
#     git-main-to-master.sh — renomme la branche main en master (local + remote)
#
# SYNOPSIS
#     git-main-to-master.sh [DEPOT] [-r REMOTE] [-L] [-k] [-n] [-y] [-h]
#
# DESCRIPTION
#     Convertit un dépôt dont la branche principale s'appelle « main » vers
#     « master », convention de ce dépôt dotfile (voir l'alias git « start »).
#
#     Le script refuse de démarrer si le dépôt n'est pas propre : modifications
#     suivies, fichiers non suivis, fusion/rebase/cherry-pick en cours, ou
#     branche « master » déjà présente (localement ou sur le remote).
#
#     Séquence (le remote est traité en premier : s'il refuse, rien n'a bougé
#     en local) :
#       1. publication de main sous le nom master sur le remote ;
#       2. renommage local main → master ;
#       3. réglage du suivi (upstream) de master et des autres branches
#          locales qui suivaient remote/main ;
#       4. remote/HEAD pointé sur master ;
#       5. bascule de la branche par défaut GitHub (si le remote est GitHub
#          et que « gh » est disponible), puis suppression de main sur le
#          remote.
#
#     Un dépôt sans remote est converti en local seulement. La suppression
#     de main sur le remote est refusée par GitHub tant que main reste la
#     branche par défaut : le script le signale et sort avec le code 3.
#
#     Ce que le script ne fait PAS : il ne réécrit pas l'historique, ne
#     touche ni aux tags ni aux autres branches, et ne met pas à jour les
#     autres clones (voir le rappel affiché en fin d'exécution).
#
# OPTIONS
#     DEPOT                  Dépôt à convertir (défaut : répertoire courant).
#     -r, --remote NOM       Remote à convertir (défaut : origin).
#     -L, --local-only       Ne pas toucher au remote.
#     -k, --keep-remote-main Publier master sur le remote mais conserver
#                            main (pas de suppression, pas de bascule GitHub).
#     -n, --dry-run          Affiche les commandes sans rien modifier.
#     -y, --yes              Ne pas demander de confirmation.
#     -h, --help             Affiche cette aide.
#
# EXAMPLES
#     # Dépôt courant, après confirmation
#     git-main-to-master.sh
#
#     # Simulation sur un dépôt précis
#     git-main-to-master.sh ~/projets/mon-site --dry-run
#
#     # Lot de dépôts, sans question
#     for d in ~/projets/*/; do git-main-to-master.sh "$d" -y || true; done
#
#     # Local seulement (remote injoignable ou hors de contrôle)
#     git-main-to-master.sh -L
#
# EXIT CODES
#     0   Conversion terminée (ou dépôt déjà sur master : rien à faire).
#     1   Erreur d'exécution ou précondition non remplie : dépôt sale, pas un
#         dépôt Git, master déjà présente, remote injoignable ou en avance
#         sur main, confirmation refusée, échec de git.
#     2   Erreur d'usage : option inconnue, valeur manquante, dépôt introuvable.
#     3   Conversion faite et master publiée, mais main n'a pas pu être
#         supprimée sur le remote (souvent : encore branche par défaut).
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly OLD_BRANCH="main"
readonly NEW_BRANCH="master"
readonly DEFAULT_REMOTE="origin"

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
    # Réimprime l'en-tête manpage (lignes de commentaire après le shebang),
    # sans le préfixe « # » : l'aide reste juste même si l'en-tête grossit.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# Refuse une option à valeur laissée sans argument : sans ce garde-fou, le
# « shift 2 » échouerait et set -e ferait sortir le script silencieusement.
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_not_root() {
    # Lancé en root, git créerait des objets appartenant à root dans .git.
    if [ "$(id -u)" -eq 0 ]; then
        echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
        echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
SRC="."
REMOTE="$DEFAULT_REMOTE"
REMOTE_EXPLICIT="no"
LOCAL_ONLY="no"
KEEP_REMOTE_MAIN="no"
DRY_RUN="no"
ASSUME_YES="no"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--remote)           value_of "--remote" "${2-}"; REMOTE="$2"; REMOTE_EXPLICIT="yes"; shift 2 ;;
            -L|--local-only)       LOCAL_ONLY="yes"; shift ;;
            -k|--keep-remote-main) KEEP_REMOTE_MAIN="yes"; shift ;;
            -n|--dry-run)          DRY_RUN="yes"; shift ;;
            -y|--yes)              ASSUME_YES="yes"; shift ;;
            -h|--help)             usage; exit 0 ;;
            -*)                    usage_error "Option inconnue : $1" ;;
            *)                     SRC="$1"; shift ;;
        esac
    done

    [[ -d "$SRC" ]] || usage_error "Répertoire introuvable : $SRC"
}

# -----------------------------------------------------------------------------
# Aides git
# -----------------------------------------------------------------------------
REPO_ROOT=""

# Toutes les commandes git visent le dépôt résolu, quel que soit le répertoire
# courant (le script accepte un chemin en argument).
g() { git -C "$REPO_ROOT" "$@"; }

has_branch() { g show-ref --verify --quiet "refs/heads/$1"; }

# Exécute la commande, ou se contente de l'afficher en mode --dry-run.
run() {
    if [[ "$DRY_RUN" == "yes" ]]; then
        local cmd="$*"
        echo -e "${BOLD}[SIMULATION]${RESET} ${cmd/#g /git }"
        return 0
    fi
    "$@"
}

# -----------------------------------------------------------------------------
# Contrôles du dépôt local
# -----------------------------------------------------------------------------
resolve_repo() {
    command -v git >/dev/null 2>&1 || die "'git' n'est pas installé."

    git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 \
        || die "'$SRC' n'est pas un dépôt Git (ni un sous-dossier d'un dépôt)."

    # Un dépôt nu n'a pas d'arbre de travail : le test de propreté n'aurait
    # pas de sens et la procédure n'a pas été pensée pour lui.
    [[ "$(git -C "$SRC" rev-parse --is-bare-repository)" == "false" ]] \
        || die "Dépôt nu non géré : lancez le script depuis un clone."

    REPO_ROOT=$(git -C "$SRC" rev-parse --show-toplevel)
}

check_clean() {
    # Opération Git inachevée : le statut peut sembler propre en plein rebase.
    local marker
    for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
        if [[ -e "$(g rev-parse --git-path "$marker")" ]]; then
            die "Opération Git en cours (${marker}) : terminez-la ou abandonnez-la d'abord."
        fi
    done

    local status
    status=$(g status --porcelain)
    if [[ -n "$status" ]]; then
        error "Dépôt non propre : commitez, remisez ou supprimez ces changements d'abord."
        echo "$status" | head -n 10 >&2
        [[ $(echo "$status" | wc -l) -gt 10 ]] && echo "  [...]" >&2
        exit 1
    fi
}

check_branches() {
    if has_branch "$OLD_BRANCH"; then
        if has_branch "$NEW_BRANCH"; then
            die "Les branches ${OLD_BRANCH} et ${NEW_BRANCH} existent déjà toutes les deux : conversion ambiguë."
        fi
    else
        if has_branch "$NEW_BRANCH"; then
            success "Le dépôt utilise déjà ${BOLD}${NEW_BRANCH}${RESET} : rien à faire."
            exit 0
        fi
        die "Aucune branche locale ${OLD_BRANCH} dans ce dépôt."
    fi
}

# -----------------------------------------------------------------------------
# Contrôles du remote
# -----------------------------------------------------------------------------
HAS_REMOTE="no"
REMOTE_HAS_OLD="no"

check_remote() {
    [[ "$LOCAL_ONLY" == "yes" ]] && return 0

    if ! g remote get-url "$REMOTE" >/dev/null 2>&1; then
        # Remote demandé explicitement mais absent : erreur. Remote par défaut
        # absent : dépôt purement local, on convertit seulement la branche.
        [[ "$REMOTE_EXPLICIT" == "yes" ]] && die "Remote introuvable : $REMOTE"
        warn "Pas de remote '${REMOTE}' : conversion locale uniquement."
        return 0
    fi
    HAS_REMOTE="yes"

    # ls-remote plutôt que fetch pour détecter les branches : lecture seule,
    # et il échoue franchement si le remote est injoignable.
    local heads
    heads=$(g ls-remote --heads "$REMOTE" "$OLD_BRANCH" "$NEW_BRANCH") \
        || die "Remote '${REMOTE}' injoignable : conversion annulée, rien n'a été modifié."

    # ls-remote filtre par suffixe (« main » trouverait aussi feature/main) :
    # on compare donc le nom complet de la référence.
    if grep -q "[[:space:]]refs/heads/${NEW_BRANCH}\$" <<<"$heads"; then
        die "${REMOTE}/${NEW_BRANCH} existe déjà : à fusionner ou supprimer manuellement avant conversion."
    fi
    if grep -q "[[:space:]]refs/heads/${OLD_BRANCH}\$" <<<"$heads"; then
        REMOTE_HAS_OLD="yes"
    fi

    if [[ "$REMOTE_HAS_OLD" == "yes" ]]; then
        # main distante ne doit pas avoir de commits absents localement :
        # master serait publiée sans eux, puis main supprimée = perte.
        g fetch --quiet "$REMOTE" \
            || die "Échec du fetch sur '${REMOTE}'."
        g merge-base --is-ancestor "refs/remotes/${REMOTE}/${OLD_BRANCH}" "refs/heads/${OLD_BRANCH}" \
            || die "${REMOTE}/${OLD_BRANCH} contient des commits absents de ${OLD_BRANCH} local : faites d'abord un pull."
    else
        warn "${REMOTE}/${OLD_BRANCH} n'existe pas : ${NEW_BRANCH} sera simplement publiée."
    fi
}

# -----------------------------------------------------------------------------
# Plan et confirmation
# -----------------------------------------------------------------------------
show_plan() {
    echo -e "\n${BOLD}=== Conversion ${OLD_BRANCH} → ${NEW_BRANCH} ===${RESET}\n"
    info "Dépôt : $REPO_ROOT"
    info "Local : renommer ${BOLD}${OLD_BRANCH}${RESET} en ${BOLD}${NEW_BRANCH}${RESET}"
    if [[ "$HAS_REMOTE" == "yes" ]]; then
        info "Remote '${REMOTE}' : publier ${NEW_BRANCH}, régler le suivi et ${REMOTE}/HEAD"
        if [[ "$REMOTE_HAS_OLD" == "yes" && "$KEEP_REMOTE_MAIN" == "no" ]]; then
            warn "Remote '${REMOTE}' : ${BOLD}supprimer${RESET} ${OLD_BRANCH} (irréversible côté serveur)"
        elif [[ "$REMOTE_HAS_OLD" == "yes" ]]; then
            info "Remote '${REMOTE}' : ${OLD_BRANCH} conservée (--keep-remote-main)"
        fi
    fi
    echo ""
}

confirm() {
    [[ "$ASSUME_YES" == "yes" || "$DRY_RUN" == "yes" ]] && return 0
    # Sans terminal, impossible de poser la question : refuser plutôt que
    # supprimer une branche distante sans accord explicite.
    [[ -t 0 ]] || die "Aucun terminal pour confirmer : relancez avec --yes."

    local answer
    read -r -p "$(echo -e "${YELLOW}Continuer ?${RESET} [o/N] ")" answer
    [[ "$answer" =~ ^[oOyY]$ ]] || { info "Annulé."; exit 0; }
}

# -----------------------------------------------------------------------------
# Conversion
# -----------------------------------------------------------------------------
PARTIAL="no"

# Bascule la branche par défaut sur GitHub : sans elle, GitHub refuse de
# supprimer main ("refusing to delete the default branch").
set_github_default() {
    local url slug
    url=$(g remote get-url "$REMOTE")
    [[ "$url" == *github.com* ]] || return 0

    if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
        warn "gh absent ou non connecté : changez la branche par défaut dans Settings > Branches."
        return 0
    fi

    # git@github.com:OWNER/REPO.git | https://github.com/OWNER/REPO(.git)
    slug=$(sed -E 's#^.*github\.com[:/]##; s#\.git$##; s#/$##' <<<"$url")
    info "Branche par défaut GitHub → ${NEW_BRANCH} (${slug})"
    run gh repo edit "$slug" --default-branch "$NEW_BRANCH" \
        || warn "Échec de 'gh repo edit' : changez la branche par défaut dans Settings > Branches."
}

delete_remote_main() {
    set_github_default

    info "Suppression de ${REMOTE}/${OLD_BRANCH}"
    if ! run g push "$REMOTE" --delete "$OLD_BRANCH"; then
        warn "${REMOTE}/${OLD_BRANCH} n'a pas pu être supprimée (branche par défaut ou protégée ?)."
        warn "Changez la branche par défaut du dépôt, puis : git push ${REMOTE} --delete ${OLD_BRANCH}"
        PARTIAL="yes"
    fi
}

retarget_upstreams() {
    # Après « branch -m », master garde l'upstream remote/main de l'ancienne
    # main : on le fixe explicitement, puis on traite les autres branches
    # locales qui suivaient remote/main.
    run g branch -u "${REMOTE}/${NEW_BRANCH}" "$NEW_BRANCH"

    local branch upstream
    while read -r branch upstream; do
        if [[ "$upstream" == "${REMOTE}/${OLD_BRANCH}" ]]; then
            info "Suivi de ${branch} : ${REMOTE}/${OLD_BRANCH} → ${REMOTE}/${NEW_BRANCH}"
            run g branch -u "${REMOTE}/${NEW_BRANCH}" "$branch"
        fi
    done < <(g for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads)
}

convert() {
    if [[ "$HAS_REMOTE" == "yes" ]]; then
        # Publier d'abord : si le remote refuse, le dépôt local est intact.
        info "Publication de ${OLD_BRANCH} sous le nom ${NEW_BRANCH} sur '${REMOTE}'"
        run g push "$REMOTE" "refs/heads/${OLD_BRANCH}:refs/heads/${NEW_BRANCH}" \
            || die "Push refusé : rien n'a été modifié en local."
    fi

    info "Renommage local ${OLD_BRANCH} → ${NEW_BRANCH}"
    run g branch -m "$OLD_BRANCH" "$NEW_BRANCH"

    if [[ "$HAS_REMOTE" == "yes" ]]; then
        retarget_upstreams
        run g remote set-head "$REMOTE" "$NEW_BRANCH" >/dev/null

        if [[ "$REMOTE_HAS_OLD" == "yes" && "$KEEP_REMOTE_MAIN" == "no" ]]; then
            delete_remote_main
        fi
    fi
}

report() {
    echo ""
    if [[ "$DRY_RUN" == "yes" ]]; then
        info "Simulation terminée : rien n'a été modifié."
        return 0
    fi

    if [[ "$PARTIAL" == "yes" ]]; then
        warn "Conversion terminée, mais ${REMOTE}/${OLD_BRANCH} subsiste."
    else
        success "Dépôt converti : ${BOLD}${NEW_BRANCH}${RESET}"
    fi

    if [[ "$HAS_REMOTE" == "yes" ]]; then
        info "Dans chaque autre clone de ce dépôt :"
        echo "    git fetch --prune ${REMOTE}"
        echo "    git branch -m ${OLD_BRANCH} ${NEW_BRANCH}"
        echo "    git branch -u ${REMOTE}/${NEW_BRANCH} ${NEW_BRANCH}"
        echo "    git remote set-head ${REMOTE} ${NEW_BRANCH}"
    fi
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    check_not_root
    parse_args "$@"
    resolve_repo
    check_clean
    check_branches
    check_remote
    show_plan
    confirm
    convert
    report
    [[ "$PARTIAL" == "no" ]] || exit 3
}

main "$@"
