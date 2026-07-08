#!/usr/bin/env bash
set -euo pipefail

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
  cat <<'EOF'
Usage:
  pack-dir.sh [dossier] [options]

Par defaut (aligne sur pack-project.sh):
  dossier courant si non precise, codec zst, date+heure ajoutee,
  sortie dans le dossier parent de la source.

Options:
  -b <nom_base>        Nom de base (defaut: nom du dossier)
  -c <xz|gz|bz2|zst>   Codec tar (defaut: zst)
  -T                  Pas de date+heure dans le nom (par defaut, elle est ajoutee: _YYYYMMDD_HHMM)
  -z                  Genere aussi un .zip (en plus du tar compresse)
  -o <dir_sortie>      Repertoire de sortie (defaut: dossier parent de la source)
  -I <fichier>         Fichier d'exclusions (une regle par ligne, optionnel)
  -E                  Desactive les exclusions (inclut tout, ignore -I)
  -h                  Aide

Exemples:
  ./pack-dir.sh                     # archive le dossier courant
  ./pack-dir.sh ./TP
  ./pack-dir.sh ./TP -z
  ./pack-dir.sh ./TP -c gz -o ./out
  ./pack-dir.sh ./TP -b elec-ccf -z
  ./pack-dir.sh ./TP -T             # pas de date+heure dans le nom
  ./pack-dir.sh ./TP -I .packignore
  ./pack-dir.sh ./TP -E             # inclut .git, node_modules, etc.

Notes:
  - Le dossier source est optionnel (defaut: dossier courant), et peut etre relatif ou absolu.
  - Les exclusions par defaut sont des patterns "glob" (tar/zip).
  - Avec -I, chaque ligne est un pattern (lignes vides et commentaires ignores).
  - -E force l'inclusion de tout et ignore -I.

Le fichier .packignore:
  # commentaires OK
  .git
  node_modules
  **/__pycache__
  .vscode
  .idea
  dist
  build
EOF
}

# 1er argument optionnel: dossier source (defaut: dossier courant, comme pack-project.sh)
if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

src="."
if [[ $# -gt 0 && "$1" != -* ]]; then
  src="${1%/}"
  shift
fi

base=""
codec="zst"
add_ts=true
make_zip=false
outdir=""
ignore_file=""
disable_excludes=false

while getopts ":b:c:Tzo:I:Eh" opt; do
  case "$opt" in
    b) base="$OPTARG" ;;
    c) codec="$OPTARG" ;;
    T) add_ts=false ;;
    z) make_zip=true ;;
    o) outdir="$OPTARG" ;;
    I) ignore_file="$OPTARG" ;;
    E) disable_excludes=true ;;
    h) usage; exit 0 ;;
    :) error "Option -$OPTARG requiert un argument."; usage; exit 1 ;;
    \?) error "Option inconnue: -$OPTARG"; usage; exit 1 ;;
  esac
done

if [[ ! -d "$src" ]]; then
  die "'$src' n'est pas un dossier."
fi

src_real="$(realpath "$src")"

outdir="${outdir:-$(dirname "$src_real")}"
mkdir -p "$outdir"

default_base="$(basename "$src_real")"
base="${base:-$default_base}"

suffix=""
if $add_ts; then
  suffix="_$(date +%Y%m%d_%H%M)"
fi

parent="$(dirname "$src_real")"
name="$(basename "$src_real")"

# Exclusions "dev" (liste par defaut)
EXCLUDES=(
  ".svn" ".hg"
  ".DS_Store" "Thumbs.db"

  "node_modules" "node_modules/**"

  "__pycache__" "**/__pycache__"
  "*.pyc" "*.pyo"
  ".pytest_cache" ".mypy_cache" ".ruff_cache"

  ".venv" "venv" "env"

  ".idea" ".vscode"

  "dist" "build" "*.egg-info"
)

# Construit les args d'exclusion tar/zip (si activees)
tar_exclude_args=()
zip_exclude_args=()

if ! $disable_excludes; then
  for p in "${EXCLUDES[@]}"; do
    tar_exclude_args+=( "--exclude=$p" )
    zip_exclude_args+=( "-x" "${name}/${p}" )
  done

  if [[ -n "$ignore_file" ]]; then
    if [[ ! -f "$ignore_file" ]]; then
      error "Fichier d'exclusions introuvable: $ignore_file"
      exit 4
    fi

    # tar: support natif
    tar_exclude_args+=( "--exclude-from=$ignore_file" )

    # zip: lecture ligne par ligne (ignore vides + commentaires)
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      zip_exclude_args+=( "-x" "${name}/${line}" )
    done < "$ignore_file"
  fi
fi

case "$codec" in
  xz)  tar_ext="tar.xz";  compress_cmd=(xz -T0 -c) ;;
  gz)  tar_ext="tar.gz";  compress_cmd=(gzip -c) ;;
  bz2) tar_ext="tar.bz2"; compress_cmd=(bzip2 -c) ;;
  zst) tar_ext="tar.zst"; compress_cmd=(zstd -T0 -c --long) ;;
  *)
    error "Codec invalide '$codec' (attendu: xz|gz|bz2|zst)."
    exit 2
    ;;
esac

tar_out="${outdir%/}/${base}${suffix}.${tar_ext}"

info "Source      : $src_real"
info "Archive     : $tar_out"
info "Codec       : ${BOLD}${codec}${RESET}"
echo ""

cleanup_tar() {
  rm -f "$tar_out"
  error "Interruption ou erreur — archive incomplète supprimée."
  exit 1
}
trap cleanup_tar ERR INT TERM

info "Compression en cours..."
if command -v pv >/dev/null 2>&1; then
  tar --create --ignore-failed-read "${tar_exclude_args[@]}" \
      -C "$parent" "$name" \
    | pv -N "Pack" \
    | "${compress_cmd[@]}" > "$tar_out"
else
  warn "Installez 'pv' (apt install pv) pour une barre de progression."
  tar --create \
      --ignore-failed-read \
      --file="$tar_out" \
      --use-compress-program="${compress_cmd[*]}" \
      --checkpoint=500 \
      --checkpoint-action='ttyout=    → bloc %d\r' \
      "${tar_exclude_args[@]}" \
      -C "$parent" \
      "$name"
  echo ""
fi

trap - ERR INT TERM

tar_size=$(du -sh "$tar_out" | cut -f1)
success "Archive : ${BOLD}${tar_out}${RESET} (${tar_size})"

if $make_zip; then
  if ! command -v zip >/dev/null 2>&1; then
    error "'zip' n'est pas installé (ex: sudo apt install zip)."
    exit 3
  fi

  zip_out="${outdir%/}/${base}${suffix}.zip"

  cleanup_zip() {
    rm -f "$zip_out"
    error "Interruption ou erreur — zip incomplet supprimé."
    exit 1
  }
  trap cleanup_zip ERR INT TERM

  info "Zip en cours...   : $zip_out"
  (cd "$parent" && zip -rq9 "$zip_out" "$name" "${zip_exclude_args[@]}")

  trap - ERR INT TERM

  zip_size=$(du -sh "$zip_out" | cut -f1)
  success "Zip     : ${BOLD}${zip_out}${RESET} (${zip_size})"
fi
