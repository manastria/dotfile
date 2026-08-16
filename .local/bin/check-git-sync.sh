#!/usr/bin/env bash
# NAME
#     check-git-sync.sh — état de synchronisation des dépôts Git d'un répertoire
#
# SYNOPSIS
#     check-git-sync.sh [-d DIR] [-n] [-t SEC] [-q] [-h]
#     check-git-sync.sh [DIR]
#
# DESCRIPTION
#     Passe en revue chaque sous-dossier de DIR (premier niveau uniquement,
#     pas de récursion) et rapporte l'état de chaque dépôt Git vis-à-vis de
#     son remote « origin », quelle que soit la forge (GitHub, GitLab,
#     Codeberg, self-hosted…). Pensé comme un état des lieux avant de
#     quitter la machine : rien de non commité, rien de non poussé, rien de
#     bizarre côté distant. Le script ne modifie jamais l'historique local :
#     la seule commande écrivante est « git fetch », qui met uniquement à
#     jour les branches de suivi (refs/remotes/*).
#
# OPTIONS
#     -d, --dir DIR      Répertoire à scanner (défaut : répertoire courant).
#                        DIR accepté aussi en argument positionnel.
#     -n, --no-fetch     Ne contacte aucun remote. Le rapport se base alors
#                        sur les dernières branches de suivi connues :
#                        beaucoup plus rapide, mais possiblement périmé.
#     -t, --timeout SEC  Délai maximum par « git fetch » (défaut : 20).
#                        Évite qu'un remote injoignable bloque tout le scan.
#     -q, --quiet        N'affiche que le tableau final, sans le détail
#                        déroulant dépôt par dépôt.
#     -h, --help         Affiche cette aide.
#
# EXAMPLES
#     # État des lieux du répertoire de projets courant
#     cd ~/projets && check-git-sync.sh
#
#     # Scanner un répertoire précis, sans accès réseau (avion, hors-ligne)
#     check-git-sync.sh --no-fetch ~/projets
#
#     # Utilisable dans un hook de fin de session : ne rend la main
#     # proprement que si tout est synchronisé
#     check-git-sync.sh -q ~/projets || echo "Des projets demandent attention"
#
# EXIT CODES
#     0   Tous les dépôts sont propres et synchronisés.
#     1   Au moins un point d'attention (non commité, non poussé, en retard,
#         divergence, force-push, fetch en échec, dossier non-git…).
#     2   Erreur d'usage : option inconnue ou répertoire introuvable.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly REMOTE_NAME="origin"
readonly DEFAULT_TIMEOUT=20
readonly LABEL_WIDTH=13

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
# lors d'une redirection « check-git-sync.sh > rapport.txt ».
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

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)      BASE_DIR="${2:-}"; shift 2 ;;
            -t|--timeout)  FETCH_TIMEOUT="${2:-}"; shift 2 ;;
            -n|--no-fetch) DO_FETCH="no"; shift ;;
            -q|--quiet)    QUIET="yes"; shift ;;
            -h|--help)     usage; exit 0 ;;
            -*)            usage_error "Option inconnue : $1" ;;
            *)             BASE_DIR="$1"; shift ;;
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

    # timeout(1) borne les fetch sur remote injoignable (coreutils, présent
    # partout sur Debian/Ubuntu — mais on reste fonctionnel sans lui).
    TIMEOUT_BIN="$(command -v timeout || true)"
}

# -----------------------------------------------------------------------------
# Accumulation des résultats
# -----------------------------------------------------------------------------
declare -a R_NAME=() R_LABEL=() R_COLOR=() R_DETAIL=()

# État du dépôt en cours d'analyse (globaux : évite de sérialiser un tuple
# de retour à travers stdout, et les fonctions bash ne rendent qu'un entier).
CUR_SEV=0
CUR_LABEL="OK"
CUR_COLOR="$GREEN"
declare -a CUR_NOTES=()

# set_status <sévérité> <couleur> <libellé>
# Le libellé affiché est celui du problème le plus grave : une comparaison
# stricte fait que le premier constat d'une sévérité donnée l'emporte, ce
# qui fixe la priorité par l'ordre des tests (force-push avant divergence).
set_status() {
    if (( $1 > CUR_SEV )); then
        CUR_SEV="$1"
        CUR_COLOR="$2"
        CUR_LABEL="$3"
    fi
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
    # anglaises, il faut donc forcer l'anglais.
    if [[ -n "$TIMEOUT_BIN" ]]; then
        FETCH_OUT="$(LC_ALL=C "$TIMEOUT_BIN" "$FETCH_TIMEOUT" \
            git -C "$dir" fetch "$REMOTE_NAME" 2>&1)" || rc=$?
    else
        FETCH_OUT="$(LC_ALL=C git -C "$dir" fetch "$REMOTE_NAME" 2>&1)" || rc=$?
    fi
    return "$rc"
}

check_repo() {
    local dir="$1"

    CUR_SEV=0
    CUR_LABEL="OK"
    CUR_COLOR="$GREEN"
    CUR_NOTES=()
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
    local i sep width=0

    # Largeur du filet calée sur la ligne la plus longue, détail compris,
    # mais plafonnée à la largeur du terminal pour éviter qu'il ne s'enroule
    # sur deux lignes (tput échoue hors tty, d'où le repli à 100).
    local term_width
    term_width="$(tput cols 2>/dev/null || echo 100)"
    for i in "${!R_NAME[@]}"; do
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
    echo -e "${BOLD}$(pad "PROJET" "$NAME_WIDTH")  $(pad "STATUT" "$LABEL_WIDTH")  DÉTAIL${RESET}"
    echo "$sep"

    for i in "${!R_NAME[@]}"; do
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
    echo ""

    # Premier passage : uniquement pour connaître la largeur de colonne avant
    # d'afficher quoi que ce soit, sinon les lignes émises au fil de l'eau
    # seraient alignées sur une largeur encore incomplète.
    local d name detail
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

        R_NAME+=("$name")
        R_LABEL+=("$CUR_LABEL")
        R_COLOR+=("$CUR_COLOR")
        R_DETAIL+=("$detail")

        if [[ "$QUIET" == "no" ]]; then
            print_live "$name" "$detail"
        fi
    done

    print_table

    # Le code de sortie agrège tous les dépôts : 0 seulement si aucun ne
    # demande d'action, pour rester utilisable dans un && / || ou un hook.
    local i attention=0
    for i in "${!R_LABEL[@]}"; do
        if [[ "${R_LABEL[$i]}" != "OK" ]]; then
            attention=$(( attention + 1 ))
        fi
    done

    echo ""
    if (( attention == 0 )); then
        success "${BOLD}Tout est synchronisé.${RESET} ${#R_NAME[@]} dépôt(s) vérifié(s)."
        exit 0
    fi

    warn "${BOLD}$attention point(s) d'attention${RESET} sur ${#R_NAME[@]} dépôt(s)."
    exit 1
}

main "$@"
