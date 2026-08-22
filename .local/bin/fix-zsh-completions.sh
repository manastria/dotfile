#!/usr/bin/env bash
# NAME
#     fix-zsh-completions.sh — répare les fichiers de complétion zsh cassés
#     (liens symboliques morts, liens vers un montage volatile)
#
# SYNOPSIS
#     fix-zsh-completions.sh [-n] [-y] [--no-freeze] [DIR]... [-h]
#
# DESCRIPTION
#     Au démarrage, compinit lit chaque fichier des répertoires de $fpath.
#     Un lien symbolique mort y provoque une erreur bruyante à chaque
#     ouverture de shell :
#
#         compinit:527: no such file or directory: /usr/share/zsh/vendor-completions/_docker
#
#     Le cas typique est WSL : Docker Desktop installe ses complétions sous
#     forme de liens vers /mnt/wsl/docker-desktop/, un point de montage qui
#     n'existe que lorsque Docker Desktop tourne côté Windows. Dès qu'il est
#     arrêté, le lien pointe dans le vide et compinit proteste.
#
#     Le script inspecte les répertoires de complétion et traite deux cas :
#
#     1. Lien mort — la cible est introuvable. Le lien est supprimé : il ne
#        sert à rien et casse compinit.
#     2. Lien vers un montage volatile (/mnt, /media, /run/media) dont la
#        cible est LISIBLE. Le lien est remplacé par une copie réelle du
#        fichier (« gel »). La complétion continue alors de fonctionner
#        montage démonté, ce qui empêche le problème de revenir. C'est le
#        comportement par défaut, désactivable avec --no-freeze.
#
#     Une copie gelée est un instantané : elle ne suit plus les mises à jour
#     de l'outil. Relancer le script après une mise à jour majeure de Docker
#     Desktop (montage présent) rafraîchit l'instantané.
#
#     Les répertoires système sont modifiés via sudo, les répertoires de
#     l'utilisateur directement. Ne jamais lancer ce script avec sudo : les
#     copies faites dans $HOME appartiendraient alors à root.
#
# OPTIONS
#     DIR                Répertoire de complétion supplémentaire à inspecter,
#                        répétable. S'ajoute aux répertoires par défaut :
#                        /usr/share/zsh/vendor-completions,
#                        /usr/share/zsh/site-functions,
#                        /usr/local/share/zsh/site-functions,
#                        ~/.zsh/completions.
#     -n, --dry-run      Montre ce qui serait fait, sans rien modifier.
#     -y, --yes          Ne pose aucune question (mode non interactif).
#     --no-freeze        N'effectue que la suppression des liens morts ;
#                        laisse intacts les liens vers un montage volatile.
#     -h, --help         Affiche cette aide.
#
# EXAMPLES
#     # Diagnostic sans rien changer
#     fix-zsh-completions.sh --dry-run
#
#     # Docker Desktop arrêté : supprime le lien mort _docker
#     fix-zsh-completions.sh
#
#     # Docker Desktop démarré : fige les complétions pour qu'elles
#     # survivent à son arrêt (correctif durable)
#     fix-zsh-completions.sh -y
#
#     # Inspecter en plus un répertoire ajouté à fpath par un plugin
#     fix-zsh-completions.sh ~/.zsh/custom/plugins/zsh-completions/src
#
# EXIT CODES
#     0   Rien à faire, ou réparations effectuées.
#     1   Erreur d'exécution (copie ou suppression impossible).
#     2   Erreur d'usage : option inconnue, répertoire introuvable.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
# Répertoires inspectés par défaut : ceux que les paquets Debian/Ubuntu et les
# installeurs tiers ajoutent à $fpath. Les inexistants sont ignorés en silence.
readonly DEFAULT_DIRS=(
    /usr/share/zsh/vendor-completions
    /usr/share/zsh/site-functions
    /usr/local/share/zsh/site-functions
    "$HOME/.zsh/completions"
)

# Préfixes considérés comme volatiles : sous WSL comme sur un poste de bureau,
# ces arborescences apparaissent et disparaissent au gré des montages.
readonly VOLATILE_PREFIXES=(/mnt/ /media/ /run/media/)

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
    # Réimprime le bloc d'en-tête manpage (lignes de commentaire suivant le
    # shebang) en retirant le préfixe « # » : l'aide reste juste même si
    # l'en-tête évolue.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
DRY_RUN="no"
ASSUME_YES="no"
FREEZE="yes"
EXTRA_DIRS=()

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run) DRY_RUN="yes"; shift ;;
            -y|--yes)     ASSUME_YES="yes"; shift ;;
            --no-freeze)  FREEZE="no"; shift ;;
            -h|--help)    usage; exit 0 ;;
            -*)           usage_error "Option inconnue : $1" ;;
            *)            [[ -d "$1" ]] || usage_error "Répertoire introuvable : $1"
                          EXTRA_DIRS+=("$1"); shift ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
# Tier 3 partiel : le script écrit potentiellement dans ~/.zsh/completions.
# Lancé en root, il y créerait des fichiers appartenant à root, invisibles
# au prochain « rm » de l'utilisateur.
check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        error "Ce script ne doit pas être lancé en root."
        error "Relancez sans sudo : les répertoires système seront élevés au cas par cas."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Inspection
# -----------------------------------------------------------------------------
DEAD_LINKS=()      # liens dont la cible est introuvable
VOLATILE_LINKS=()  # liens lisibles mais pointant vers un montage volatile

is_volatile() {
    local target="$1" prefix
    for prefix in "${VOLATILE_PREFIXES[@]}"; do
        [[ "$target" == "$prefix"* ]] && return 0
    done
    return 1
}

scan() {
    local dirs=() dir link target
    dirs=("${DEFAULT_DIRS[@]}" ${EXTRA_DIRS[@]+"${EXTRA_DIRS[@]}"})

    for dir in "${dirs[@]}"; do
        [ -d "$dir" ] || continue
        # -maxdepth 1 : compinit ne descend pas dans les sous-répertoires de
        # $fpath, inutile de les inspecter.
        while IFS= read -r -d '' link; do
            target="$(readlink -f "$link" || true)"
            if [ ! -e "$link" ]; then
                # -e suit le lien : faux ici signifie cible absente.
                DEAD_LINKS+=("$link")
            elif [ -n "$target" ] && is_volatile "$target"; then
                VOLATILE_LINKS+=("$link")
            fi
        done < <(find "$dir" -maxdepth 1 -type l -print0 2>/dev/null)
    done
}

# -----------------------------------------------------------------------------
# Réparation
# -----------------------------------------------------------------------------
# Élève la commande uniquement si le répertoire conteneur n'est pas accessible
# en écriture : pas de sudo inutile sur les fichiers de l'utilisateur.
run_privileged() {
    local dir="$1"; shift
    if [ -w "$dir" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

confirm() {
    local prompt="$1" answer
    [ "$ASSUME_YES" = "yes" ] && return 0
    read -r -p "$(echo -e "${YELLOW}${prompt}${RESET} [o/N] ")" answer
    [[ "$answer" =~ ^[oOyY]$ ]]
}

remove_dead_links() {
    local link dir target
    for link in "${DEAD_LINKS[@]}"; do
        dir="$(dirname "$link")"
        target="$(readlink "$link")"
        warn "Lien mort : ${BOLD}${link}${RESET} → ${target}"
        if [ "$DRY_RUN" = "yes" ]; then
            info "  (simulation) suppression du lien"
            continue
        fi
        if confirm "  Supprimer ce lien ?"; then
            run_privileged "$dir" rm -f "$link" || die "Suppression impossible : $link"
            success "  Supprimé."
            if is_volatile "$target"; then
                info "  La cible est sur un montage volatile. Relancez ce script"
                info "  montage présent pour figer une copie réutilisable."
            fi
        else
            info "  Conservé — l'erreur compinit persistera."
        fi
    done
}

freeze_volatile_links() {
    local link dir target snapshot
    for link in "${VOLATILE_LINKS[@]}"; do
        dir="$(dirname "$link")"
        target="$(readlink -f "$link")"
        info "Lien vers un montage volatile : ${BOLD}${link}${RESET} → ${target}"
        if [ "$DRY_RUN" = "yes" ]; then
            info "  (simulation) remplacement par une copie réelle"
            continue
        fi
        if confirm "  Le remplacer par une copie réelle ?"; then
            # Copie d'abord dans un temporaire : si le montage disparaît en
            # cours de route, le lien d'origine reste en place.
            snapshot="${TMP_DIR}/$(basename "$link")"
            cp -- "$target" "$snapshot" || die "Lecture impossible : $target"
            run_privileged "$dir" rm -f "$link" || die "Suppression impossible : $link"
            run_privileged "$dir" install -m 0644 "$snapshot" "$link" \
                || die "Copie impossible vers : $link"
            success "  Copie figée en place."
        else
            info "  Conservé — l'erreur reviendra une fois le montage absent."
        fi
    done
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_not_root

    echo -e "\n${BOLD}=== Réparation des complétions zsh ===${RESET}\n"

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Inspection des répertoires de complétion..."
    scan

    if [ "${#DEAD_LINKS[@]}" -eq 0 ] && \
       { [ "$FREEZE" = "no" ] || [ "${#VOLATILE_LINKS[@]}" -eq 0 ]; }; then
        success "Aucun lien de complétion à réparer."
        return 0
    fi

    [ "${#DEAD_LINKS[@]}" -gt 0 ] && remove_dead_links
    if [ "$FREEZE" = "yes" ] && [ "${#VOLATILE_LINKS[@]}" -gt 0 ]; then
        freeze_volatile_links
    fi

    if [ "$DRY_RUN" = "yes" ]; then
        info "Simulation terminée — aucun fichier modifié."
    else
        info "Rechargez un shell pour vérifier : ${BOLD}exec zsh${RESET}"
        info "Si l'erreur persiste, videz le cache de compinit : rm -f ~/.zcompdump*"
    fi
}

main "$@"
