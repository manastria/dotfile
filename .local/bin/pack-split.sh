#!/usr/bin/env bash
# NAME
#     pack-split.sh — compresse (zstd), découpe, protège (par2) et vérifie
#                     (b3sum) un gros fichier, ou refait le chemin inverse
#
# SYNOPSIS
#     pack-split.sh pack   FICHIER [-o DIR] [-s TAILLE] [-l NIVEAU] [-r POURCENT] [-d]
#     pack-split.sh unpack REPERTOIRE [-o DIR] [-f]
#     pack-split.sh verify REPERTOIRE
#     pack-split.sh -h
#
# DESCRIPTION
#     Prépare un gros fichier (image de VM, disque, archive…) pour un
#     transfert vers un Drive (kDrive, Google Drive…) ou une clé USB :
#     des volumes de taille raisonnable, des empreintes pour détecter la
#     corruption, et de la redondance pour la réparer sans retransférer.
#
#     « pack » crée, à côté du fichier, un répertoire « FICHIER.split »
#     (le nom exact du fichier est pris par le fichier lui-même, d'où le
#     suffixe) contenant :
#
#         FICHIER.zst.001, .002…   volumes zstd de TAILLE chacun
#         FICHIER.b3               empreintes BLAKE3 des volumes
#         FICHIER.orig.b3          empreinte BLAKE3 du fichier d'origine
#         FICHIER.par2, .vol*.par2 données de réparation par2
#         RESTAURER.txt            mode d'emploi sans ce script
#
#     Avant de proposer la suppression de l'original, « pack » relit les
#     volumes, les décompresse et compare l'empreinte du résultat à celle
#     de l'original : c'est la preuve que la restauration sera identique
#     octet pour octet.
#
#     « unpack » refait le fichier d'origine à partir du répertoire, dans
#     son répertoire parent. Il contrôle les volumes avec b3sum, les répare
#     avec par2 si nécessaire, puis vérifie le fichier produit.
#
#     « verify » contrôle seulement les volumes (b3sum) et indique si par2
#     peut les réparer ; rien n'est modifié.
#
# OPTIONS
#     -o, --output DIR      pack : répertoire où créer FICHIER.split
#                           (défaut : répertoire du fichier).
#                           unpack : répertoire où recréer le fichier
#                           (défaut : parent du répertoire .split).
#     -s, --size TAILLE     pack : taille d'un volume, au format de split(1) :
#                           500M, 1G, 2G… (défaut : 1G).
#     -l, --level NIVEAU    pack : niveau zstd de 1 à 19 (défaut : 3).
#                           Plus haut = plus petit mais bien plus lent.
#     -r, --redundancy PCT  pack : redondance par2 en pourcents, de 1 à 100
#                           (défaut : 10).
#     -d, --delete-source   pack : supprime le fichier d'origine une fois la
#                           vérification réussie, sans poser la question.
#                           Sans cette option, la question n'est posée que si
#                           le script tourne dans un terminal.
#     -f, --force           unpack : écrase un fichier existant du même nom
#                           (seulement une fois le nouveau fichier vérifié).
#     -h, --help            Affiche cette aide.
#
# EXAMPLES
#     # Prépare disque.qcow2 → ./disque.qcow2.split/
#     pack-split.sh pack disque.qcow2
#
#     # Volumes de 500 Mo directement sur la clé USB, puis suppression
#     pack-split.sh pack disque.qcow2 -s 500M -o /media/usb -d
#
#     # Après le transfert : le contenu du Drive est-il intact ?
#     pack-split.sh verify /media/usb/disque.qcow2.split
#
#     # Restauration dans le répertoire parent de disque.qcow2.split
#     pack-split.sh unpack disque.qcow2.split
#
# EXIT CODES
#     0   Opération réussie et vérifiée.
#     1   Erreur d'exécution : outil manquant, volume corrompu et
#         irréparable, empreinte finale différente, disque plein.
#     2   Erreur d'usage : option inconnue, argument manquant ou invalide,
#         chemin introuvable, destination déjà existante.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly DEFAULT_SIZE="1G"
readonly DEFAULT_LEVEL=3
readonly DEFAULT_REDUNDANCY=10
readonly DIR_SUFFIX=".split"
readonly SPLIT_SUFFIX_LEN=3     # .001 à .999 : jusqu'à 999 volumes

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
    # Réimprime l'en-tête manpage (lignes de commentaire après le shebang)
    # sans le préfixe « # » : l'aide suit l'en-tête même s'il grossit.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# Refuse une option à valeur laissée sans argument : sans ce garde-fou, le
# « shift 2 » échouerait et set -e ferait sortir le script sans message.
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Nettoyage en cas d'erreur ou d'interruption
# -----------------------------------------------------------------------------
CLEANUP_PATHS=()    # sorties partielles à supprimer si le script échoue

cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && ${#CLEANUP_PATHS[@]} -gt 0 ]]; then
        warn "Échec ou interruption : suppression des fichiers incomplets."
        rm -rf -- "${CLEANUP_PATHS[@]}"
    fi
}
trap cleanup EXIT
# Ctrl-C et kill passent par exit pour déclencher le trap EXIT ci-dessus.
trap 'exit 130' INT
trap 'exit 143' TERM

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
CMD=""
TARGET=""
OUTDIR=""
VOL_SIZE="$DEFAULT_SIZE"
LEVEL="$DEFAULT_LEVEL"
REDUNDANCY="$DEFAULT_REDUNDANCY"
DELETE_SOURCE="no"
FORCE="no"

parse_args() {
    [[ $# -gt 0 ]] || usage_error "Commande attendue : pack, unpack ou verify."

    case "$1" in
        -h|--help)            usage; exit 0 ;;
        pack|unpack|verify)   CMD="$1"; shift ;;
        *)                    usage_error "Commande inconnue : $1" ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)       value_of "$1" "${2-}"; OUTDIR="$2"; shift 2 ;;
            -s|--size)         value_of "$1" "${2-}"; VOL_SIZE="$2"; shift 2 ;;
            -l|--level)        value_of "$1" "${2-}"; LEVEL="$2"; shift 2 ;;
            -r|--redundancy)   value_of "$1" "${2-}"; REDUNDANCY="$2"; shift 2 ;;
            -d|--delete-source) DELETE_SOURCE="yes"; shift ;;
            -f|--force)        FORCE="yes"; shift ;;
            -h|--help)         usage; exit 0 ;;
            -*)                usage_error "Option inconnue : $1" ;;
            *)
                [[ -z "$TARGET" ]] || usage_error "Un seul argument attendu (reçu aussi : $1)."
                TARGET="$1"; shift ;;
        esac
    done

    [[ -n "$TARGET" ]] || usage_error "Argument manquant : $([[ $CMD == pack ]] && echo FICHIER || echo REPERTOIRE)."

    # Les valeurs sont validées ici, pas à mi-parcours d'une compression de
    # plusieurs heures.
    [[ "$VOL_SIZE" =~ ^[1-9][0-9]*([KMGT]B?)?$ ]] \
        || usage_error "Taille de volume invalide : $VOL_SIZE (exemples : 500M, 1G)."
    [[ "$LEVEL" =~ ^[0-9]+$ && "$LEVEL" -ge 1 && "$LEVEL" -le 19 ]] \
        || usage_error "Niveau zstd invalide : $LEVEL (1 à 19)."
    [[ "$REDUNDANCY" =~ ^[0-9]+$ && "$REDUNDANCY" -ge 1 && "$REDUNDANCY" -le 100 ]] \
        || usage_error "Redondance invalide : $REDUNDANCY (1 à 100)."

    if [[ "$CMD" == "pack" ]]; then
        [[ -f "$TARGET" ]] || usage_error "Fichier introuvable : $TARGET"
    else
        [[ -d "$TARGET" ]] || usage_error "Répertoire introuvable : $TARGET"
    fi
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_tools() {
    local missing=() tool
    for tool in zstd par2 b3sum pv; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Outil(s) manquant(s) : ${missing[*]}"
        # Les noms de paquets Debian/Ubuntu sont ceux des commandes.
        die "Installation : sudo apt install ${missing[*]}"
    fi
}

human() { numfmt --to=iec --suffix=B "$1"; }

# -----------------------------------------------------------------------------
# Lecture d'un répertoire .split (unpack et verify)
# -----------------------------------------------------------------------------
PACK_DIR=""         # chemin absolu du répertoire .split
NAME=""             # nom du fichier d'origine
ORIG_HASH=""        # empreinte BLAKE3 du fichier d'origine
VOLUMES=()          # noms des volumes, dans l'ordre

load_pack_dir() {
    PACK_DIR=$(realpath -- "$1")

    # Le nom d'origine vient du fichier .orig.b3 : un répertoire déplacé ou
    # renommé reste donc utilisable.
    local origs=()
    mapfile -t origs < <(find "$PACK_DIR" -maxdepth 1 -type f -name '*.orig.b3')
    [[ ${#origs[@]} -eq 1 ]] \
        || die "Répertoire invalide : un seul fichier *.orig.b3 attendu dans $PACK_DIR (trouvé : ${#origs[@]})."

    local line
    line=$(<"${origs[0]}")
    ORIG_HASH="${line%%  *}"
    NAME="${line#*  }"
    [[ "$ORIG_HASH" =~ ^[0-9a-f]{64}$ && -n "$NAME" ]] \
        || die "Fichier d'empreinte illisible : ${origs[0]} (essayez : cd '$PACK_DIR' && par2 repair '*.par2')"

    [[ -f "$PACK_DIR/$NAME.b3" ]] \
        || die "Manifeste des volumes introuvable : $PACK_DIR/$NAME.b3"

    # La liste des volumes vient du manifeste et non d'un glob : un volume
    # perdu est ainsi détecté (et réparable par par2) au lieu d'être ignoré.
    mapfile -t VOLUMES < <(sed 's/^[^ ]*  //' "$PACK_DIR/$NAME.b3")
    [[ ${#VOLUMES[@]} -gt 0 ]] || die "Manifeste vide : $PACK_DIR/$NAME.b3"
}

# Somme des tailles des volumes présents : sert de total à la barre de
# progression de pv, qui lit le flux compressé.
volumes_size() {
    (cd "$PACK_DIR" && stat -c %s -- "${VOLUMES[@]}" | awk '{ s += $1 } END { print s + 0 }')
}

# Concatène les volumes sur la sortie standard.
stream_volumes() { (cd "$PACK_DIR" && cat -- "${VOLUMES[@]}"); }

# Contrôle des volumes par b3sum ; affiche « volume: OK » au fil de l'eau.
check_volumes() {
    (cd "$PACK_DIR" && b3sum --check "$NAME.b3")
}

# Réparation par par2 à partir des volumes de redondance. par2 renomme les
# fichiers endommagés en « .1 » plutôt que de les écraser.
repair_volumes() {
    [[ -f "$PACK_DIR/$NAME.par2" ]] || die "Fichier de réparation introuvable : $PACK_DIR/$NAME.par2"
    local quiet=()
    [[ -t 1 ]] || quiet=(-q)
    (cd "$PACK_DIR" && par2 repair "${quiet[@]}" "$NAME.par2") \
        || die "Réparation par2 impossible : trop de blocs perdus pour la redondance prévue."
}

# -----------------------------------------------------------------------------
# pack
# -----------------------------------------------------------------------------
SRC=""              # chemin absolu du fichier d'origine
SRC_SIZE=0
SRC_HASH=""

prepare_pack() {
    SRC=$(realpath -- "$TARGET")
    NAME=$(basename -- "$SRC")
    SRC_SIZE=$(stat -c %s -- "$SRC")
    [[ "$SRC_SIZE" -gt 0 ]] || die "Le fichier est vide : $SRC"

    local parent="${OUTDIR:-$(dirname -- "$SRC")}"
    mkdir -p -- "$parent"
    PACK_DIR="$(realpath -- "$parent")/${NAME}${DIR_SUFFIX}"

    if [[ -e "$PACK_DIR" ]]; then
        error "Existe déjà : $PACK_DIR"
        echo "Supprimez-le ou choisissez un autre répertoire avec -o." >&2
        exit 2
    fi

    # Pire cas : fichier incompressible. En pratique l'espace nécessaire est
    # souvent bien moindre, d'où un simple avertissement.
    local avail need
    avail=$(df --output=avail -B1 -- "$parent" | tail -n1 | tr -d ' ')
    need=$(( SRC_SIZE + SRC_SIZE * REDUNDANCY / 100 ))
    if [[ "$avail" -lt "$need" ]]; then
        warn "Espace libre : $(human "$avail") — jusqu'à $(human "$need") peuvent être nécessaires."
    fi

    mkdir -- "$PACK_DIR"
    CLEANUP_PATHS+=("$PACK_DIR")

    info "Fichier    : $SRC ($(human "$SRC_SIZE"))"
    info "Sortie     : $PACK_DIR"
    info "Paramètres : volumes ${BOLD}${VOL_SIZE}${RESET}, zstd niveau ${BOLD}${LEVEL}${RESET}, par2 ${BOLD}${REDUNDANCY}%${RESET}"
    echo ""
}

hash_source() {
    info "[1/5] Empreinte BLAKE3 du fichier d'origine..."
    SRC_HASH=$(pv -N "empreinte" -s "$SRC_SIZE" <"$SRC" | b3sum --no-names)
    printf '%s  %s\n' "$SRC_HASH" "$NAME" > "$PACK_DIR/$NAME.orig.b3"
}

compress_and_split() {
    info "[2/5] Compression zstd et découpage en volumes de ${VOL_SIZE}..."
    # -T0 : tous les cœurs. -q : zstd ne mêle pas sa propre progression à celle
    # de pv. Le découpage se fait à la volée : aucun fichier intermédiaire de
    # la taille de l'original.
    pv -N "compression" -s "$SRC_SIZE" <"$SRC" \
        | zstd -q -T0 "-$LEVEL" \
        | split -b "$VOL_SIZE" --numeric-suffixes=1 -a "$SPLIT_SUFFIX_LEN" - "$PACK_DIR/$NAME.zst."

    # Les volumes sont seuls dans le répertoire à ce stade : le glob est sûr.
    mapfile -t VOLUMES < <(find "$PACK_DIR" -maxdepth 1 -type f -name '*.zst.[0-9]*' -printf '%f\n' | LC_ALL=C sort)
    [[ ${#VOLUMES[@]} -gt 0 ]] || die "Aucun volume produit."
    info "${#VOLUMES[@]} volume(s) créé(s), $(human "$(volumes_size)") au total."
}

hash_volumes() {
    info "[3/5] Empreintes BLAKE3 des volumes..."
    local vol hash
    : > "$PACK_DIR/$NAME.b3"
    for vol in "${VOLUMES[@]}"; do
        hash=$(pv -N "$vol" <"$PACK_DIR/$vol" | b3sum --no-names)
        # Format « empreinte␣␣nom » : directement relisible par b3sum --check.
        printf '%s  %s\n' "$hash" "$vol" >> "$PACK_DIR/$NAME.b3"
    done
}

create_par2() {
    info "[4/5] Données de réparation par2 (${REDUNDANCY}%)..."
    # Les manifestes sont protégés avec les volumes : un .b3 corrompu serait
    # sinon sans remède. par2 enregistre les noms tels qu'il les reçoit, d'où
    # le cd : les chemins restent relatifs au répertoire.
    # Dans un terminal, le pourcentage de par2 s'affiche sur place et prouve que
    # le calcul avance ; redirigé vers un fichier, il produirait des milliers
    # de lignes : -q dans ce cas.
    local quiet=()
    [[ -t 1 ]] || quiet=(-q)
    (cd "$PACK_DIR" && par2 create "${quiet[@]}" -r"$REDUNDANCY" "$NAME.par2" \
        "${VOLUMES[@]}" "$NAME.b3" "$NAME.orig.b3")
}

verify_roundtrip() {
    info "[5/5] Contrôle de bout en bout : relecture, décompression, comparaison..."
    local got
    got=$(stream_volumes | pv -N "contrôle" -s "$(volumes_size)" | zstd -dcq | b3sum --no-names)
    if [[ "$got" != "$SRC_HASH" ]]; then
        error "L'empreinte après décompression diffère de celle de l'original."
        die "Les volumes ne sont pas fiables ; l'original n'a pas été touché."
    fi
}

write_readme() {
    cat > "$PACK_DIR/RESTAURER.txt" <<EOF
Fichier d'origine : $NAME
Taille d'origine  : $SRC_SIZE octets
Empreinte BLAKE3  : $SRC_HASH
Créé le           : $(date '+%Y-%m-%d %H:%M')

Restauration avec le script (dotfiles) :
    pack-split.sh unpack <ce répertoire>

Restauration manuelle (outils : zstd, par2, b3sum), depuis ce répertoire :
    b3sum --check "$NAME.b3"               # contrôle des volumes
    par2 repair "$NAME.par2"               # seulement si un volume est corrompu ou manquant
    cat "$NAME".zst.[0-9][0-9][0-9] | zstd -d > "../$NAME"
    b3sum "../$NAME"                       # doit afficher l'empreinte ci-dessus
EOF
}

offer_source_deletion() {
    local answer
    if [[ "$DELETE_SOURCE" != "yes" ]]; then
        if [[ ! -t 0 ]]; then
            info "Original conservé. Pour le supprimer : rm -- \"$SRC\""
            return 0
        fi
        read -r -p "$(echo -e "${YELLOW}Supprimer le fichier d'origine ?${RESET} [o/N] ")" answer
        if [[ ! "$answer" =~ ^[oOyY]$ ]]; then
            info "Original conservé."
            return 0
        fi
    fi
    rm -- "$SRC"
    success "Fichier d'origine supprimé : $SRC"
}

cmd_pack() {
    prepare_pack
    hash_source
    compress_and_split
    hash_volumes
    create_par2
    verify_roundtrip
    write_readme

    # Tout est valide : les sorties ne sont plus « partielles ».
    CLEANUP_PATHS=()

    echo ""
    success "Prêt à transférer : ${BOLD}${PACK_DIR}${RESET}"
    info "Taille : $(human "$(du -sb -- "$PACK_DIR" | cut -f1)") pour $(human "$SRC_SIZE") d'origine."
    info "Après transfert, contrôle : $(basename "$0") verify \"$PACK_DIR\""
    offer_source_deletion
}

# -----------------------------------------------------------------------------
# unpack
# -----------------------------------------------------------------------------
cmd_unpack() {
    load_pack_dir "$TARGET"

    local parent="${OUTDIR:-$(dirname -- "$PACK_DIR")}"
    mkdir -p -- "$parent"
    local dest tmp
    dest="$(realpath -- "$parent")/$NAME"
    tmp="$dest.partial"

    if [[ -e "$dest" && "$FORCE" != "yes" ]]; then
        error "Existe déjà : $dest"
        echo "Utilisez --force pour l'écraser, ou -o pour un autre répertoire." >&2
        exit 2
    fi

    info "Source      : $PACK_DIR (${#VOLUMES[@]} volume(s))"
    info "Destination : $dest"
    echo ""

    info "[1/3] Contrôle des volumes (b3sum)..."
    if ! check_volumes; then
        warn "Volume(s) corrompu(s) ou manquant(s) : tentative de réparation par2..."
        repair_volumes
        info "Nouveau contrôle après réparation..."
        check_volumes || die "Volumes toujours invalides après réparation par2."
        success "Volumes réparés."
    fi

    info "[2/3] Concaténation et décompression..."
    # Écriture dans un .partial renommé seulement à la fin : un fichier du
    # nom définitif est toujours un fichier complet et vérifié.
    CLEANUP_PATHS+=("$tmp")
    stream_volumes | pv -N "décompression" -s "$(volumes_size)" | zstd -dcq > "$tmp"

    info "[3/3] Vérification du fichier restauré..."
    local size got
    size=$(stat -c %s -- "$tmp")
    got=$(pv -N "empreinte" -s "$size" <"$tmp" | b3sum --no-names)
    [[ "$got" == "$ORIG_HASH" ]] \
        || die "L'empreinte du fichier restauré diffère de l'original (volumes valides mais contenu inattendu)."

    mv -f -- "$tmp" "$dest"
    CLEANUP_PATHS=()

    echo ""
    success "Fichier restauré : ${BOLD}${dest}${RESET} ($(human "$size"), empreinte conforme)"
}

# -----------------------------------------------------------------------------
# verify
# -----------------------------------------------------------------------------
cmd_verify() {
    load_pack_dir "$TARGET"
    info "Contrôle de ${#VOLUMES[@]} volume(s) de ${BOLD}${NAME}${RESET}..."
    if check_volumes; then
        success "Tous les volumes sont intègres."
        return 0
    fi

    error "Volume(s) corrompu(s) ou manquant(s)."
    # Un diagnostic par2 dit si la réparation est possible, sans rien modifier.
    if [[ -f "$PACK_DIR/$NAME.par2" ]]; then
        (cd "$PACK_DIR" && par2 verify "$NAME.par2") || true
    fi
    die "Si par2 annonce « repair is possible » : $(basename "$0") unpack \"$PACK_DIR\" répare automatiquement."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    check_tools

    case "$CMD" in
        pack)   cmd_pack ;;
        unpack) cmd_unpack ;;
        verify) cmd_verify ;;
    esac
}

main "$@"
