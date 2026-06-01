#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Cette procédure est prévue pour Debian/Ubuntu (apt)." >&2
  exit 1
fi

# --- add Syncthing apt repo (keyring + source) ----------------------------
echo "[1/3] Installation de la clé du dépôt Syncthing…"
install -d -m 0755 /usr/share/keyrings

# Essaye la clé .gpg, puis bascule sur .txt (compat)
if curl -fsSL https://syncthing.net/release-key.gpg -o /tmp/syncthing-release-key.gpg; then
  gpg --dearmor </tmp/syncthing-release-key.gpg | tee /usr/share/keyrings/syncthing-archive-keyring.gpg >/dev/null
  rm -f /tmp/syncthing-release-key.gpg
else
  curl -fsSL https://syncthing.net/release-key.txt | gpg --dearmor | tee /usr/share/keyrings/syncthing-archive-keyring.gpg >/dev/null
fi

echo "[2/3] Déclaration du dépôt apt Syncthing…"
SOURCE_LINE='deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable'
LIST_FILE="/etc/apt/sources.list.d/syncthing.list"

if [ -f "$LIST_FILE" ] && grep -q "apt.syncthing.net" "$LIST_FILE"; then
  echo "  - Dépôt déjà présent (${LIST_FILE})."
else
  echo "$SOURCE_LINE" | tee "$LIST_FILE" >/dev/null
fi

# --- install ---------------------------------------------------------------
echo "[3/3] Mise à jour des index et installation…"
apt-get update -qq
apt-get install -y syncthing

# --- finish (no enable) ----------------------------------------------------
cat <<'EOF'

✅ Syncthing est installé.
ℹ️  Le service **n'est pas activé** au démarrage (comme demandé).

Démarrer ponctuellement pour l'utilisateur courant :
  systemctl --user start syncthing
  # Interface Web : http://localhost:8384

Lancer en tâche de fond sans systemd :
  syncthing >/dev/null 2>&1 &

Arrêter :
  systemctl --user stop syncthing
  # ou : pkill syncthing

(Pare-feu ufw si nécessaire) :
  sudo ufw allow 22000/tcp
  sudo ufw allow 21027/udp

EOF

