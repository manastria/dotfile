#!/usr/bin/env bash
# NAME
#     git-check-sync.sh — état de synchronisation des dépôts Git d'un répertoire
#
# SYNOPSIS
#     git-check-sync.sh [-d DIR] [-n] [-t SEC] [-q] [-x CAT,...] [-o CAT,...]
#                       [--hide-ok] [--hide-non-git] [-y | -r] [-h]
#     git-check-sync.sh [DIR]
#
# DESCRIPTION
#     Passe en revue chaque sous-dossier de DIR (premier niveau uniquement,
#     pas de récursion) et rapporte l'état de chaque dépôt Git vis-à-vis de
#     son remote « origin », quelle que soit la forge (GitHub, GitLab,
#     Codeberg, self-hosted…). Pensé comme un état des lieux avant de
#     quitter la machine : rien de non commité, rien de non poussé, rien de
#     bizarre côté distant.
#
#     Après le tableau, deux cas sans ambiguïté sont proposés à la mise à
#     jour : les dépôts UNIQUEMENT en retard (« git pull --rebase ») et ceux
#     qui ont UNIQUEMENT des commits à pousser (« git push »). « Uniquement »
#     signifie aucun autre constat : arbre propre, fetch réussi, pas de
#     divergence ni de réécriture. Rien n'est lancé sans confirmation (ou
#     --yes). Hors de ces actions acceptées, la seule commande écrivante est
#     « git fetch », qui met uniquement à jour les branches de suivi.
#
# OPTIONS
#     -d, --dir DIR        Répertoire à scanner (défaut : répertoire courant).
#                          DIR accepté aussi en argument positionnel.
#     -n, --no-fetch       Ne contacte aucun remote pendant le scan. Le rapport
#                          se base alors sur les dernières branches de suivi
#                          connues : plus rapide, mais possiblement périmé.
#     -t, --timeout SEC    Délai maximum par opération réseau : fetch, et
#                          pull/push acceptés (défaut : 20).
#     -q, --quiet          N'affiche que le tableau final, sans le détail
#                          déroulant dépôt par dépôt.
#     -x, --hide CAT,...   Masque les dépôts dont TOUS les constats sont dans
#                          la liste (un dépôt « MODIFS + A-POUSSER » reste
#                          affiché avec --hide modifs).
#     -o, --only CAT,...   N'affiche que les dépôts ayant AU MOINS un constat
#                          de la liste.
#         --hide-ok        Raccourci de --hide ok.
#         --hide-non-git   Raccourci de --hide non-git.
#     -y, --yes            Applique les mises à jour proposées sans demander.
#     -r, --report-only    Rapport seul : ne propose aucune mise à jour.
#     -h, --help           Affiche cette aide.
#
#     Catégories (insensibles à la casse, options répétables) :
#         ok  non-git  vide  modifs  sans-remote  fetch-ko  sans-branche
#         sans-upstream  force-push  divergence  a-pousser  a-recuperer
#
#     Les dépôts masqués ne comptent ni dans le code de retour ni dans les
#     mises à jour proposées.
#
# EXAMPLES
#     # État des lieux du répertoire de projets courant
#     cd ~/projets && git-check-sync.sh
#
#     # Seulement ce qui demande attention, sans les dossiers non-git
#     git-check-sync.sh --hide ok,non-git ~/projets
#
#     # Lister les dépôts à pousser, et les pousser sans question
#     git-check-sync.sh -o a-pousser -y ~/projets
#
#     # Scanner sans accès réseau (avion, hors-ligne), sans rien proposer
#     git-check-sync.sh --no-fetch -r ~/projets
#
#     # Hook de fin de session : ne rend la main proprement que si tout est
#     # synchronisé
#     git-check-sync.sh -q -r ~/projets || echo "Des projets demandent attention"
#
# EXIT CODES
#     0   Tous les dépôts affichés sont propres et synchronisés (après les
#         éventuelles mises à jour acceptées).
#     1   Au moins un point d'attention parmi les dépôts affichés (non
#         commité, non poussé, en retard, divergence, force-push, fetch ou
#         mise à jour en échec, dossier non-git…).
#     2   Erreur d'usage : option ou catégorie inconnue, répertoire
#         introuvable, options incompatibles.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly REMOTE_NAME="origin"
readonly DEFAULT_TIMEOUT=20
readonly LABEL_WIDTH=13
readonly CATEGORIES=" OK NON-GIT VIDE MODIFS SANS-REMOTE FETCH-KO SANS-BRANCHE SANS-UPSTREAM FORCE-PUSH DIVERGENCE A-POUSSER A-RECUPERER "

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

# Constat grave dans le rapport (divergence, force-push). Volontairement sur
# stdout et non stderr comme error() : ce n'est pas une erreur d'exécution du
# script mais une ligne du rapport, qui doit rester dans l'ordre du tableau
# lors d'une redirection « git-check-sync.sh > rapport.txt ».
critical() { echo -e "${RED}[CRITIQUE]${RESET}  $*"; }

usage() {
    # Réimprime le bloc d'en-tête manpage (toutes les lignes de commentaire
    # qui suivent le shebang) en retirant le préfixe « # ». Extraction par
    # motif plutôt que par numéros de ligne : l'aide reste juste même si
    # l'en-tête grossit.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
BASE_DIR="."
DO_FETCH="yes"
FETCH_TIMEOUT="$DEFAULT_TIMEOUT"
QUIET="no"
# ask : proposer (si terminal) ; yes : appliquer ; none : rapport seul
ACTION_MODE="ask"
# Ensembles de catégories sous forme « ␣A␣B␣ » : le test d'appartenance se
# réduit alors à un motif *" X "*, sans tableau associatif.
HIDE_SET=""
ONLY_SET=""

# add_categories <nom-de-variable> <liste séparée par des virgules>
# Normalise en majuscules et refuse toute catégorie inconnue : une faute de
# frappe dans --hide masquerait sinon silencieusement… rien du tout.
add_categories() {
    local var="$1" list="$2" cat
    local -a items
    [[ -n "$list" ]] || usage_error "Liste de catégories vide."
    IFS=',' read -r -a items <<< "$list"
    for cat in "${items[@]}"; do
        cat="${cat^^}"
        cat="${cat// /}"
        [[ -n "$cat" ]] || continue
        [[ "$CATEGORIES" == *" $cat "* ]] \
            || usage_error "Catégorie inconnue : $cat (voir --help)."
        printf -v "$var" '%s' "${!var:- }$cat "
    done
}

set_action_mode() {
    if [[ "$ACTION_MODE" != "ask" && "$ACTION_MODE" != "$1" ]]; then
        usage_error "--yes et --report-only sont incompatibles."
    fi
    ACTION_MODE="$1"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)        BASE_DIR="${2:-}"; shift 2 ;;
            -t|--timeout)    FETCH_TIMEOUT="${2:-}"; shift 2 ;;
            -x|--hide)       add_categories HIDE_SET "${2:-}"; shift 2 ;;
            -o|--only)       add_categories ONLY_SET "${2:-}"; shift 2 ;;
            --hide-ok)       add_categories HIDE_SET "OK"; shift ;;
            --hide-non-git)  add_categories HIDE_SET "NON-GIT"; shift ;;
            -n|--no-fetch)   DO_FETCH="no"; shift ;;
            -q|--quiet)      QUIET="yes"; shift ;;
            -y|--yes)        set_action_mode "yes"; shift ;;
            -r|--report-only) set_action_mode "none"; shift ;;
            -h|--help)       usage; exit 0 ;;
            -*)              usage_error "Option inconnue : $1" ;;
            *)               BASE_DIR="$1"; shift ;;
        esac
    done

    [[ -n "$BASE_DIR" ]] || usage_error "--dir attend un répertoire."
    [[ "$FETCH_TIMEOUT" =~ ^[0-9]+$ ]] || usage_error "--timeout attend un entier (secondes)."
    [[ -d "$BASE_DIR" ]] || usage_error "Répertoire introuvable : $BASE_DIR"
}

# -----------------------------------------------------------------------------
# Environnement Git
# -----------------------------------------------------------------------------
setup_git_env() {
    # Un scan doit être non interactif de bout en bout : un seul dépôt dont
    # le credential helper a expiré suffirait sinon à bloquer le script sur
    # un prompt, typiquement au pire moment (on s'apprête à partir).
    export GIT_TERMINAL_PROMPT=0
    # BatchMode=yes fait échouer ssh immédiatement au lieu de demander une
    # passphrase. On préfixe la commande existante si l'utilisateur en a
    # défini une, pour ne pas écraser sa configuration.
    export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes"

    # timeout(1) borne les opérations réseau sur remote injoignable
    # (coreutils, présent partout sur Debian/Ubuntu — mais on reste
    # fonctionnel sans lui).
    TIMEOUT_BIN="$(command -v timeout || true)"
}

# run_git_net <dir> <args git…>
# Commande git qui touche le réseau, bornée par --timeout. Sortie standard et
# d'erreur fusionnées. Code de retour de git, ou 124 si timeout(1) a coupé.
run_git_net() {
    local dir="$1"
    shift
    if [[ -n "$TIMEOUT_BIN" ]]; then
        "$TIMEOUT_BIN" "$FETCH_TIMEOUT" git -C "$dir" "$@" 2>&1
    else
        git -C "$dir" "$@" 2>&1
    fi
}

# -----------------------------------------------------------------------------
# Accumulation des résultats
# -----------------------------------------------------------------------------
# R_FLAGS : tous les constats du dépôt (« MODIFS A-POUSSER »), pas seulement
# le plus grave affiché dans R_LABEL. Les filtres et l'éligibilité aux mises
# à jour se décident sur l'ensemble des constats.
declare -a R_PATH=() R_NAME=() R_LABEL=() R_COLOR=() R_DETAIL=() R_FLAGS=() R_SHOWN=()

# État du dépôt en cours d'analyse (globaux : évite de sérialiser un tuple
# de retour à travers stdout, et les fonctions bash ne rendent qu'un entier).
CUR_SEV=0
CUR_LABEL="OK"
CUR_COLOR="$GREEN"
declare -a CUR_NOTES=() CUR_FLAGS=()

# set_status <sévérité> <couleur> <libellé>
# Le libellé affiché est celui du problème le plus grave : une comparaison
# stricte fait que le premier constat d'une sévérité donnée l'emporte, ce
# qui fixe la priorité par l'ordre des tests (force-push avant divergence).
# Chaque constat est en revanche toujours mémorisé dans CUR_FLAGS.
set_status() {
    CUR_FLAGS+=("$3")
    if (( $1 > CUR_SEV )); then
        CUR_SEV="$1"
        CUR_COLOR="$2"
        CUR_LABEL="$3"
    fi
}

# is_visible "<constats séparés par des espaces>"
# --only : au moins un constat dans la liste. --hide : masqué seulement si
# TOUS les constats y sont, pour qu'un dépôt « MODIFS + A-POUSSER » ne
# disparaisse pas parce qu'on a demandé à ignorer les modifications locales.
is_visible() {
    local f any_only="no" all_hidden="yes"
    for f in $1; do
        if [[ "$ONLY_SET" == *" $f "* ]]; then
            any_only="yes"
        fi
        if [[ "$HIDE_SET" != *" $f "* ]]; then
            all_hidden="no"
        fi
    done
    if [[ -n "$ONLY_SET" && "$any_only" == "no" ]]; then
        return 1
    fi
    if [[ -n "$HIDE_SET" && "$all_hidden" == "yes" ]]; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Analyse d'un dépôt
# -----------------------------------------------------------------------------

# Lance le fetch et capture sa sortie dans FETCH_OUT. Retourne le code de
# git (ou 124 si timeout(1) a coupé).
FETCH_OUT=""
run_fetch() {
    local dir="$1" rc=0

    # LC_ALL=C : la sortie du fetch est *parsée* plus bas pour repérer
    # « (forced update) ». Ce message est traduit dans les locales non
    # anglaises, il faut donc forcer l'anglais. L'export a lieu dans la
    # sous-shell de $(…) : il ne fuit pas vers le reste du script.
    FETCH_OUT="$(export LC_ALL=C; run_git_net "$dir" fetch "$REMOTE_NAME")" || rc=$?
    return "$rc"
}

check_repo() {
    local dir="$1"

    CUR_SEV=0
    CUR_LABEL="OK"
    CUR_COLOR="$GREEN"
    CUR_NOTES=()
    CUR_FLAGS=()
    FETCH_OUT=""

    # --- 1. Est-ce un dépôt Git ? -------------------------------------------
    # On teste l'existence de .git, pas seulement sa nature de répertoire :
    # dans un worktree lié ou un submodule, .git est un *fichier* contenant
    # « gitdir: … ».
    if [[ ! -e "$dir/.git" ]]; then
        set_status 1 "$YELLOW" "NON-GIT"
        CUR_NOTES+=("pas un dépôt git")
        return 1
    fi

    # --- 2. Dépôt vide (aucun commit) ---------------------------------------
    if ! git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
        set_status 1 "$YELLOW" "VIDE"
        CUR_NOTES+=("dépôt sans aucun commit")
        return 1
    fi

    # --- 3. Working tree ----------------------------------------------------
    # --porcelain : format stable et non traduit, contrairement à la sortie
    # humaine de git status qui dépend de la locale. Une ligne = un fichier
    # (modifié, indexé, ou non suivi préfixé par '??').
    local dirty
    dirty="$(git -C "$dir" status --porcelain --untracked-files=normal 2>/dev/null | wc -l || true)"
    if (( dirty > 0 )); then
        set_status 1 "$YELLOW" "MODIFS"
        CUR_NOTES+=("$dirty fichier(s) modifié(s)/non suivi(s)")
    fi

    # --- 4. Remote origin ---------------------------------------------------
    # On interroge « origin » nommément plutôt que de filtrer sur un domaine :
    # la forge n'a aucune importance ici.
    if ! git -C "$dir" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
        set_status 1 "$YELLOW" "SANS-REMOTE"
        CUR_NOTES+=("aucun remote « $REMOTE_NAME » configuré")
        return 1
    fi

    # --- 5. Fetch -----------------------------------------------------------
    local rc=0
    if [[ "$DO_FETCH" == "yes" ]]; then
        run_fetch "$dir" || rc=$?
        if (( rc != 0 )); then
            set_status 1 "$YELLOW" "FETCH-KO"
            if (( rc == 124 )); then
                CUR_NOTES+=("fetch échoué (timeout ${FETCH_TIMEOUT}s)")
            else
                CUR_NOTES+=("fetch échoué (réseau ou authentification)")
            fi
            # On continue quand même : les branches de suivi connues
            # restent une information utile, simplement datée.
        fi
    fi

    # --- 6. Branche courante et upstream ------------------------------------
    local branch
    if ! branch="$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null)"; then
        # HEAD détaché : aucune branche à comparer, et c'est rarement un état
        # dans lequel on veut laisser un projet en partant.
        set_status 1 "$YELLOW" "SANS-BRANCHE"
        CUR_NOTES+=("HEAD détaché (aucune branche courante)")
        return 1
    fi

    local upstream
    if ! upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        set_status 1 "$YELLOW" "SANS-UPSTREAM"
        CUR_NOTES+=("branche '$branch' sans upstream (jamais poussée ?)")
        return 1
    fi

    # --- 7. Détection d'une réécriture d'historique -------------------------
    #
    # Piège à éviter : « git merge-base --is-ancestor HEAD @{u} » ne permet
    # PAS de détecter un force-push. Dès qu'on est ahead d'un seul commit,
    # HEAD n'est par construction jamais un ancêtre de l'upstream — le test
    # échoue donc identiquement pour une divergence parfaitement banale.
    # Distinguer les deux cas exige de connaître l'ANCIEN sommet distant.
    #
    # D'où deux signaux complémentaires :
    #
    #   a) La sortie du fetch. Git annonce une mise à jour non fast-forward
    #      par « + <old>...<new> main -> origin/main  (forced update) ».
    #      Preuve directe, mais visible seulement si la réécriture est
    #      survenue pendant CE fetch.
    #
    #   b) Le reflog de la branche de suivi. « origin/main@{1} » est la
    #      valeur précédente de la ref. Si cet ancien sommet n'est plus un
    #      ancêtre du sommet actuel, le distant a été réécrit — y compris
    #      lors d'un fetch antérieur. Nécessite core.logAllRefUpdates (actif
    #      par défaut hors dépôt bare) ; on dégrade silencieusement sinon.
    local rewritten="no" prev_tip
    if [[ "$FETCH_OUT" == *"forced update"* ]]; then
        rewritten="yes"
    elif prev_tip="$(git -C "$dir" rev-parse -q --verify "${upstream}@{1}" 2>/dev/null)"; then
        if ! git -C "$dir" merge-base --is-ancestor "$prev_tip" "$upstream" 2>/dev/null; then
            rewritten="yes"
        fi
    fi

    if [[ "$rewritten" == "yes" ]]; then
        set_status 2 "$RED" "FORCE-PUSH"
        CUR_NOTES+=("HISTORIQUE RÉÉCRIT sur $upstream (force-push probable)")
    fi

    # --- 8. Comparaison ahead / behind --------------------------------------
    # La plage à trois points avec --left-right --count donne en une seule
    # invocation « <commits présents seulement dans HEAD>TAB<seulement dans
    # upstream> », c'est-à-dire exactement ahead puis behind.
    local counts ahead behind
    counts="$(git -C "$dir" rev-list --left-right --count "HEAD...${upstream}" 2>/dev/null || printf '0\t0')"
    ahead="${counts%%[[:space:]]*}"
    behind="${counts##*[[:space:]]}"

    if (( ahead > 0 && behind > 0 )); then
        set_status 2 "$RED" "DIVERGENCE"
        CUR_NOTES+=("divergence : $ahead commit(s) local(aux), $behind distant(s)")
    elif (( ahead > 0 )); then
        set_status 1 "$YELLOW" "A-POUSSER"
        CUR_NOTES+=("$ahead commit(s) non poussé(s) sur $upstream")
    elif (( behind > 0 )); then
        set_status 1 "$YELLOW" "A-RECUPERER"
        CUR_NOTES+=("$behind commit(s) distant(s) non récupéré(s)")
    elif (( CUR_SEV == 0 )); then
        # Rien à signaler. On précise tout de même l'état de référence : sans
        # fetch, un « OK » ne vaut que pour la dernière synchro connue.
        # (Un fetch en échec a déjà porté CUR_SEV à 1, donc on n'arrive ici
        # qu'après un fetch réussi ou en mode --no-fetch.)
        if [[ "$DO_FETCH" == "yes" ]]; then
            CUR_NOTES+=("à jour avec $upstream")
        else
            CUR_NOTES+=("à jour avec $upstream (état local, sans fetch)")
        fi
    fi

    (( CUR_SEV == 0 ))
}

# -----------------------------------------------------------------------------
# Mises à jour proposées
# -----------------------------------------------------------------------------

# apply_action <pull|push> <index>
# Exécute la mise à jour d'un dépôt éligible et, en cas de succès, le passe
# à OK dans les résultats : l'éligibilité exige un constat unique, donc une
# fois ce constat levé il ne reste rien à signaler.
apply_action() {
    local kind="$1" i="$2"
    local dir="${R_PATH[$i]}" name="${R_NAME[$i]}" out rc=0 done_msg

    case "$kind" in
        pull)
            # Aucun commit local (sinon ce serait A-POUSSER ou DIVERGENCE) et
            # arbre propre : le rebase se réduit à une avance rapide, sans
            # risque de conflit ni de commit réécrit.
            out="$(run_git_net "$dir" pull --rebase)" || rc=$?
            done_msg="mis à jour (git pull --rebase)"
            ;;
        push)
            # Push explicite vers l'upstream comparé pendant le scan
            # (branch.<b>.remote / branch.<b>.merge), plutôt qu'un « git push »
            # nu dont la cible dépend de push.default et pourrait ne pas être
            # la branche suivie (nom local différent du nom distant).
            local branch remote merge
            branch="$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || true)"
            remote="$(git -C "$dir" config --get "branch.${branch}.remote" 2>/dev/null || true)"
            merge="$(git -C "$dir" config --get "branch.${branch}.merge" 2>/dev/null || true)"
            if [[ -z "$branch" || -z "$remote" || -z "$merge" ]]; then
                warn "$(pad "$name" "$NAME_WIDTH")  push impossible : upstream introuvable"
                return 0
            fi
            out="$(run_git_net "$dir" push "$remote" "HEAD:${merge}")" || rc=$?
            done_msg="poussé vers $remote/${merge#refs/heads/}"
            ;;
    esac

    if (( rc == 0 )); then
        success "$(pad "$name" "$NAME_WIDTH")  $done_msg"
        R_LABEL[$i]="OK"
        R_COLOR[$i]="$GREEN"
        R_FLAGS[$i]="OK"
        R_DETAIL[$i]="$done_msg"
        return 0
    fi

    if (( rc == 124 )); then
        warn "$(pad "$name" "$NAME_WIDTH")  échec : timeout ${FETCH_TIMEOUT}s (voir --timeout)"
    else
        warn "$(pad "$name" "$NAME_WIDTH")  échec de git $kind :"
    fi
    # Sortie de git indentée sous la ligne du dépôt : c'est elle qui dit
    # pourquoi (rejet non fast-forward, authentification, hook…).
    if [[ -n "$out" ]]; then
        printf '%s\n' "$out" | sed 's/^/                  /'
    fi
    R_DETAIL[$i]="échec de git $kind"
}

# propose_group <pull|push> <index…>
# Liste les dépôts du groupe puis, selon ACTION_MODE, demande confirmation
# globale (o), dépôt par dépôt (i), ou applique directement (--yes).
propose_group() {
    local kind="$1"
    shift
    (( $# > 0 )) || return 0

    local i cmd title answer="" one
    if [[ "$kind" == "pull" ]]; then
        cmd="git pull --rebase"
        title="Uniquement en retard"
    else
        cmd="git push"
        title="Uniquement des commits à pousser"
    fi

    echo ""
    info "${BOLD}$title${RESET} — « $cmd » possible sur $# dépôt(s) :"
    for i in "$@"; do
        echo "                  - ${R_NAME[$i]} : ${R_DETAIL[$i]}"
    done

    case "$ACTION_MODE" in
        yes)
            answer="o"
            ;;
        ask)
            # Sans terminal en entrée (cron, pipe, hook non interactif), pas
            # de question : on indique simplement comment appliquer.
            if [[ ! -t 0 ]]; then
                info "Pas de terminal interactif : relancer avec --yes pour appliquer."
                return 0
            fi
            read -r -p "$(echo -e "${YELLOW}Lancer « $cmd » ?${RESET} [o]ui / [N]on / [i] un par un : ")" answer || answer=""
            ;;
    esac

    case "$answer" in
        [oOyY]*)
            for i in "$@"; do
                apply_action "$kind" "$i"
            done
            ;;
        [iI]*)
            for i in "$@"; do
                read -r -p "$(echo -e "  ${R_NAME[$i]} ? [o/N] ")" one || one=""
                if [[ "$one" =~ ^[oOyY] ]]; then
                    apply_action "$kind" "$i"
                fi
            done
            ;;
        *)
            info "Ignoré."
            ;;
    esac
}

propose_updates() {
    [[ "$ACTION_MODE" != "none" ]] || return 0

    # Éligibilité stricte : le constat doit être SEUL. Un dépôt modifié, en
    # échec de fetch ou réécrit côté distant demande un regard humain, même
    # si l'opération réussirait peut-être techniquement.
    local i
    local -a pulls=() pushes=()
    for i in "${!R_NAME[@]}"; do
        [[ "${R_SHOWN[$i]}" == "yes" ]] || continue
        case "${R_FLAGS[$i]}" in
            A-RECUPERER) pulls+=("$i") ;;
            A-POUSSER)   pushes+=("$i") ;;
        esac
    done

    if (( ${#pulls[@]} + ${#pushes[@]} == 0 )); then
        return 0
    fi

    echo ""
    echo -e "${BOLD}=== MISES À JOUR POSSIBLES ===${RESET}"
    propose_group pull ${pulls[@]+"${pulls[@]}"}
    propose_group push ${pushes[@]+"${pushes[@]}"}
}

# -----------------------------------------------------------------------------
# Affichage
# -----------------------------------------------------------------------------

# Complète une chaîne jusqu'à N colonnes. On n'utilise pas « printf %-Ns » :
# celui-ci compte les octets, ce qui décale les colonnes dès qu'un nom de
# projet contient un accent (UTF-8 = plusieurs octets par caractère), alors
# que ${#s} compte bien les caractères.
pad() {
    local s="$1" w="$2" n
    n=$(( w - ${#s} ))
    if (( n > 0 )); then
        printf '%s%*s' "$s" "$n" ""
    else
        printf '%s' "$s"
    fi
}

# « ${array[*]} » ne joint qu'avec le PREMIER caractère d'IFS ; on assemble
# donc à la main pour obtenir un vrai séparateur « , ».
join_notes() {
    local out="" n
    for n in ${CUR_NOTES[@]+"${CUR_NOTES[@]}"}; do
        if [[ -n "$out" ]]; then
            out+=", "
        fi
        out+="$n"
    done
    printf '%s' "$out"
}

print_live() {
    local name="$1" detail="$2"
    case "$CUR_SEV" in
        0) success  "$(pad "$name" "$NAME_WIDTH")  $detail" ;;
        1) warn     "$(pad "$name" "$NAME_WIDTH")  $detail" ;;
        *) critical "$(pad "$name" "$NAME_WIDTH")  $detail" ;;
    esac
}

print_table() {
    local i sep width=0 shown=0

    # Largeur du filet calée sur la ligne la plus longue, détail compris,
    # mais plafonnée à la largeur du terminal pour éviter qu'il ne s'enroule
    # sur deux lignes (tput échoue hors tty, d'où le repli à 100).
    local term_width
    term_width="$(tput cols 2>/dev/null || echo 100)"
    for i in "${!R_NAME[@]}"; do
        [[ "${R_SHOWN[$i]}" == "yes" ]] || continue
        shown=$(( shown + 1 ))
        if (( ${#R_DETAIL[$i]} > width )); then
            width=${#R_DETAIL[$i]}
        fi
    done
    width=$(( NAME_WIDTH + LABEL_WIDTH + 4 + width ))
    if (( width > term_width )); then
        width=$term_width
    fi
    sep="$(printf '%*s' "$width" '' | tr ' ' '-')"

    echo ""
    echo -e "${BOLD}=== RÉCAPITULATIF ===${RESET}"
    if (( shown == 0 )); then
        info "Aucun dépôt ne correspond aux filtres."
        return 0
    fi
    echo -e "${BOLD}$(pad "PROJET" "$NAME_WIDTH")  $(pad "STATUT" "$LABEL_WIDTH")  DÉTAIL${RESET}"
    echo "$sep"

    for i in "${!R_NAME[@]}"; do
        [[ "${R_SHOWN[$i]}" == "yes" ]] || continue
        echo -e "$(pad "${R_NAME[$i]}" "$NAME_WIDTH")  ${R_COLOR[$i]}$(pad "${R_LABEL[$i]}" "$LABEL_WIDTH")${RESET}  ${R_DETAIL[$i]}"
    done
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    setup_git_env

    # nullglob : sans lui, un répertoire vide ferait boucler une fois sur la
    # chaîne littérale « */ ». Le glob ignore les dossiers cachés, ce qui
    # évite de scanner .cache, .venv & co.
    shopt -s nullglob

    echo -e "\n${BOLD}=== État de synchronisation Git ===${RESET}"
    info "Répertoire : $(cd "$BASE_DIR" && pwd)"
    if [[ "$DO_FETCH" == "no" ]]; then
        warn "Mode hors-ligne (--no-fetch) : état distant potentiellement périmé."
    fi
    if [[ -n "$HIDE_SET" ]]; then
        info "Masqués :${HIDE_SET% }"
    fi
    if [[ -n "$ONLY_SET" ]]; then
        info "Uniquement :${ONLY_SET% }"
    fi
    echo ""

    # Premier passage : uniquement pour connaître la largeur de colonne avant
    # d'afficher quoi que ce soit, sinon les lignes émises au fil de l'eau
    # seraient alignées sur une largeur encore incomplète. Les dépôts masqués
    # comptent aussi : on ne connaît leurs constats qu'après analyse.
    local d name detail flags
    local -a dirs=()
    NAME_WIDTH=6   # largeur mini = longueur de l'en-tête « PROJET »
    for d in "$BASE_DIR"/*/; do
        dirs+=("${d%/}")
        name="$(basename "$d")"
        if (( ${#name} > NAME_WIDTH )); then
            NAME_WIDTH=${#name}
        fi
    done

    if (( ${#dirs[@]} == 0 )); then
        warn "Aucun sous-répertoire à analyser dans '$BASE_DIR'."
        exit 0
    fi

    for d in "${dirs[@]}"; do
        name="$(basename "$d")"

        # « || true » : check_repo rend 1 dès qu'un point d'attention existe,
        # ce qui sous set -e stopperait le scan au premier dépôt à problème.
        check_repo "$d" || true
        detail="$(join_notes)"
        flags="${CUR_FLAGS[*]:-OK}"

        R_PATH+=("$d")
        R_NAME+=("$name")
        R_LABEL+=("$CUR_LABEL")
        R_COLOR+=("$CUR_COLOR")
        R_DETAIL+=("$detail")
        R_FLAGS+=("$flags")

        if is_visible "$flags"; then
            R_SHOWN+=("yes")
            if [[ "$QUIET" == "no" ]]; then
                print_live "$name" "$detail"
            fi
        else
            R_SHOWN+=("no")
        fi
    done

    print_table
    propose_updates

    # Le code de sortie agrège les dépôts affichés, APRÈS les mises à jour
    # acceptées : 0 seulement si aucun ne demande d'action, pour rester
    # utilisable dans un && / || ou un hook. Ce qu'on a choisi de masquer,
    # on a choisi de l'ignorer.
    local i attention=0 shown=0 hidden=0
    for i in "${!R_NAME[@]}"; do
        if [[ "${R_SHOWN[$i]}" != "yes" ]]; then
            hidden=$(( hidden + 1 ))
            continue
        fi
        shown=$(( shown + 1 ))
        if [[ "${R_FLAGS[$i]}" != "OK" ]]; then
            attention=$(( attention + 1 ))
        fi
    done

    echo ""
    if (( hidden > 0 )); then
        info "$hidden dépôt(s) masqué(s) par les filtres."
    fi
    if (( attention == 0 )); then
        success "${BOLD}Tout est synchronisé.${RESET} $shown dépôt(s) affiché(s) sur ${#R_NAME[@]}."
        exit 0
    fi

    warn "${BOLD}$attention point(s) d'attention${RESET} sur $shown dépôt(s) affiché(s)."
    exit 1
}

main "$@"
