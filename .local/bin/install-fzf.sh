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
if command -v fzf >/dev/null 2>&1; then
    CURRENT=$(fzf --version | awk '{print $1}')
    echo "fzf ${CURRENT} déjà présent dans $(command -v fzf)."
fi

# --- récupération de la dernière version ----------------------------------
echo "[1/3] Récupération de la dernière version fzf…"
LATEST=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest \
    | grep '"tag_name"' \
    | cut -d '"' -f 4 \
    | ltrim -c 'v' 2>/dev/null \
    || curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest \
    | grep '"tag_name"' \
    | sed 's/.*"v\?\([^"]*\)".*/\1/')

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH_TAG="linux_amd64" ;;
    aarch64) ARCH_TAG="linux_arm64" ;;
    armv7l)  ARCH_TAG="linux_armv7" ;;
    *)
        echo "Architecture non supportée : ${ARCH}" >&2
        exit 1
        ;;
esac

TARBALL="fzf-${LATEST}-${ARCH_TAG}.tar.gz"
URL="https://github.com/junegunn/fzf/releases/download/v${LATEST}/${TARBALL}"

# --- téléchargement et extraction ----------------------------------------
echo "[2/3] Téléchargement de fzf ${LATEST} (${ARCH_TAG})…"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL -o "${TMP_DIR}/${TARBALL}" "$URL"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR"

# --- installation --------------------------------------------------------
echo "[3/3] Installation dans ${INSTALL_DIR}…"
install -m 0755 "${TMP_DIR}/fzf" "${INSTALL_DIR}/fzf"

# --- vérification --------------------------------------------------------
INSTALLED=$(fzf --version | awk '{print $1}')

cat <<EOF

✅ fzf ${INSTALLED} installé dans ${INSTALL_DIR}/fzf

L'intégration shell (complétion + raccourcis clavier) est activée
automatiquement via les dotfiles (.fzf.bash / .fzf.zsh).

Raccourcis disponibles dans le shell :
  Ctrl+R  — recherche dans l'historique
  Ctrl+T  — recherche de fichiers (colle le résultat)
  Alt+C   — cd interactif dans un sous-répertoire

EOF
