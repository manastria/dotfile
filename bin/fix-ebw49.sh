#!/usr/bin/env bash
# Réglage automatique Epson EB-W49 via VGA avec fallback de modes.
# Usage :
#   fix-ebw49.sh                 # applique le meilleur mode dispo
#   fix-ebw49.sh --only-external # coupe l'écran du portable (évite miroir bridé)
#   fix-ebw49.sh --external-primary  # met l'externe en écran primaire (Xfce)
#   fix-ebw49.sh --dry-run       # n'affiche que ce qui serait fait

set -u -o pipefail

DRYRUN=0
ONLY_EXTERNAL=0
EXTERNAL_PRIMARY=0

for a in "$@"; do
  case "$a" in
    --dry-run) DRYRUN=1 ;;
    --only-external) ONLY_EXTERNAL=1 ;;
    --external-primary) EXTERNAL_PRIMARY=1 ;;
    *) echo "Option inconnue: $a" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$DRYRUN" -eq 1 ]; then
    echo "+ $*"
  else
    "$@"
  fi
}

# Détermine écrans
XRANDR=$(xrandr --query)
INTERNAL=$(printf "%s\n" "$XRANDR" | awk '/ connected primary/{print $1}' | head -n1)
[ -z "${INTERNAL:-}" ] && INTERNAL=$(printf "%s\n" "$XRANDR" | awk '/ connected/{print $1}' | grep -E '^eDP' | head -n1)
[ -z "${INTERNAL:-}" ] && INTERNAL=$(printf "%s\n" "$XRANDR" | awk '/ connected/{print $1}' | head -n1)

EXTERNAL=$(printf "%s\n" "$XRANDR" | awk '/ connected/{print $1}' | grep -v "^${INTERNAL}$" | head -n1)

if [ -z "${EXTERNAL:-}" ]; then
  echo "Aucun écran externe connecté détecté." >&2
  exit 1
fi

echo "Interne  : ${INTERNAL}"
echo "Externe  : ${EXTERNAL}"

# Définition des modelines (hardcodées, évite dépendre de 'cvt' à l'exécution)
# 1080p60 CVT standard
MODE_1080_STD_NAME="1920x1080_60.00"
MODE_1080_STD_LINE='1920x1080_60.00 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync'
# 1080p60 CVT Reduced Blanking (pixel clock plus bas)
MODE_1080_RB_NAME="1920x1080R"
MODE_1080_RB_LINE='1920x1080R 138.50 1920 1968 2000 2080 1080 1083 1088 1111 +hsync -vsync'
# 1366x768@60
MODE_1366_NAME="1366x768_60.00"
MODE_1366_LINE='1366x768_60.00 85.50 1366 1436 1579 1792 768 771 774 798 -hsync +vsync'
# 1280x800@60 (natif EB-W49)
MODE_1280x800_NAME="1280x800_60.00"
MODE_1280x800_LINE='1280x800_60.00 83.50 1280 1344 1480 1680 800 803 809 831 -hsync +vsync'
# 1024x768@60
MODE_1024x768_NAME="1024x768_60.00"
MODE_1024x768_LINE='1024x768_60.00 65.00 1024 1048 1184 1344 768 771 777 806 -hsync -vsync'

ensure_mode() {
  local OUT="$1" NAME="$2" LINE="$3"
  # Ajoute le mode s'il n'existe pas déjà
  if ! xrandr | grep -qE "^\s*${NAME}\b"; then
    echo "Ajout du mode ${NAME}"
    run xrandr --newmode $LINE
  fi
  # Associe le mode à la sortie si besoin
  if ! xrandr | awk "/^${OUT} /,/^$/" | grep -qE "^\s*${NAME}\b"; then
    run xrandr --addmode "$OUT" "$NAME" || true
  fi
}

try_set_mode() {
  local OUT="$1" NAME="$2" LINE="$3"
  ensure_mode "$OUT" "$NAME" "$LINE"
  echo "→ tentative ${OUT} --mode ${NAME}"
  if run xrandr --output "$OUT" --mode "$NAME"; then
    return 0
  else
    return 1
  fi
}

# Option : ne projeter que sur l'externe (évite les contraintes du miroir)
if [ "$ONLY_EXTERNAL" -eq 1 ]; then
  echo "Désactivation de l'écran interne (${INTERNAL})"
  run xrandr --output "$INTERNAL" --off || true
fi

# Fallback du plus exigeant au plus sécure
# 1) 1080p CVT standard → 2) 1080p CVT-RB → 3) 1366x768 → 4) 1280x800 → 5) 1024x768
if try_set_mode "$EXTERNAL" "$MODE_1080_STD_NAME" "$MODE_1080_STD_LINE"; then
  CHOSEN="$MODE_1080_STD_NAME"
elif try_set_mode "$EXTERNAL" "$MODE_1080_RB_NAME" "$MODE_1080_RB_LINE"; then
  CHOSEN="$MODE_1080_RB_NAME"
elif try_set_mode "$EXTERNAL" "$MODE_1366_NAME" "$MODE_1366_LINE"; then
  CHOSEN="$MODE_1366_NAME"
elif try_set_mode "$EXTERNAL" "$MODE_1280x800_NAME" "$MODE_1280x800_LINE"; then
  CHOSEN="$MODE_1280x800_NAME"
elif try_set_mode "$EXTERNAL" "$MODE_1024x768_NAME" "$MODE_1024x768_LINE"; then
  CHOSEN="$MODE_1024x768_NAME"
else
  echo "Aucun des modes n'a pu être appliqué sur ${EXTERNAL}." >&2
  exit 1
fi

echo "Mode appliqué sur ${EXTERNAL} : ${CHOSEN}"

# Option : définir l'externe en PRIMARY (sert à Xfce/panels)
if [ "$EXTERNAL_PRIMARY" -eq 1 ]; then
  echo "Définition de ${EXTERNAL} comme écran primaire"
  run xrandr --output "$EXTERNAL" --primary
fi

exit 0
