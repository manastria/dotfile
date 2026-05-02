#!/usr/bin/env bash
# install-node.sh — Installe Node.js sur Debian/Ubuntu
# À exécuter en root (sudo). Étape 1/2 — voir setup-node-env.sh pour l'étape utilisateur.
#
# Usage:
#   sudo ./install-node.sh                # NodeSource LTS (recommandé)
#   sudo ./install-node.sh --method apt   # Dépôts officiels Debian/Ubuntu
#   sudo ./install-node.sh --node 22      # NodeSource 22.x
#   sudo ./install-node.sh --node current # NodeSource "current"

set -euo pipefail

METHOD="nodesource"   # nodesource | apt
NODE_SPEC="lts"       # lts | current | <major> ex: 22

# --- Parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      METHOD="${2:-}"; shift 2 ;;
    --node)
      NODE_SPEC="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,10p' "$0"; exit 0 ;;
    *)
      echo "Option inconnue : $1" >&2; exit 1 ;;
  esac
done

# --- Pré-requis --------------------------------------------------------------
if ! command -v apt-get >/dev/null 2>&1; then
  echo "Ce script nécessite un système basé sur APT (Debian/Ubuntu)." >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Merci d'exécuter en root (ex : sudo $0 ...)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# --- Fonctions ---------------------------------------------------------------
install_via_apt() {
  echo "→ Installation via les dépôts Debian/Ubuntu..."
  apt-get update -y
  apt-get install -y nodejs npm
  # Compat : vieux Debian où node s'appelle nodejs
  if ! command -v node >/dev/null 2>&1 && command -v nodejs >/dev/null 2>&1; then
    ln -sf /usr/bin/nodejs /usr/bin/node
  fi
}

install_via_nodesource() {
  echo "→ Installation via NodeSource (${NODE_SPEC})..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  case "$NODE_SPEC" in
    lts)     SETUP="setup_lts.x" ;;
    current) SETUP="setup_current.x" ;;
    *[!0-9]*)
      echo "Valeur --node invalide : $NODE_SPEC (attendu : lts | current | entier)" >&2
      exit 1 ;;
    *)       SETUP="setup_${NODE_SPEC}.x" ;;  # ex : setup_22.x
  esac

  curl -fsSL "https://deb.nodesource.com/${SETUP}" | bash -
  apt-get install -y nodejs
}

# --- Go ----------------------------------------------------------------------
case "$METHOD" in
  apt)        install_via_apt ;;
  nodesource) install_via_nodesource ;;
  *)
    echo "Méthode inconnue : $METHOD (attendu : nodesource | apt)" >&2
    exit 1 ;;
esac

# --- Résumé ------------------------------------------------------------------
echo
echo "✔ Node.js installé."
printf "  node : %s\n" "$(node -v 2>/dev/null || echo 'non trouvé')"
printf "  npm  : %s\n" "$(npm -v  2>/dev/null || echo 'non trouvé')"
echo
echo "→ Étape suivante (en tant qu'utilisateur, sans sudo) :"
echo "     ./setup-node-env.sh"
