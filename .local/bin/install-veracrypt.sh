#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "Cette procédure est prévue pour Debian/Ubuntu (apt)." >&2
    exit 1
fi

# --- prérequis -------------------------------------------------------------
echo "[1/4] Installation des prérequis…"
apt-get install -y software-properties-common

# --- dépôt PPA -------------------------------------------------------------
echo "[2/4] Ajout du dépôt PPA Unit193/encryption…"
PPA="ppa:unit193/encryption"

if apt-cache policy 2>/dev/null | grep -q "unit193/encryption"; then
    echo "  - Dépôt déjà présent, étape ignorée."
else
    add-apt-repository -y "$PPA"
fi

# --- installation ----------------------------------------------------------
echo "[3/4] Mise à jour des index…"
apt-get update -qq

echo "[4/4] Installation de VeraCrypt…"
apt-get install -y veracrypt

# --- fin -------------------------------------------------------------------
cat <<'EOF'

✅ VeraCrypt est installé.

Lancer l'interface graphique :
  veracrypt

Créer un volume chiffré (CLI) :
  veracrypt --text --create

Monter un volume existant :
  veracrypt --text /chemin/vers/volume /point/de/montage

Démonter tous les volumes :
  veracrypt --text --dismount

EOF
