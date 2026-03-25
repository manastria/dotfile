#!/usr/bin/env bash
# install-drawio.sh — Installe ou met à jour draw.io Desktop (.deb) depuis GitHub
# Usage : sudo ./install-drawio.sh
#         sudo ./install-drawio.sh 29.6.1    # version spécifique

set -euo pipefail

# ─── Vérifications ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "❌ Ce script doit être lancé avec sudo."
    exit 1
fi

for cmd in curl jq dpkg apt-get; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ Dépendance manquante : $cmd"
        exit 1
    fi
done

# ─── Architecture ────────────────────────────────────────────────
ARCH=$(dpkg --print-architecture)  # amd64 ou arm64

# ─── Version installée vs version cible ──────────────────────────
INSTALLED=$(dpkg-query -W -f='${Version}' drawio 2>/dev/null || echo "non installé")

if [[ -n "${1:-}" ]]; then
    TARGET="$1"
    RELEASE_URL="https://api.github.com/repos/jgraph/drawio-desktop/releases/tags/v${TARGET}"
else
    RELEASE_URL="https://api.github.com/repos/jgraph/drawio-desktop/releases/latest"
    TARGET=$(curl -fsSL "$RELEASE_URL" | jq -r '.tag_name' | sed 's/^v//')
fi

echo "╔══════════════════════════════════════════╗"
echo "║         draw.io Desktop — Install        ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Installée : ${INSTALLED}"
echo "║  Cible     : ${TARGET}"
echo "║  Arch      : ${ARCH}"
echo "╚══════════════════════════════════════════╝"

if [[ "$INSTALLED" == "$TARGET" ]]; then
    echo "✅ draw.io ${TARGET} est déjà installé."
    exit 0
fi

# ─── Téléchargement ──────────────────────────────────────────────
DEB_NAME="drawio-${ARCH}-${TARGET}.deb"
DEB_URL="https://github.com/jgraph/drawio-desktop/releases/download/v${TARGET}/${DEB_NAME}"
TMP_DIR=$(mktemp -d)
DEB_PATH="${TMP_DIR}/${DEB_NAME}"

echo "⬇  Téléchargement de ${DEB_URL} …"
if ! curl -fSL --progress-bar -o "$DEB_PATH" "$DEB_URL"; then
    echo "❌ Échec du téléchargement. Vérifiez la version et l'architecture."
    echo "   Releases : https://github.com/jgraph/drawio-desktop/releases"
    rm -rf "$TMP_DIR"
    exit 1
fi

# ─── Installation ────────────────────────────────────────────────
echo "📦 Installation …"
dpkg -i "$DEB_PATH" || apt-get install -f -y

# ─── Nettoyage ───────────────────────────────────────────────────
rm -rf "$TMP_DIR"

# ─── Vérification ────────────────────────────────────────────────
NEW_VERSION=$(dpkg-query -W -f='${Version}' drawio 2>/dev/null || echo "???")
echo ""
echo "✅ draw.io ${NEW_VERSION} installé."
echo "   Lancer : drawio"
echo "   Export : drawio --export --format svg --output out.svg fichier.drawio"
