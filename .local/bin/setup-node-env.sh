#!/usr/bin/env bash
# setup-node-env.sh — Configure l'environnement Node.js pour l'utilisateur courant
# À exécuter SANS sudo. Étape 2/2 — après install-node.sh.
#
# Ce script :
#   1. Configure ~/.npmrc (prefix, options recommandées)
#   2. Génère ~/.shellrc/rc.d/node.sh (PATH vers les packages globaux)
#   3. Installe les packages npm globaux utiles
#
# Usage:
#   ./setup-node-env.sh          # configuration complète
#   ./setup-node-env.sh --dry-run  # affiche ce qui serait fait, sans modifier

set -euo pipefail

DRY_RUN=false

# --- Parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 1 ;;
  esac
done

# --- Pré-requis --------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  echo "Ne pas exécuter en root. Lancez sans sudo." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm n'est pas installé. Exécutez d'abord : sudo ./install-node.sh" >&2
  exit 1
fi

# --- Helpers -----------------------------------------------------------------
info()    { echo "  [info]  $*"; }
action()  { echo "  [→]     $*"; }
skip()    { echo "  [skip]  $*"; }
dry()     { echo "  [dry]   $*"; }

run() {
  # Exécute une commande ou l'affiche en dry-run
  if $DRY_RUN; then
    dry "$*"
  else
    eval "$*"
  fi
}

# --- 1. Lire le prefix existant ----------------------------------------------
echo
echo "=== 1/3 · Configuration ~/.npmrc ==="

NPMRC="$HOME/.npmrc"
DEFAULT_PREFIX="$HOME/.npm-packages"

# Lire le prefix déjà défini dans ~/.npmrc, sinon utiliser la valeur par défaut
if [[ -f "$NPMRC" ]] && grep -q '^prefix=' "$NPMRC" 2>/dev/null; then
  NPM_PREFIX="$(grep '^prefix=' "$NPMRC" | cut -d= -f2)"
  info "prefix existant détecté : $NPM_PREFIX"
else
  NPM_PREFIX="$DEFAULT_PREFIX"
  info "aucun prefix trouvé, valeur par défaut : $NPM_PREFIX"
fi

# Construire le contenu ~/.npmrc souhaité
NPMRC_CONTENT="# Répertoire d'installation des packages globaux (évite sudo npm install -g)
prefix=${NPM_PREFIX}

# Désactive les messages de financement après chaque install
fund=false

# Désactive l'audit automatique (ralentit les installs)
# Lancer manuellement : npm audit
audit=false

# Fixe les versions exactes dans package.json (1.2.3 au lieu de ^1.2.3)
# Garantit la reproductibilité des projets dans le temps
save-exact=true
"

if $DRY_RUN; then
  dry "Contenu de ~/.npmrc qui serait écrit :"
  echo "$NPMRC_CONTENT" | sed 's/^/      /'
else
  echo "$NPMRC_CONTENT" > "$NPMRC"
  action "~/.npmrc mis à jour"
fi

# Créer le répertoire prefix si nécessaire
if [[ ! -d "$NPM_PREFIX" ]]; then
  run "mkdir -p '$NPM_PREFIX'"
  action "Répertoire créé : $NPM_PREFIX"
else
  skip "Répertoire déjà existant : $NPM_PREFIX"
fi

# --- 2. Configurer le PATH ---------------------------------------------------
echo
echo "=== 2/3 · Configuration PATH (~/.shellrc/rc.d/node.sh) ==="

SHELLRC_DIR="$HOME/.shellrc/rc.d"
NODE_SH="$SHELLRC_DIR/node.sh"

NODE_SH_CONTENT="# node.sh — Ajout des binaires npm globaux au PATH
# Généré par setup-node-env.sh — ne pas éditer manuellement
# Compatible bash et zsh (chargé via ~/.shellrc/rc.d/)

NPM_PREFIX=\"\$(npm config get prefix 2>/dev/null)\"
if [[ -n \"\$NPM_PREFIX\" && -d \"\${NPM_PREFIX}/bin\" ]]; then
  case \":\$PATH:\" in
    *\":\${NPM_PREFIX}/bin:\"*) ;;  # déjà présent, on n'ajoute pas
    *) export PATH=\"\${NPM_PREFIX}/bin:\$PATH\" ;;
  esac
fi
"

run "mkdir -p '$SHELLRC_DIR'"

if $DRY_RUN; then
  dry "Contenu de $NODE_SH qui serait écrit :"
  echo "$NODE_SH_CONTENT" | sed 's/^/      /'
else
  echo "$NODE_SH_CONTENT" > "$NODE_SH"
  action "$NODE_SH créé"
fi

# --- 3. Packages globaux -----------------------------------------------------
echo
echo "=== 3/3 · Installation des packages globaux ==="

# Liste des packages à installer globalement
GLOBAL_PACKAGES=(
  # Qualité de code
  prettier          # Formateur de code universel (JS, TS, CSS, HTML, MDX...)
  eslint            # Linter JavaScript/TypeScript

  # Build tools (souvent requis par des projets legacy ou des cours)
  gulp-cli          # CLI pour Gulp (le package gulp lui-même s'installe par projet)
  grunt-cli         # CLI pour Grunt (idem)

  # Gestion des dépendances
  npm-check-updates # ncu : vérifie les mises à jour disponibles dans package.json

  # Utilitaires
  tldr              # Pages de man simplifiées (ex : tldr npm)
)

# Récupérer les packages déjà installés globalement
if ! $DRY_RUN; then
  INSTALLED="$(npm list -g --depth=0 --parseable 2>/dev/null | xargs -I{} basename {} | tail -n +2)"
fi

for pkg in "${GLOBAL_PACKAGES[@]}"; do
  # Ignorer les lignes vides et commentaires
  [[ -z "$pkg" || "$pkg" == \#* ]] && continue

  if $DRY_RUN; then
    dry "npm install -g $pkg"
  else
    # Extraire le nom sans version éventuelle pour la vérification
    pkg_name="${pkg%%@*}"
    if echo "$INSTALLED" | grep -q "^${pkg_name}$"; then
      skip "$pkg (déjà installé)"
    else
      action "Installation : $pkg"
      npm install -g "$pkg"
    fi
  fi
done

# --- Résumé ------------------------------------------------------------------
echo
if $DRY_RUN; then
  echo "✔ Dry-run terminé. Relancez sans --dry-run pour appliquer."
else
  echo "✔ Environnement Node.js configuré."
  echo
  NODE_BIN="$(npm config get prefix 2>/dev/null)/bin/node"
  printf "  node    : %s\n" "$($NODE_BIN -v 2>/dev/null || echo 'non trouvé')"
  printf "  npm     : %s\n" "$(npm -v  2>/dev/null || echo 'non trouvé')"
  printf "  prefix  : %s\n" "$NPM_PREFIX"
  echo
  echo "→ Pour activer le PATH dans le shell courant :"
  echo "     source ~/.shellrc/rc.d/node.sh"
  echo "  (les prochains shells le chargeront automatiquement)"
fi
