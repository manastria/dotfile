#!/usr/bin/env bash
# install-gitkraken.sh — Installation de GitKraken sur Debian/Ubuntu
# Méthode : snap (recommandé) ou .deb pour l'interface graphique,
#            .deb depuis GitHub Releases pour le CLI (gk)
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# Vérification : système 64 bits
if [ "$(uname -m)" != "x86_64" ]; then
    echo "Erreur : GitKraken ne supporte que les systèmes x86_64." >&2
    exit 1
fi

# --- Méthode snap (recommandée : mises à jour automatiques) ---
install_snap() {
    if ! command -v snap &>/dev/null; then
        echo "==> Installation de snapd..."
        apt update -y
        apt install -y snapd
        # Sur Debian, le socket snap peut nécessiter un redémarrage
        # ou l'activation manuelle du service
        systemctl enable --now snapd.socket
        echo "    snapd installé. Si la commande snap échoue,"
        echo "    redémarrez la session ou le système puis relancez."
    fi
    echo "==> Installation de GitKraken via snap..."
    snap install gitkraken --classic
    echo "==> GitKraken installé. Lancez-le avec : gitkraken &"
}

# --- Méthode .deb (alternative) ---
install_deb() {
    local DEB_URL="https://release.gitkraken.com/linux/gitkraken-amd64.deb"
    local TMP_DEB="/tmp/gitkraken-amd64.deb"
    echo "==> Téléchargement de GitKraken (.deb)..."
    wget -O "$TMP_DEB" "$DEB_URL"
    echo "==> Installation (apt gère les dépendances)..."
    apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"
    echo "==> GitKraken installé. Lancez-le avec : gitkraken &"
    echo ""
    echo "⚠  Rappel : sans repo APT, les mises à jour sont manuelles."
    echo "   Relancez ce script pour mettre à jour."
}

# --- GitKraken CLI (gk) ---
install_gk_cli() {
    local TMP_DEB="/tmp/gk_linux_amd64.deb"
    echo "==> Récupération de la dernière version du CLI GitKraken..."
    local LATEST_URL
    LATEST_URL=$(curl -fsSL https://api.github.com/repos/gitkraken/gk-cli/releases/latest \
        | grep '"browser_download_url"' \
        | grep 'linux_amd64.deb' \
        | cut -d '"' -f 4)
    if [ -z "$LATEST_URL" ]; then
        echo "Erreur : impossible de déterminer l'URL de téléchargement." >&2
        exit 1
    fi
    echo "==> Téléchargement de gk CLI..."
    curl -fsSL -o "$TMP_DEB" "$LATEST_URL"
    echo "==> Installation (apt gère les dépendances)..."
    apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"
    echo "==> GitKraken CLI installé. Vérifiez avec : gk --version"
    echo ""
    echo "⚠  Rappel : sans repo APT, les mises à jour sont manuelles."
    echo "   Relancez ce script pour mettre à jour."
}

# --- Choix ---
echo "Que voulez-vous installer ?"
echo "  1) GitKraken (interface graphique) via snap  (recommandé — mises à jour automatiques)"
echo "  2) GitKraken (interface graphique) via .deb  (manuel)"
echo "  3) GitKraken CLI (gk)                        (outil en ligne de commande)"
echo "  4) Les deux : GUI via snap + CLI"
echo "  5) Les deux : GUI via .deb  + CLI"
read -rp "Votre choix [1/2/3/4/5] : " choix

case "$choix" in
    1) install_snap ;;
    2) install_deb ;;
    3) install_gk_cli ;;
    4) install_snap; install_gk_cli ;;
    5) install_deb; install_gk_cli ;;
    *) echo "Choix invalide." >&2; exit 1 ;;
esac
