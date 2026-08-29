#!/usr/bin/env bash
# NAME
#     backup-projets.sh — sauvegarde miroir des projets vers une clé USB
#
# SYNOPSIS
#     backup-projets.sh [-c FICHIER] [-d DIR] [-o MOTIF] [-a] [-k N]
#                       [-n] [-G] [-L] [-q] [-h]
#     backup-projets.sh --init POINT_DE_MONTAGE
#
# DESCRIPTION
#     Recopie sur une clé USB la liste de projets décrite dans un fichier de
#     configuration, en miroir incrémental : seuls les fichiers modifiés
#     depuis la sauvegarde précédente sont transférés. Pensé comme le dernier
#     geste avant d'éteindre la machine — si un commit n'a pas été poussé, ou
#     pas même commité, le travail est malgré tout sur la clé.
#
#     Le miroir conserve les répertoires .git (chaque projet reste clonable
#     depuis la clé) et écarte les artefacts d'environnement de développement
#     (node_modules, .venv, target, vendor…), comme le fait pack-project.sh.
#     À la différence de celui-ci, le résultat n'est pas une archive mais une
#     copie directement ouvrable : sur le poste de la classe, les fichiers se
#     lisent sans rien décompresser.
#
#     Chaque projet est en outre inspecté côté Git — sans aucun accès réseau —
#     pour signaler ce qui n'a pas été publié. Cette information est
#     consultative : un projet non poussé est sauvegardé normalement, c'est
#     précisément la raison d'être du script.
#
#     La clé de destination est reconnue à un fichier marqueur déposé à sa
#     racine (voir --init), ce qui la rend indépendante de la lettre de
#     lecteur attribuée par Windows et interdit d'écrire sur le mauvais
#     disque. L'option -d force une destination quelconque.
#
#     Le script refuse d'écrire sur le système de fichiers racine. Sous WSL,
#     un lecteur branché après le démarrage n'est pas monté automatiquement
#     et /mnt/<lettre> n'est alors qu'un répertoire vide du disque virtuel :
#     la sauvegarde s'y déverserait sans que rien n'apparaisse sur la clé.
#     Le cas est détecté et la commande de montage est proposée. L'option
#     --allow-local lève ce garde-fou, pour un essai vers un répertoire local.
#
#     Le support doit également accepter que l'on fixe la date des fichiers,
#     sans quoi rsync ne peut plus distinguer ce qui a changé et recopie tout
#     à chaque passe. Un montage drvfs sans « uid= » produit exactement cet
#     effet : les fichiers appartiennent à root et leur date est verrouillée.
#     Le script sonde le support et propose la commande de remontage.
#
#     L'option -a ajoute, en plus du miroir, une archive .tar.zst horodatée
#     par projet — un instantané figé, auquel se raccrocher si un fichier est
#     abîmé côté source et que le miroir a déjà répercuté les dégâts.
#
# CONFIGURATION
#     Fichier ~/.config/backup-projets/projets.conf (voir -c), une entrée par
#     ligne, « # » pour les commentaires :
#
#         ~/projets/*                      un glob : tous les projets
#         /mnt/f/_Obsidian/gclasse         un chemin précis
#         /mnt/f/_Obsidian/quatro|quatro-win   nom explicite sur la clé
#         !~/projets/gclasse-quartz        exclusion (motif glob)
#
#     Le nom du répertoire sur la clé est le nom de base du projet, sauf
#     mention après une barre verticale. Les exclusions « ! » s'appliquent
#     aux chemins résolus, quel que soit leur ordre dans le fichier.
#
# OPTIONS
#     -c, --config FICHIER  Liste des projets (défaut :
#                           ~/.config/backup-projets/projets.conf).
#     -d, --dest DIR        Destination explicite, court-circuite la
#                           détection par marqueur.
#     -o, --only MOTIF      Ne traiter que les projets dont le nom sur la clé
#                           correspond au motif glob (répétable).
#     -a, --archive         Créer aussi une archive .tar.zst par projet.
#     -k, --keep N          Nombre d'archives conservées par projet
#                           (défaut : 3). Sans effet sans -a.
#     -n, --dry-run         Simulation : affiche ce qui serait transféré,
#                           n'écrit rien sur la clé.
#     -G, --no-git          Ne pas inspecter l'état Git des projets (plus
#                           rapide sur les gros dépôts montés en 9p).
#     -L, --deref           Remplacer les liens symboliques par leur cible.
#                           Détecté automatiquement si la clé ne sait pas
#                           stocker de lien.
#     -q, --quiet           N'afficher que le récapitulatif final.
#         --allow-local     Autoriser une destination sur le système de
#                           fichiers racine (essai local, pas un support).
#         --no-times        Accepter un support qui refuse de dater les
#                           fichiers. La comparaison se fait alors sur la
#                           taille seule : une modification qui ne change
#                           pas la taille passe inaperçue. À éviter.
#         --init DIR        Déposer le fichier marqueur sur DIR et quitter.
#     -h, --help            Affiche cette aide.
#
# EXAMPLES
#     # Préparation, une seule fois, de la clé montée sur /mnt/e
#     backup-projets.sh --init /mnt/e
#
#     # Sauvegarde du soir : la clé est retrouvée toute seule
#     backup-projets.sh
#
#     # Vérifier ce qui partirait, sans rien écrire
#     backup-projets.sh --dry-run
#
#     # Sauvegarde avec instantané figé, 5 archives conservées par projet
#     backup-projets.sh --archive --keep 5
#
#     # Un seul projet, vers un disque externe
#     backup-projets.sh --only gclasse --dest /mnt/g/sauvegardes
#
#     # Enchaînement avec l'état de synchronisation des dépôts
#     backup-projets.sh && check-git-sync.sh ~/projets
#
# EXIT CODES
#     0   Tous les projets ont été sauvegardés.
#     1   Sauvegarde non garantie : au moins un projet en échec, ou un
#         prérequis manquant (rsync absent, support non inscriptible).
#         L'état Git n'entre pas dans ce calcul : un projet non publié est
#         une sauvegarde réussie.
#     2   Erreur d'usage : option inconnue, configuration illisible ou vide,
#         support de destination introuvable, ambigu, ou non monté.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly DEFAULT_CONF="${HOME}/.config/backup-projets/projets.conf"
readonly MARKER=".backup-projets"
readonly BACKUP_DIRNAME="backup-projets"
readonly MIRROR_DIRNAME="miroir"
readonly ARCHIVE_DIRNAME="archives"
readonly REPORT_NAME="DERNIERE-SAUVEGARDE.txt"
readonly DEFAULT_KEEP=3
readonly ZSTD_LEVEL="${PACK_ZSTD_LEVEL:-3}"
readonly STATE_WIDTH=9
# Espace libre en dessous duquel on prévient (2 Gio), sans bloquer : le
# volume réellement nécessaire dépend du différentiel, inconnu avant rsync.
readonly LOW_SPACE_BYTES=$(( 2 * 1024 * 1024 * 1024 ))

# Artefacts d'environnement de développement, jamais recopiés. Liste alignée
# sur pack-project.sh : un motif sans « / » désigne le nom de base, à
# n'importe quelle profondeur, aussi bien pour rsync que pour tar.
readonly -a DEV_EXCLUDES=(
    # Python
    ".venv" "venv" "env" ".env" "__pycache__" ".mypy_cache"
    ".pytest_cache" "*.pyc" "*.pyo" ".tox" "dist" "build" "*.egg-info" ".ruff_cache"
    # Node.js
    "node_modules" ".npm" ".yarn" ".pnp"
    # Java / Kotlin / Scala
    "target" ".gradle" "*.class" "*.jar" "*.war"
    # Go / PHP / Composer
    "vendor"
    # Divers
    ".DS_Store" "Thumbs.db"
)

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

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
CONF="${BACKUP_PROJETS_CONF:-$DEFAULT_CONF}"
DEST_ROOT="${BACKUP_PROJETS_DEST:-}"
DO_ARCHIVE="no"
KEEP="$DEFAULT_KEEP"
DRY_RUN="no"
DO_GIT="yes"
DEREF="auto"
QUIET="no"
ALLOW_LOCAL="no"
NO_TIMES="no"
INIT_DIR=""
declare -a ONLY_PATTERNS=()

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)  CONF="${2:-}"; shift 2 ;;
            -d|--dest)    DEST_ROOT="${2:-}"; shift 2 ;;
            -o|--only)    ONLY_PATTERNS+=("${2:-}"); shift 2 ;;
            -k|--keep)    KEEP="${2:-}"; shift 2 ;;
            -a|--archive) DO_ARCHIVE="yes"; shift ;;
            -n|--dry-run) DRY_RUN="yes"; shift ;;
            -G|--no-git)  DO_GIT="no"; shift ;;
            -L|--deref)   DEREF="yes"; shift ;;
            -q|--quiet)   QUIET="yes"; shift ;;
            --allow-local) ALLOW_LOCAL="yes"; shift ;;
            --no-times)   NO_TIMES="yes"; shift ;;
            --init)       INIT_DIR="${2:-}"; shift 2 ;;
            -h|--help)    usage; exit 0 ;;
            *)            usage_error "Option inconnue : $1" ;;
        esac
    done

    [[ "$KEEP" =~ ^[0-9]+$ ]] || usage_error "--keep attend un entier."
    (( KEEP >= 1 )) || usage_error "--keep attend au moins 1."
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------

# Tier 3 : le script écrit dans le home de l'utilisateur (fichier journal
# temporaire) et sur une clé montée pour lui. En root, les fichiers du miroir
# appartiendraient à root, et une clé montée par l'utilisateur ne serait même
# pas visible dans l'environnement de sudo.
check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
        echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
        exit 1
    fi
}

check_deps() {
    command -v rsync   >/dev/null 2>&1 || die "rsync est requis (apt install rsync)."
    command -v numfmt  >/dev/null 2>&1 || die "numfmt est requis (paquet coreutils)."
    if [[ "$DO_GIT" == "yes" ]] && ! command -v git >/dev/null 2>&1; then
        warn "git absent : l'état de publication ne sera pas rapporté."
        DO_GIT="no"
    fi
    if [[ "$DO_ARCHIVE" == "yes" ]]; then
        command -v tar  >/dev/null 2>&1 || die "tar est requis pour --archive."
        command -v zstd >/dev/null 2>&1 || die "zstd est requis pour --archive (apt install zstd)."
    fi
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
declare -a SPEC_PATH=() SPEC_LABEL=() EXCLUDE_PATTERNS=()

# Développe un « ~ » de tête. Volontairement limité à ce seul cas : évaluer
# la ligne (eval, guillemets) exposerait le fichier de configuration à une
# exécution de commande, pour un confort d'écriture marginal.
expand_tilde() {
    local p="$1"
    case "$p" in
        "~")   printf '%s' "$HOME" ;;
        "~/"*) printf '%s' "${HOME}/${p#\~/}" ;;
        *)     printf '%s' "$p" ;;
    esac
}

trim() {
    local s="$1"
    s="${s%$'\r'}"                          # fichier édité sous Windows
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

load_config() {
    [[ -f "$CONF" ]] || {
        error "Fichier de configuration introuvable : $CONF"
        echo "Créez-le à partir de ~/.config/backup-projets/projets.conf.sample" >&2
        exit 2
    }

    local line path label
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "$line")"
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == '!'* ]]; then
            EXCLUDE_PATTERNS+=("$(expand_tilde "$(trim "${line#!}")")")
            continue
        fi

        # La barre verticale sépare le chemin de son nom sur la clé. Ce
        # séparateur plutôt qu'une espace : les chemins Windows en
        # contiennent régulièrement (« Atomic Thinking - Obsidian Expert »).
        if [[ "$line" == *'|'* ]]; then
            label="$(trim "${line##*|}")"
            path="$(trim "${line%|*}")"
        else
            label=""
            path="$line"
        fi

        SPEC_PATH+=("$(expand_tilde "$path")")
        SPEC_LABEL+=("$label")
    done < "$CONF"

    (( ${#SPEC_PATH[@]} > 0 )) || usage_error "Aucun projet listé dans $CONF"
}

# -----------------------------------------------------------------------------
# Résolution de la liste des projets
# -----------------------------------------------------------------------------
declare -a PROJ_PATH=() PROJ_LABEL=()

is_excluded() {
    local path="$1" pattern
    for pattern in ${EXCLUDE_PATTERNS[@]+"${EXCLUDE_PATTERNS[@]}"}; do
        # Motif non quoté à droite de == : c'est ce qui active la
        # correspondance glob plutôt qu'une égalité littérale.
        [[ "$path" == $pattern ]] && return 0
    done
    return 1
}

matches_only() {
    local label="$1" pattern
    (( ${#ONLY_PATTERNS[@]} == 0 )) && return 0
    for pattern in "${ONLY_PATTERNS[@]}"; do
        [[ "$label" == $pattern ]] && return 0
    done
    return 1
}

# Ajoute un projet, en réglant deux collisions que la configuration rend
# inévitables :
#   - le même chemin listé deux fois (nommément ET pris par un glob) : une
#     seule entrée, et c'est le nom explicite qui l'emporte ;
#   - deux chemins différents de même nom de base — « gclasse » existe aussi
#     bien dans ~/projets que sur /mnt/f — auquel cas le second écraserait le
#     miroir du premier s'il n'était pas désambiguïsé.
add_project() {
    local path="$1" label="$2" explicit="no" i

    if [[ -n "$label" ]]; then
        explicit="yes"
    else
        label="$(basename "$path")"
    fi

    for i in ${PROJ_PATH[@]+"${!PROJ_PATH[@]}"}; do
        if [[ "${PROJ_PATH[$i]}" == "$path" ]]; then
            # Déjà connu : on ne garde que le nom explicite s'il en arrive un.
            [[ "$explicit" == "yes" ]] && PROJ_LABEL[$i]="$label"
            return 0
        fi
    done

    for i in ${PROJ_LABEL[@]+"${!PROJ_LABEL[@]}"}; do
        if [[ "${PROJ_LABEL[$i]}" == "$label" ]]; then
            local parent
            parent="$(basename "$(dirname "$path")")"
            warn "Nom « $label » déjà pris par ${PROJ_PATH[$i]} — celui-ci devient « ${parent}-${label} »."
            label="${parent}-${label}"
            break
        fi
    done

    PROJ_PATH+=("$path")
    PROJ_LABEL+=("$label")
}

# Deux passes : les chemins nommés d'abord, les globs ensuite. Ainsi une
# ligne « /mnt/f/_Obsidian/quatro|quatro-win » impose son nom même si un glob
# plus haut dans le fichier ramène déjà ce répertoire.
resolve_projects() {
    local pass i spec label path
    local -a matches

    shopt -s nullglob
    for pass in explicite glob; do
    for i in "${!SPEC_PATH[@]}"; do
        spec="${SPEC_PATH[$i]}"
        label="${SPEC_LABEL[$i]}"

        if [[ "$spec" == *[*?[]* ]]; then
            [[ "$pass" == "glob" ]] || continue
            # IFS vide : la substitution ne subit plus de découpage en mots,
            # mais la développement de nom de chemin s'applique toujours et
            # produit un élément par correspondance. C'est ce qui permet à un
            # glob de rendre des chemins contenant des espaces.
            local IFS=
            matches=( $spec )
            unset IFS

            (( ${#matches[@]} > 0 )) || { warn "Aucune correspondance pour « $spec »."; continue; }
            for path in "${matches[@]}"; do
                [[ -d "$path" ]] || continue
                is_excluded "$path" && continue
                add_project "$path" ""      # un glob ne peut pas nommer
            done
        else
            [[ "$pass" == "explicite" ]] || continue
            is_excluded "$spec" && continue
            add_project "$spec" "$label"
        fi
    done
    done
    shopt -u nullglob

    # Filtrage --only après résolution, pour que le motif porte sur le nom
    # tel qu'il apparaîtra sur la clé.
    if (( ${#ONLY_PATTERNS[@]} > 0 )); then
        local -a kp=() kl=()
        for i in "${!PROJ_LABEL[@]}"; do
            if matches_only "${PROJ_LABEL[$i]}"; then
                kp+=("${PROJ_PATH[$i]}")
                kl+=("${PROJ_LABEL[$i]}")
            fi
        done
        PROJ_PATH=( ${kp[@]+"${kp[@]}"} )
        PROJ_LABEL=( ${kl[@]+"${kl[@]}"} )
    fi

    (( ${#PROJ_PATH[@]} > 0 )) || usage_error "Aucun projet à sauvegarder après résolution de $CONF"
}

# -----------------------------------------------------------------------------
# Destination
# -----------------------------------------------------------------------------

# Cherche le marqueur sur les points de montage plausibles. Chaque test est
# borné par timeout : sous WSL, /mnt/ contient les lecteurs réseau Windows,
# dont un seul déconnecté suffirait à figer le script.
detect_dest() {
    local cand
    local -a found=()

    shopt -s nullglob
    for cand in /media/"$USER"/* /run/media/"$USER"/* /media/* /mnt/*; do
        [[ -d "$cand" ]] || continue
        case "$cand" in
            /mnt/wsl|/mnt/wslg) continue ;;
        esac
        # Un marqueur déposé par erreur dans le disque de WSL ne doit jamais
        # faire élire cette destination : elle n'est pas un support.
        [[ "$ALLOW_LOCAL" == "no" ]] && is_on_root_fs "$cand" && continue
        if timeout 3 test -e "${cand}/${MARKER}" 2>/dev/null; then
            found+=("$cand")
        fi
    done
    shopt -u nullglob

    case "${#found[@]}" in
        0) return 1 ;;
        1) printf '%s' "${found[0]}"; return 0 ;;
        *)
            error "Plusieurs supports portent le marqueur ${MARKER} :"
            printf '  %s\n' "${found[@]}" >&2
            echo "Désignez celui à utiliser avec --dest." >&2
            exit 2
            ;;
    esac
}

# Le système de fichiers qui porte réellement un répertoire. « / » signale
# que le chemin n'est adossé à aucun montage propre : sous WSL, c'est la
# signature d'un /mnt/<lettre> laissé vide par un montage précédent, et donc
# d'une sauvegarde qui partirait dans le disque virtuel au lieu de la clé.
mount_point_of() { stat -c %m "$1" 2>/dev/null; }

is_on_root_fs() { [[ "$(mount_point_of "$1")" == "/" ]]; }

# Refus commenté, avec la commande de montage quand le chemin ressemble à une
# lettre de lecteur Windows : c'est l'unique manœuvre à connaître, et elle
# n'est pas devinable au moment où l'on est pressé de partir.
reject_local_dest() {
    local dir="$1"
    error "« ${dir} » n'est pas un support monté : ce chemin appartient au système de fichiers racine."
    echo "Y écrire remplirait le disque de WSL sans rien déposer sur la clé." >&2
    if [[ "$dir" =~ ^(/mnt/([a-z]))(/|$) ]]; then
        local mnt="${BASH_REMATCH[1]}" letter="${BASH_REMATCH[2]}"
        echo "" >&2
        echo "Sous WSL, un lecteur branché après le démarrage n'est pas monté tout seul." >&2
        echo "Montez-le, puis relancez :" >&2
        echo "    sudo mount -t drvfs ${letter^^}: ${mnt}" >&2
    fi
    echo "" >&2
    echo "Pour une destination locale assumée (essai, disque interne), ajoutez --allow-local." >&2
    exit 2
}

check_real_medium() {
    local dir="$1"
    [[ "$ALLOW_LOCAL" == "yes" ]] && return 0
    is_on_root_fs "$dir" && reject_local_dest "$dir"
    return 0
}

init_dest() {
    local dir="$1"
    [[ -d "$dir" ]] || die "Répertoire introuvable : $dir"
    [[ -w "$dir" ]] || die "Répertoire non inscriptible : $dir"
    check_real_medium "$dir"

    if [[ -e "${dir}/${MARKER}" ]]; then
        info "Marqueur déjà présent : ${dir}/${MARKER}"
    else
        printf 'Support de sauvegarde de backup-projets.sh — ne pas supprimer.\n' \
            > "${dir}/${MARKER}"
        success "Marqueur créé : ${BOLD}${dir}/${MARKER}${RESET}"
    fi
    info "Ce support sera désormais retrouvé automatiquement."
}

# Certains systèmes de fichiers (exFAT, FAT32, et les partages Windows selon
# la configuration) refusent les liens symboliques. Plutôt que de deviner
# d'après le type de montage — « v9fs » ne dit rien de la partition Windows
# sous-jacente — on tente réellement d'en créer un.
detect_deref() {
    # Sonde posée à la racine du support et non dans BACKUP_ROOT : celui-ci
    # n'existe pas encore en simulation, où l'on n'écrit rien.
    local probe="${DEST_ROOT}/.probe-lien-$$"
    if ln -s cible "$probe" 2>/dev/null; then
        rm -f "$probe"
        DEREF="no"
    else
        DEREF="yes"
        info "La clé ne stocke pas les liens symboliques : ils seront remplacés par leur cible."
    fi
}

# rsync décide de recopier ou non un fichier en comparant sa taille et sa
# date. Si le support refuse qu'on lui fixe une date, la destination porte
# celle de la copie : toujours différente de la source, donc tout est recopié
# à chaque passe, indéfiniment. Le symptôme visible est une avalanche de
# « failed to set times … Operation not permitted » et un état PARTIEL, mais
# le vrai dégât est la perte silencieuse du caractère incrémental.
#
# Cause de loin la plus fréquente sous WSL : un montage drvfs manuel sans
# « uid= ». Les répertoires sont en 777, on peut donc y créer des fichiers,
# mais ceux-ci appartiennent à root — et seul le propriétaire d'un fichier
# peut en fixer la date.
detect_times() {
    local probe="${DEST_ROOT}/.probe-date-$$"
    local owner=""

    : > "$probe" 2>/dev/null || return 0     # l'inscriptibilité est testée ailleurs
    owner="$(stat -c %u "$probe" 2>/dev/null || true)"

    if touch -d '2001-02-03 04:05:00' "$probe" 2>/dev/null; then
        rm -f "$probe"
        return 0
    fi
    rm -f "$probe"

    if [[ "$NO_TIMES" == "yes" ]]; then
        warn "Support incapable de dater les fichiers : comparaison sur la taille seule."
        warn "Une modification qui ne change pas la taille d'un fichier passera inaperçue."
        return 0
    fi

    error "Le support « ${DEST_ROOT} » refuse que l'on fixe la date des fichiers."
    echo "Sans date conservée, rsync ne distingue plus ce qui a changé : chaque" >&2
    echo "sauvegarde recopierait l'intégralité des projets." >&2

    if [[ -n "$owner" && "$owner" != "$(id -u)" ]]; then
        local mnt letter
        mnt="$(mount_point_of "$DEST_ROOT")"
        echo "" >&2
        echo "Les fichiers y appartiennent à l'utilisateur ${owner}, pas à vous (${USER}, $(id -u))." >&2
        echo "Le support est monté sans « uid= » ; seul le propriétaire d'un fichier peut le dater." >&2
        if [[ "$mnt" =~ ^/mnt/([a-z])$ ]]; then
            letter="${BASH_REMATCH[1]}"
            echo "Remontez-le avec votre identité :" >&2
            echo "    sudo umount ${mnt}" >&2
            echo "    sudo mount -t drvfs ${letter^^}: ${mnt} -o uid=$(id -u),gid=$(id -g),noatime" >&2
        fi
    fi

    echo "" >&2
    echo "Pour passer outre malgré tout, ajoutez --no-times (comparaison sur la taille)." >&2
    exit 2
}

prepare_dest() {
    if [[ -z "$DEST_ROOT" ]]; then
        DEST_ROOT="$(detect_dest || true)"
        [[ -n "$DEST_ROOT" ]] || {
            error "Aucun support portant le marqueur ${MARKER} n'a été trouvé."
            echo "Branchez la clé, ou préparez-la une fois pour toutes :" >&2
            echo "    $(basename "$0") --init /mnt/e" >&2
            echo "Une destination ponctuelle reste possible avec --dest DIR." >&2
            exit 2
        }
        info "Support détecté : ${BOLD}${DEST_ROOT}${RESET}"
    else
        [[ -d "$DEST_ROOT" ]] || usage_error "Destination introuvable : $DEST_ROOT"
        check_real_medium "$DEST_ROOT"
        info "Destination imposée : ${BOLD}${DEST_ROOT}${RESET}"
    fi

    [[ -w "$DEST_ROOT" ]] || die "Destination non inscriptible : $DEST_ROOT"
    info "Montage       : $(mount_point_of "$DEST_ROOT")"

    BACKUP_ROOT="${DEST_ROOT}/${BACKUP_DIRNAME}"
    MIRROR_ROOT="${BACKUP_ROOT}/${MIRROR_DIRNAME}"
    ARCHIVE_ROOT="${BACKUP_ROOT}/${ARCHIVE_DIRNAME}"

    if [[ "$DRY_RUN" == "no" ]]; then
        mkdir -p "$MIRROR_ROOT"
        [[ "$DO_ARCHIVE" == "yes" ]] && mkdir -p "$ARCHIVE_ROOT"
    fi

    [[ "$DEREF" == "auto" ]] && detect_deref
    detect_times

    local avail
    avail="$(df -B1 --output=avail "$DEST_ROOT" 2>/dev/null | tail -1 | tr -dc '0-9')"
    if [[ -n "$avail" ]]; then
        info "Espace libre  : $(human "$avail")"
        if (( avail < LOW_SPACE_BYTES )); then
            warn "Moins de $(human "$LOW_SPACE_BYTES") disponibles — la sauvegarde peut échouer."
        fi
    fi
}

# -----------------------------------------------------------------------------
# Outils d'affichage
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

human() { numfmt --to=iec-i --format='%.1f' --suffix=o "${1:-0}" 2>/dev/null || printf '%s o' "${1:-0}"; }

# -----------------------------------------------------------------------------
# État Git (hors ligne)
# -----------------------------------------------------------------------------
GIT_LABEL="-"
GIT_SEV=0

git_state() {
    local dir="$1"
    GIT_LABEL="-"
    GIT_SEV=0

    [[ "$DO_GIT" == "yes" ]] || return 0

    # .git testé en -e et non en -d : dans un worktree lié ou un submodule,
    # c'est un fichier contenant « gitdir: … ».
    if [[ ! -e "$dir/.git" ]]; then
        GIT_LABEL="hors git"
        return 0
    fi

    if ! git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
        GIT_LABEL="aucun commit"
        GIT_SEV=1
        return 0
    fi

    local dirty notes=""
    # --porcelain : format stable et non traduit, une ligne par fichier.
    dirty="$(git -C "$dir" status --porcelain --untracked-files=normal 2>/dev/null | wc -l || echo 0)"
    if (( dirty > 0 )); then
        notes="${dirty} modif(s)"
        GIT_SEV=1
    fi

    local upstream ahead
    if upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        # Aucun fetch : on compare au dernier état connu du distant. C'est
        # suffisant pour ce que le script cherche à dire — « ces commits ne
        # sont sûrement pas publiés » — et ça garde la sauvegarde hors ligne.
        ahead="$(git -C "$dir" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)"
        if (( ahead > 0 )); then
            [[ -n "$notes" ]] && notes+=", "
            notes+="${ahead} à pousser"
            GIT_SEV=1
        fi
    else
        [[ -n "$notes" ]] && notes+=", "
        notes+="sans upstream"
        GIT_SEV=1
    fi

    GIT_LABEL="${notes:-publié}"
}

# -----------------------------------------------------------------------------
# Synchronisation
# -----------------------------------------------------------------------------
EXCLUDE_FILE=""
RSYNC_LOG=""

setup_workdir() {
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    EXCLUDE_FILE="${TMP_DIR}/excludes"
    printf '%s\n' "${DEV_EXCLUDES[@]}" > "$EXCLUDE_FILE"
    RSYNC_LOG="${TMP_DIR}/rsync.log"
}

# Résultat de la dernière synchronisation (globaux : bash ne rend qu'un entier).
# CUR_SEV : 0 rien à signaler, 1 remarque sans conséquence, 2 sauvegarde non
# garantie — seul ce dernier niveau pèse sur le code de sortie.
CUR_STATE="OK"
CUR_COLOR="$GREEN"
CUR_DETAIL=""
CUR_SEV=0

sync_project() {
    local src="$1" label="$2"
    local dst="${MIRROR_ROOT}/${label}"

    CUR_STATE="OK"
    CUR_COLOR="$GREEN"
    CUR_DETAIL=""
    CUR_SEV=0

    if [[ ! -d "$src" ]]; then
        CUR_STATE="ABSENT"; CUR_COLOR="$RED"; CUR_SEV=2
        CUR_DETAIL="répertoire introuvable"
        return 1
    fi

    # Garde-fou contre le pire scénario : un disque Windows non monté laisse
    # un point de montage vide. Avec --delete, rsync viderait alors le miroir
    # de tout le projet, c'est-à-dire la sauvegarde elle-même.
    #
    # Encore faut-il distinguer ce cas d'un répertoire réellement vide, qu'un
    # glob « ~/projets/* » ramène tôt ou tard : il n'y a alors rien à sauver,
    # et faire échouer la passe entière pour ça serait une fausse alerte.
    if [[ -z "$(ls -A "$src" 2>/dev/null)" ]]; then
        CUR_STATE="VIDE"
        if [[ -d "$dst" && -n "$(ls -A "$dst" 2>/dev/null)" ]]; then
            CUR_COLOR="$RED"; CUR_SEV=2
            CUR_DETAIL="source vide alors que le miroir ne l'est pas — disque non monté ? miroir laissé intact"
        else
            CUR_COLOR="$YELLOW"; CUR_SEV=1
            CUR_DETAIL="répertoire vide, rien à sauvegarder"
        fi
        return 1
    fi

    local -a opts=(
        --recursive
        --delete --delete-excluded
        --exclude-from="$EXCLUDE_FILE"
        --stats
    )

    if [[ "$NO_TIMES" == "yes" ]]; then
        # Support incapable de dater : comparer les dates n'aurait aucun sens,
        # elles seraient toutes fausses. La taille reste le seul critère
        # exploitable — imparfait, mais déterministe.
        opts+=(--no-times --size-only)
    else
        # Horodatages FAT/exFAT à la granularité de 2 s : sans cette tolérance,
        # rsync retransfère indéfiniment les mêmes fichiers.
        opts+=(--times --modify-window=2)
    fi

    if [[ "$DEREF" == "yes" ]]; then
        opts+=(--copy-links)
    else
        opts+=(--links)
    fi
    [[ "$DRY_RUN" == "yes" ]] && opts+=(--dry-run)
    if [[ "$QUIET" == "no" && -t 1 ]]; then
        opts+=(--info=progress2 --human-readable)
    fi

    [[ "$DRY_RUN" == "no" ]] && mkdir -p "$dst"

    # LC_ALL=C : la section --stats est relue plus bas, on fige son format.
    local rc=0
    set +e
    if [[ "$QUIET" == "no" ]]; then
        LC_ALL=C rsync "${opts[@]}" "${src}/" "${dst}/" 2>&1 | tee "$RSYNC_LOG"
        rc=${PIPESTATUS[0]}
    else
        LC_ALL=C rsync "${opts[@]}" "${src}/" "${dst}/" > "$RSYNC_LOG" 2>&1
        rc=$?
    fi
    set -e

    local files bytes
    files="$(grep -m1 '^Number of regular files transferred:' "$RSYNC_LOG" | tr -dc '0-9' || true)"
    bytes="$(grep -m1 '^Total transferred file size:' "$RSYNC_LOG" \
        | sed 's/.*: *//; s/ bytes.*//' | tr -dc '0-9' || true)"
    CUR_DETAIL="${files:-0} fichier(s), $(human "${bytes:-0}")"

    case "$rc" in
        0)  ;;
        24) # Des fichiers ont disparu entre l'inventaire et la copie : normal
            # si un éditeur écrit pendant la sauvegarde, sans conséquence.
            CUR_DETAIL+=" — fichiers disparus pendant la copie"
            ;;
        23) CUR_STATE="PARTIEL"; CUR_COLOR="$YELLOW"; CUR_SEV=2
            CUR_DETAIL+=" — $(first_rsync_error)"
            return 1
            ;;
        *)  CUR_STATE="ÉCHEC"; CUR_COLOR="$RED"; CUR_SEV=2
            CUR_DETAIL="rsync code ${rc} — $(first_rsync_error)"
            return 1
            ;;
    esac

    return 0
}

first_rsync_error() {
    local msg
    msg="$(grep -m1 '^rsync: ' "$RSYNC_LOG" | sed 's/^rsync: //; s/ (in main.*//' || true)"
    printf '%s' "${msg:-cause inconnue, voir la sortie ci-dessus}"
}

# -----------------------------------------------------------------------------
# Archives horodatées (option -a)
# -----------------------------------------------------------------------------

# L'archive est construite depuis le MIROIR, jamais depuis la source : le
# miroir est déjà expurgé des artefacts de développement, et il est local au
# support — relire 1 Go à travers un montage 9p une seconde fois coûterait
# une minute pour un résultat identique.
archive_project() {
    local label="$1"
    local stamp archive
    stamp="$(date +%Y%m%d_%H%M)"
    archive="${ARCHIVE_ROOT}/${label}_${stamp}.tar.zst"

    if [[ "$DRY_RUN" == "yes" ]]; then
        CUR_DETAIL+=" | archive simulée"
        return 0
    fi

    if tar --create --ignore-failed-read \
            -C "$MIRROR_ROOT" "./${label}" 2>/dev/null \
            | zstd -q -T0 "-${ZSTD_LEVEL}" --long > "$archive"; then
        local size
        size="$(stat -c %s "$archive" 2>/dev/null || echo 0)"
        CUR_DETAIL+=" | archive $(human "$size")"
        rotate_archives "$label"
    else
        rm -f "$archive"
        CUR_DETAIL+=" | archive ÉCHOUÉE"
        [[ "$CUR_STATE" == "OK" ]] && { CUR_STATE="PARTIEL"; CUR_COLOR="$YELLOW"; }
        CUR_SEV=2
        return 1
    fi
}

# Ne conserve que les KEEP archives les plus récentes du projet. Le tri se
# fait sur le nom : l'horodatage AAAAMMJJ_HHMM est trié lexicographiquement
# comme chronologiquement, ce qui évite de dépendre des dates de la clé —
# souvent fausses sur un système de fichiers FAT.
rotate_archives() {
    local label="$1" old
    local -a archives=()

    shopt -s nullglob
    archives=( "${ARCHIVE_ROOT}/${label}"_[0-9]*.tar.zst )
    shopt -u nullglob

    (( ${#archives[@]} > KEEP )) || return 0

    local -a sorted=()
    mapfile -t sorted < <(printf '%s\n' "${archives[@]}" | sort)
    for old in "${sorted[@]:0:$(( ${#sorted[@]} - KEEP ))}"; do
        rm -f "$old"
    done
}

# -----------------------------------------------------------------------------
# Récapitulatif
# -----------------------------------------------------------------------------
declare -a R_LABEL=() R_STATE=() R_COLOR=() R_SEV=() R_GIT=() R_GITSEV=() R_DETAIL=()
NAME_WIDTH=6
GIT_WIDTH=3

# Les colonnes ne sont dimensionnées qu'une fois toutes les lignes connues :
# l'état Git d'un projet (« 12 modif(s), 3 à pousser ») n'est pas prévisible
# avant de l'avoir inspecté.
compute_widths() {
    local i
    NAME_WIDTH=6      # largeur mini = longueur de l'en-tête « PROJET »
    GIT_WIDTH=3
    for i in ${R_LABEL[@]+"${!R_LABEL[@]}"}; do
        (( ${#R_LABEL[$i]} > NAME_WIDTH )) && NAME_WIDTH=${#R_LABEL[$i]}
        (( ${#R_GIT[$i]}   > GIT_WIDTH ))  && GIT_WIDTH=${#R_GIT[$i]}
    done
    return 0
}

# Rend le tableau final. Le paramètre décide de l'habillage : « couleur »
# pour le terminal, « brut » pour le fichier déposé sur la clé, qui doit
# rester lisible dans le Bloc-notes de n'importe quel poste.
render_table() {
    local mode="$1" i state git

    compute_widths

    if [[ "$mode" == "couleur" ]]; then
        echo -e "${BOLD}$(pad "PROJET" "$NAME_WIDTH")  $(pad "COPIE" "$STATE_WIDTH")  $(pad "GIT" "$GIT_WIDTH")  DÉTAIL${RESET}"
    else
        printf '%s  %s  %s  %s\n' \
            "$(pad "PROJET" "$NAME_WIDTH")" "$(pad "COPIE" "$STATE_WIDTH")" \
            "$(pad "GIT" "$GIT_WIDTH")" "DÉTAIL"
    fi
    printf '%*s\n' "$(( NAME_WIDTH + STATE_WIDTH + GIT_WIDTH + 30 ))" '' | tr ' ' '-'

    for i in ${R_LABEL[@]+"${!R_LABEL[@]}"}; do
        state="$(pad "${R_STATE[$i]}" "$STATE_WIDTH")"
        git="$(pad "${R_GIT[$i]}" "$GIT_WIDTH")"
        if [[ "$mode" == "couleur" ]]; then
            local gitcol="$RESET"
            (( R_GITSEV[i] > 0 )) && gitcol="$YELLOW"
            echo -e "$(pad "${R_LABEL[$i]}" "$NAME_WIDTH")  ${R_COLOR[$i]}${state}${RESET}  ${gitcol}${git}${RESET}  ${R_DETAIL[$i]}"
        else
            printf '%s  %s  %s  %s\n' \
                "$(pad "${R_LABEL[$i]}" "$NAME_WIDTH")" "$state" "$git" "${R_DETAIL[$i]}"
        fi
    done
}

# Un projet retiré de la configuration, ou renommé, laisse son miroir sur la
# clé : il occupe de la place et fait croire à une sauvegarde à jour. On le
# signale sans jamais y toucher — c'est peut-être la seule copie restante
# d'un projet effacé côté source, exactement ce que la clé sert à garder.
warn_orphans() {
    [[ "$DRY_RUN" == "yes" ]] && return 0
    # Avec --only, tout le reste paraîtrait orphelin : rien à conclure.
    (( ${#ONLY_PATTERNS[@]} > 0 )) && return 0
    [[ -d "$MIRROR_ROOT" ]] || return 0

    local dir name i known
    local -a orphans=()

    shopt -s nullglob
    for dir in "$MIRROR_ROOT"/*/; do
        name="$(basename "$dir")"
        known="no"
        for i in ${R_LABEL[@]+"${!R_LABEL[@]}"}; do
            [[ "${R_LABEL[$i]}" == "$name" ]] && { known="yes"; break; }
        done
        [[ "$known" == "no" ]] && orphans+=("$name")
    done
    shopt -u nullglob

    (( ${#orphans[@]} > 0 )) || return 0

    echo ""
    warn "Miroir(s) sans projet correspondant dans ${CONF} :"
    printf '            %s\n' "${orphans[@]}"
    warn "Conservés tels quels. À supprimer à la main de ${MIRROR_ROOT} si inutiles."
}

write_report() {
    local report="${BACKUP_ROOT}/${REPORT_NAME}"

    [[ "$DRY_RUN" == "yes" ]] && return 0

    {
        echo "Sauvegarde des projets — $(date '+%A %d %B %Y à %H:%M')"
        echo "Machine : $(hostname)   Utilisateur : ${USER}"
        echo "Liste    : ${CONF}"
        echo ""
        render_table brut
        echo ""
        echo "Colonne GIT : état au moment de la sauvegarde, sans accès réseau."
        echo "  « publié »     = rien en attente vis-à-vis du dernier état connu du distant"
        echo "  « N à pousser »= commits présents ici et probablement nulle part ailleurs"
        echo ""
        echo "Récupérer un projet depuis cette clé :"
        echo "  - ouvrir directement les fichiers dans ${BACKUP_DIRNAME}/${MIRROR_DIRNAME}/<projet>/"
        echo "  - ou récupérer l'historique : git clone ${BACKUP_DIRNAME}/${MIRROR_DIRNAME}/<projet> <destination>"
    } > "$report" 2>/dev/null || warn "Rapport non écrit sur la clé."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_not_root

    if [[ -n "$INIT_DIR" ]]; then
        init_dest "$INIT_DIR"
        exit 0
    fi

    check_deps
    load_config
    resolve_projects

    echo -e "\n${BOLD}=== Sauvegarde des projets ===${RESET}"
    [[ "$DRY_RUN" == "yes" ]] && warn "Mode simulation (--dry-run) : rien ne sera écrit."
    info "Liste         : ${CONF}"
    info "Projets       : ${#PROJ_PATH[@]}"

    prepare_dest
    setup_workdir
    echo ""

    local i label src started elapsed
    for i in "${!PROJ_PATH[@]}"; do
        src="${PROJ_PATH[$i]}"
        label="${PROJ_LABEL[$i]}"
        started=$SECONDS

        [[ "$QUIET" == "no" ]] && info "${BOLD}${label}${RESET}  ←  ${src}"

        git_state "$src"

        # « || true » : sync_project rend 1 sur incident, ce qui sous set -e
        # interromprait la sauvegarde des projets suivants — exactement ce
        # qu'il ne faut pas faire un soir où l'on est pressé.
        sync_project "$src" "$label" || true

        if [[ "$DO_ARCHIVE" == "yes" && "$CUR_STATE" != "ABSENT" && "$CUR_STATE" != "VIDE" && "$CUR_STATE" != "ÉCHEC" ]]; then
            archive_project "$label" || true
        fi

        elapsed=$(( SECONDS - started ))
        (( elapsed >= 5 )) && CUR_DETAIL+=" | ${elapsed}s"

        R_LABEL+=("$label")
        R_STATE+=("$CUR_STATE")
        R_COLOR+=("$CUR_COLOR")
        R_SEV+=("$CUR_SEV")
        R_GIT+=("$GIT_LABEL")
        R_GITSEV+=("$GIT_SEV")
        R_DETAIL+=("$CUR_DETAIL")

        [[ "$QUIET" == "no" ]] && echo ""
    done

    echo -e "${BOLD}=== RÉCAPITULATIF ===${RESET}"
    render_table couleur
    write_report
    warn_orphans

    local failed=0 unpublished=0
    for i in "${!R_SEV[@]}"; do
        (( R_SEV[i] >= 2 )) && failed=$(( failed + 1 ))
        (( R_GITSEV[i] > 0 )) && unpublished=$(( unpublished + 1 ))
    done

    echo ""
    if (( unpublished > 0 )); then
        warn "${unpublished} projet(s) non publié(s) — c'est bien pour eux que la clé existe."
    fi

    if (( failed > 0 )); then
        warn "${BOLD}${failed} projet(s) en échec${RESET} sur ${#R_LABEL[@]}. Rien n'est garanti pour eux."
        exit 1
    fi

    if [[ "$DRY_RUN" == "yes" ]]; then
        success "${BOLD}Simulation terminée.${RESET} ${#R_LABEL[@]} projet(s) seraient sauvegardés."
    else
        success "${BOLD}Sauvegarde terminée.${RESET} ${#R_LABEL[@]} projet(s) sur ${DEST_ROOT}."
    fi
    exit 0
}

main "$@"
