#!/usr/bin/env bash
# install-npm.sh — Installe npm (via Node.js) sur Debian/Ubuntu
# Usage:
#   sudo ./install-npm.sh                # NodeSource LTS (recommandé)
#   sudo ./install-npm.sh --method apt   # Dépôts officiels Debian/Ubuntu
#   sudo ./install-npm.sh --node 22      # NodeSource 22.x
#   sudo ./install-npm.sh --node current # NodeSource "current"

set -euo pipefail

METHOD="nodesource"   # nodesource | apt
NODE_SPEC="lts"       # lts | current | <major> ex: 22

# --- Parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      METHOD="${2:-}"; shift 2;;
    --node)
      NODE_SPEC="${2:-}"; shift 2;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0;;
    *)
      echo "Option inconnue: $1" >&2; exit 1;;
  esac
done

# --- Checks ------------------------------------------------------------------
if ! command -v apt-get >/dev/null 2>&1; then
  echo "Ce script nécessite un système basé sur APT (Debian/Ubuntu)." >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Merci d'exécuter en root (ex: sudo $0 ...)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# --- Fonctions ---------------------------------------------------------------
install_via_apt() {
  apt-get update -y
  # Sur Debian/Ubuntu récents, npm est un paquet séparé.
  apt-get install -y nodejs npm
  # Compat: si /usr/bin/node n'existe pas (vieux Debian), créer un lien.
  if ! command -v node >/dev/null 2>&1 && command -v nodejs >/dev/null 2>&1; then
    ln -sf /usr/bin/nodejs /usr/bin/node
  fi
}

install_via_nodesource() {
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  case "$NODE_SPEC" in
    lts)      SETUP="setup_lts.x" ;;
    current)  SETUP="setup_current.x" ;;
    ''|*[!0-9]*) # non numérique (déjà géré au-dessus)
      echo "Valeur --node invalide: $NODE_SPEC" >&2; exit 1 ;;
    *)        SETUP="setup_${NODE_SPEC}.x" ;; # ex: setup_22.x
  esac

  # Ajoute le dépôt NodeSource (installe la clé, la source APT, etc.)
  curl -fsSL "https://deb.nodesource.com/${SETUP}" | bash -
  apt-get install -y nodejs
}

# --- Go ----------------------------------------------------------------------
case "$METHOD" in
  apt)        install_via_apt ;;
  nodesource) install_via_nodesource ;;
  *) echo "Méthode inconnue: $METHOD (attendu: nodesource | apt)" >&2; exit 1;;
esac

echo
echo "✔ Installation terminée."
echo -n "node: ";  command -v node  >/dev/null && node  -v || echo "non trouvé"
echo -n "npm:  ";  command -v npm   >/dev/null && npm   -v || echo "non trouvé"
