#!/usr/bin/env bash
set -euo pipefail

# --- vérifications préalables ---------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
    echo "curl est requis pour ce script." >&2
    exit 1
fi

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

# --- version déjà installée ? ---------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
    CURRENT=$(zoxide --version | awk '{print $2}')
    echo "zoxide ${CURRENT} déjà présent dans $(command -v zoxide)."
fi

# --- récupération de la dernière version ----------------------------------
echo "[1/3] Récupération de la dernière version zoxide…"
LATEST=$(curl -fsSL https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest \
    | grep '"tag_name"' \
    | sed 's/.*"v\?\([^"]*\)".*/\1/')

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH_TAG="x86_64-unknown-linux-musl" ;;
    aarch64) ARCH_TAG="aarch64-unknown-linux-musl" ;;
    armv7l)  ARCH_TAG="armv7-unknown-linux-musleabihf" ;;
    *)
        echo "Architecture non supportée : ${ARCH}" >&2
        exit 1
        ;;
esac

TARBALL="zoxide-${LATEST}-${ARCH_TAG}.tar.gz"
URL="https://github.com/ajeetdsouza/zoxide/releases/download/v${LATEST}/${TARBALL}"

# --- téléchargement et extraction ----------------------------------------
echo "[2/3] Téléchargement de zoxide ${LATEST} (${ARCH_TAG})…"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL -o "${TMP_DIR}/${TARBALL}" "$URL"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR"

# --- installation --------------------------------------------------------
echo "[3/3] Installation dans ${INSTALL_DIR}…"
install -m 0755 "${TMP_DIR}/zoxide" "${INSTALL_DIR}/zoxide"

# --- vérification --------------------------------------------------------
INSTALLED=$(zoxide --version | awk '{print $2}')

cat <<EOF

✅ zoxide ${INSTALLED} installé dans ${INSTALL_DIR}/zoxide

L'intégration shell (commandes z et zi) est activée automatiquement
via les dotfiles (.shellrc/rc.d/05-navigation.sh).

Commandes disponibles :
  z motif    — saut rapide vers un répertoire fréquent
  zi motif   — sélection interactive fzf (répertoires fréquents)
  zi         — liste complète → sélection fzf

EOF
