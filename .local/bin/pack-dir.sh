#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pack-dir.sh <dossier> [options]

Par defaut (aligne sur pack-project.sh):
  codec zst, date+heure ajoutee, sortie dans le dossier parent de la source.

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
  ./pack-dir.sh ./TP
  ./pack-dir.sh ./TP -z
  ./pack-dir.sh ./TP -c gz -o ./out
  ./pack-dir.sh ./TP -b elec-ccf -z
  ./pack-dir.sh ./TP -T             # pas de date+heure dans le nom
  ./pack-dir.sh ./TP -I .packignore
  ./pack-dir.sh ./TP -E             # inclut .git, node_modules, etc.

Notes:
  - Le dossier source peut etre relatif ou absolu.
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

# 1er argument: dossier source
if [[ "${1:-}" == "" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

src="${1%/}"
shift

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
    :) echo "Option -$OPTARG requiert un argument." >&2; usage; exit 1 ;;
    \?) echo "Option inconnue: -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -d "$src" ]]; then
  echo "Erreur: '$src' n'est pas un dossier." >&2
  exit 1
fi

outdir="${outdir:-$(dirname "$(realpath "$src")")}"
mkdir -p "$outdir"

default_base="$(basename "$src")"
base="${base:-$default_base}"

suffix=""
if $add_ts; then
  suffix="_$(date +%Y%m%d_%H%M)"
fi

parent="$(dirname "$src")"
name="$(basename "$src")"

# Exclusions "dev" (liste par defaut)
EXCLUDES=(
  ".git" ".git/**" ".svn" ".hg"
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
      echo "Erreur: fichier d'exclusions introuvable: $ignore_file" >&2
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
  xz)  tar_ext="tar.xz";  tar_cmd=(tar -cJf) ;;
  gz)  tar_ext="tar.gz";  tar_cmd=(tar -czf) ;;
  bz2) tar_ext="tar.bz2"; tar_cmd=(tar -cjf) ;;
  zst) tar_ext="tar.zst"; tar_cmd=(tar --zstd -cf) ;;
  *)
    echo "Erreur: codec invalide '$codec' (attendu: xz|gz|bz2|zst)." >&2
    exit 2
    ;;
esac

tar_out="${outdir%/}/${base}${suffix}.${tar_ext}"
"${tar_cmd[@]}" "$tar_out" "${tar_exclude_args[@]}" -C "$parent" "$name"
echo "OK -> $tar_out"

if $make_zip; then
  if ! command -v zip >/dev/null 2>&1; then
    echo "Erreur: 'zip' n'est pas installe (ex: sudo apt install zip)." >&2
    exit 3
  fi

  zip_out="${outdir%/}/${base}${suffix}.zip"
  (cd "$parent" && zip -rq9 "$zip_out" "$name" "${zip_exclude_args[@]}")
  echo "OK -> $zip_out"
fi
