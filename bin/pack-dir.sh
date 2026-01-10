#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  pack-dir.sh <dossier> [options]

Options:
  -b <nom_base>        Nom de base (défaut: nom du dossier)
  -c <xz|gz|bz2|zst>   Codec tar (défaut: xz)
  -t                  Ajoute date+heure: _YYYY-MM-DD_HHMMSS
  -z                  Génère aussi un .zip (en plus du tar compressé)
  -o <dir_sortie>      Répertoire de sortie (défaut: .)
  -h                  Aide

Exemples:
  ./pack-dir.sh ./TP
  ./pack-dir.sh ./TP -t
  ./pack-dir.sh ./TP -t -z
  ./pack-dir.sh ./TP -c gz -t -o ./out
  ./pack-dir.sh ./TP -b elec-ccf -t -z
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
codec="xz"
add_ts=false
make_zip=false
outdir="."

while getopts ":b:c:tzo:h" opt; do
  case "$opt" in
    b) base="$OPTARG" ;;
    c) codec="$OPTARG" ;;
    t) add_ts=true ;;
    z) make_zip=true ;;
    o) outdir="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requiert un argument." >&2; usage; exit 1 ;;
    \?) echo "Option inconnue: -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -d "$src" ]]; then
  echo "Erreur: '$src' n'est pas un dossier." >&2
  exit 1
fi

mkdir -p "$outdir"

default_base="$(basename "$src")"
base="${base:-$default_base}"

suffix=""
if $add_ts; then
  suffix="_$(date +%F_%H%M%S)"
fi

# Archive relative (pas de chemin absolu)
parent="$(dirname "$src")"
name="$(basename "$src")"

case "$codec" in
  xz)
    tar_ext="tar.xz"
    tar_cmd=(tar -cJf)
    ;;
  gz)
    tar_ext="tar.gz"
    tar_cmd=(tar -czf)
    ;;
  bz2)
    tar_ext="tar.bz2"
    tar_cmd=(tar -cjf)
    ;;
  zst)
    tar_ext="tar.zst"
    tar_cmd=(tar --zstd -cf)
    ;;
  *)
    echo "Erreur: codec invalide '$codec' (attendu: xz|gz|bz2|zst)." >&2
    exit 2
    ;;
esac

tar_out="${outdir%/}/${base}${suffix}.${tar_ext}"
"${tar_cmd[@]}" "$tar_out" -C "$parent" "$name"
echo "OK -> $tar_out"

if $make_zip; then
  if ! command -v zip >/dev/null 2>&1; then
    echo "Erreur: 'zip' n'est pas installé (ex: sudo apt install zip)." >&2
    exit 3
  fi
  zip_out="${outdir%/}/${base}${suffix}.zip"
  (cd "$parent" && zip -rq9 "$zip_out" "$name")
  echo "OK -> $zip_out"
fi
