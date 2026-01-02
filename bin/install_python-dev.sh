#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install-python-dev.sh
#
# Installe un environnement de développement Python "passe-partout" sur :
#   - Debian / Ubuntu / Xubuntu (toutes variantes basées sur APT)
#
# Objectifs :
#   - pyenv (compilation de versions de Python dans ~/.pyenv)
#   - pipx (installé dans un venv dédié pour éviter les blocages PEP 668)
#   - poetry (installé/maintenu via pipx)
#   - configuration shell via ~/.shellrc/rc.d (sans modifier ~/.bashrc ou ~/.zshrc)
#   - config globale poetry : virtualenvs.in-project = true
#
# Usage :
#   chmod +x install-python-dev.sh
#   ./install-python-dev.sh
#
# Après exécution :
#   - Ouvre un nouveau terminal (ou source le fichier rc créé)
#   - Exemple :
#       pyenv install 3.12.7
#       pyenv global 3.12.7
#
# Notes maintenance :
#   - Ce script est conçu pour être relancé : il met à jour pyenv/plugins,
#     réinstalle/upgrade pipx et poetry si besoin, et réécrit le fichier rc.
# -----------------------------------------------------------------------------

log() { printf "\n[%s] %s\n" "$(date +'%F %T')" "$*"; }

# -----------------------------------------------------------------------------
# Sudo / root handling
# -----------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Erreur: 'sudo' est requis (ou exécute le script en root)."
    exit 1
  fi
fi

export DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# OS detection (info only)
# -----------------------------------------------------------------------------
OS_NAME="unknown"
OS_VER="unknown"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_NAME="${NAME:-unknown}"
  OS_VER="${VERSION_ID:-unknown}"
fi
log "Detected: ${OS_NAME} ${OS_VER}"

# -----------------------------------------------------------------------------
# Helper: install uniquement les paquets disponibles (utile Debian vs Ubuntu)
# -----------------------------------------------------------------------------
apt_install_available() {
  local -a wanted=("$@")
  local -a available=()

  for pkg in "${wanted[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    fi
  done

  if [ "${#available[@]}" -gt 0 ]; then
    $SUDO apt-get install -y "${available[@]}"
  fi
}

# -----------------------------------------------------------------------------
# 1) Update APT
# -----------------------------------------------------------------------------
log "1) apt update"
$SUDO apt-get update -y

# -----------------------------------------------------------------------------
# 2) Base packages (Python système minimal + outils)
#   - python3-venv est indispensable (pipx venv dédié + éventuels venvs)
#   - python3-pip est utile mais pas strictement nécessaire ici
# -----------------------------------------------------------------------------
log "2) Base packages (python3 + venv, git, curl...)"
apt_install_available \
  ca-certificates curl git \
  build-essential make \
  python3 python3-venv

# Optionnel mais pratique
apt_install_available python3-pip

# -----------------------------------------------------------------------------
# 3) Dépendances build pour compiler Python via pyenv
#   - Liste volontairement large, filtrée selon la distro
# -----------------------------------------------------------------------------
log "3) Build dependencies for pyenv (compilation de Python)"
apt_install_available \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  libffi-dev liblzma-dev \
  libgdbm-dev libnss3-dev \
  xz-utils tk-dev \
  libncursesw5-dev libncurses5-dev \
  wget llvm

# -----------------------------------------------------------------------------
# 4) pyenv (core) dans ~/.pyenv
# -----------------------------------------------------------------------------
PYENV_ROOT="${HOME}/.pyenv"

log "4) Install/Update pyenv in ${PYENV_ROOT}"
if [ ! -d "$PYENV_ROOT" ]; then
  git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
else
  git -C "$PYENV_ROOT" pull --ff-only || true
fi

# -----------------------------------------------------------------------------
# 5) pyenv-virtualenv (plugin optionnel mais utile)
# -----------------------------------------------------------------------------
log "5) Install/Update pyenv-virtualenv plugin"
if [ ! -d "${PYENV_ROOT}/plugins/pyenv-virtualenv" ]; then
  git clone https://github.com/pyenv/pyenv-virtualenv.git "${PYENV_ROOT}/plugins/pyenv-virtualenv"
else
  git -C "${PYENV_ROOT}/plugins/pyenv-virtualenv" pull --ff-only || true
fi

# -----------------------------------------------------------------------------
# 6) pipx dans un venv dédié
#   Pourquoi ?
#   - Sur Debian/Ubuntu récents, l'installation pip "dans le Python système"
#     peut être bloquée (PEP 668 / externally-managed).
#   - pipx dans son propre venv est stable, reproductible et portable.
# -----------------------------------------------------------------------------
log "6) Install/Update pipx in a dedicated venv (robuste Debian/Ubuntu récents)"

PIPX_VENV="${HOME}/.local/venvs/pipx"
PIPX_VENV_DIR="$(dirname "$PIPX_VENV")"

mkdir -p "$PIPX_VENV_DIR" "${HOME}/.local/bin"

if [ ! -d "$PIPX_VENV" ]; then
  python3 -m venv "$PIPX_VENV"
fi

# Upgrade pip + pipx dans ce venv
"$PIPX_VENV/bin/python" -m pip install -U pip >/dev/null
"$PIPX_VENV/bin/python" -m pip install -U pipx >/dev/null

# Expose pipx via ~/.local/bin (répertoire "user bin" standard)
ln -sf "$PIPX_VENV/bin/pipx" "${HOME}/.local/bin/pipx"

# Variables d'environnement pipx (emplacements "standard")
export PATH="${HOME}/.local/bin:${PATH}"
export PIPX_HOME="${HOME}/.local/pipx"
export PIPX_BIN_DIR="${HOME}/.local/bin"

# Optionnel: initialise pipx (ne casse rien si déjà ok)
# (peut tenter d'éditer des rc classiques : on ignore les effets)
pipx ensurepath >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# 7) Poetry via pipx (install / upgrade)
#   - Si poetry est déjà présent mais pas géré par pipx : on avertit.
#   - Si poetry est géré par pipx : upgrade.
# -----------------------------------------------------------------------------
log "7) Install / upgrade Poetry via pipx"

if command -v poetry >/dev/null 2>&1; then
  if pipx list 2>/dev/null | grep -qE 'package poetry\b'; then
    pipx upgrade poetry
    log "Poetry (pipx): $(poetry --version)"
  else
    log "Poetry est déjà présent mais ne semble pas installé via pipx."
    log "Conseil: désinstaller l'autre Poetry puis relancer ce script (ou: pipx install poetry)."
    log "Poetry actuel: $(poetry --version)"
  fi
else
  pipx install poetry
  log "Poetry installé: $(poetry --version)"
fi

# -----------------------------------------------------------------------------
# 7bis) Config globale Poetry
#   - virtualenvs.in-project = true (créera .venv dans chaque projet)
#   - On ne dépend pas du shell rc : on appelle poetry directement ici.
# -----------------------------------------------------------------------------
log "7bis) Configure Poetry globally: virtualenvs.in-project = true"
if command -v poetry >/dev/null 2>&1; then
  poetry config virtualenvs.in-project true
else
  log "Poetry non disponible => config globale ignorée (ne devrait pas arriver)."
fi

# -----------------------------------------------------------------------------
# 8) Shell configuration via ~/.shellrc/rc.d
#   - Ton .bashrc/.zshrc charge déjà *.sh depuis ~/.shellrc/rc.d
#   - On dépose un fichier unique, réécrit à chaque exécution (idempotent)
# -----------------------------------------------------------------------------
log "8) Shell configuration via ~/.shellrc/rc.d (sans modifier .bashrc/.zshrc)"

RC_DIR="${HOME}/.shellrc/rc.d"
RC_FILE="${RC_DIR}/20-python-dev.sh"
mkdir -p "$RC_DIR"

cat > "$RC_FILE" <<'EOF'
# python-dev: pyenv + pipx + poetry
# Fichier chargé via ~/.shellrc/rc.d/*.sh
#
# Objectif :
#   - Rendre disponibles pyenv/pipx/poetry dans bash et zsh
#   - Ne dépendre ni de ~/.bashrc ni de ~/.zshrc (déjà gérés ailleurs)

# pipx (binaries) + autres outils user
export PATH="$HOME/.local/bin:$PATH"
export PIPX_HOME="$HOME/.local/pipx"
export PIPX_BIN_DIR="$HOME/.local/bin"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv >/dev/null 2>&1; then
  # Init adapté au shell (bash/zsh)
  if [ -n "${ZSH_VERSION-}" ]; then
    eval "$(pyenv init - zsh)"
    eval "$(pyenv virtualenv-init - zsh)"
  else
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
  fi
fi
EOF

chmod 0644 "$RC_FILE"
log "Wrote: $RC_FILE"

# -----------------------------------------------------------------------------
# Fin / récap
# -----------------------------------------------------------------------------
cat <<'EOF'

Terminé.

À faire maintenant :
  1) Ouvre un nouveau terminal (ou source le fichier):
       source ~/.shellrc/rc.d/20-python-dev.sh

  2) Vérifie:
       pyenv --version
       pipx --version
       poetry --version

Exemple d'installation Python avec pyenv :
  pyenv install 3.12.7
  pyenv global 3.12.7

Poetry (global) est configuré avec:
  poetry config virtualenvs.in-project true

EOF
