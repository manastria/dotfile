#!/usr/bin/env bash
# install-wezterm.sh — installe WezTerm sur XUbuntu via le dépôt APT officiel
# Usage : sudo bash install-wezterm.sh
# Testé sur XUbuntu 25.10 (compatible grâce au sélecteur générique du dépôt fury.io)

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "Ce script doit être lancé avec sudo." >&2
  exit 1
fi

echo "==> Ajout de la clé GPG WezTerm…"
curl -fsSL https://apt.fury.io/wez/gpg.key \
  | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
chmod 644 /usr/share/keyrings/wezterm-fury.gpg

echo "==> Ajout du dépôt APT WezTerm…"
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
  | tee /etc/apt/sources.list.d/wezterm.list

echo "==> Mise à jour des dépôts…"
apt update

echo "==> Installation de WezTerm…"
apt install -y wezterm

echo ""
echo "==> WezTerm installé : $(wezterm --version)"
echo ""
echo "==> Installation du terminfo wezterm pour l'utilisateur courant…"
# Installe l'entrée terminfo dans ~/.terminfo/ de l'utilisateur qui a lancé sudo
REAL_USER="${SUDO_USER:-$USER}"
sudo -u "$REAL_USER" bash -c 'wezterm tcl | tic -x -'
echo "    terminfo installé dans ~${REAL_USER}/.terminfo/"

echo ""
echo "Pensez à placer votre ~/.wezterm.lua et à lancer wezterm."
