#!/usr/bin/env bash
# install-python-dev.sh — Environnement de développement Python (pyenv + pipx + poetry)
# Cible  : Debian / Ubuntu et variantes APT
# Usage  : ./install-python-dev.sh
#
# Installe et configure :
#   - pyenv            : gestionnaire de versions Python (~/.pyenv)
#   - pyenv-virtualenv : plugin virtualenvs pour pyenv
#   - pipx             : gestionnaire d'outils Python isolés (~/.local/venvs/pipx)
#   - poetry           : gestionnaire de projets et dépendances (via pipx)
#
# Idempotent : peut être relancé pour mettre à jour.
# Intégration shell : ~/.shellrc/rc.d/20-python-dev.sh (sans toucher .bashrc/.zshrc)

set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PYENV_ROOT="${HOME}/.pyenv"
readonly PYENV_VENV_PLUGIN="${PYENV_ROOT}/plugins/pyenv-virtualenv"
readonly PIPX_VENV="${HOME}/.local/venvs/pipx"
readonly PIPX_BIN_DIR="${HOME}/.local/bin"
readonly PIPX_HOME_DIR="${HOME}/.local/pipx"
readonly RC_DIR="${HOME}/.shellrc/rc.d"
readonly RC_FILE="${RC_DIR}/20-python-dev.sh"

# Exposition anticipée pour que pyenv et pipx soient trouvables dès leur installation,
# sans attendre le rechargement du shell.
export PYENV_ROOT
export PIPX_HOME="${PIPX_HOME_DIR}"
export PIPX_BIN_DIR
export PATH="${PIPX_BIN_DIR}:${PYENV_ROOT}/bin:${PATH}"

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        die "Ce script ne doit pas être lancé en root. Relancez sans sudo."
    fi
}

check_os() {
    command -v apt-get >/dev/null 2>&1 \
        || die "Ce script requiert un système basé sur APT (Debian / Ubuntu)."

    local distro
    distro=$(. /etc/os-release && echo "${ID:-unknown}")
    case "$distro" in
        debian|ubuntu|linuxmint|pop|raspbian) ;;
        *) die "Distribution non supportée : $distro. Ce script cible Debian / Ubuntu." ;;
    esac

    info "Système : $(. /etc/os-release && echo "${PRETTY_NAME:-$distro}")"
}

# -----------------------------------------------------------------------------
# Helper APT : filtre silencieusement les paquets absents des dépôts
# -----------------------------------------------------------------------------
apt_install() {
    local -a to_install=()
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            to_install+=("$pkg")
        else
            warn "Paquet ignoré (indisponible sur cette distro) : ${pkg}"
        fi
    done
    [ "${#to_install[@]}" -gt 0 ] && sudo apt-get install -y "${to_install[@]}"
}

# -----------------------------------------------------------------------------
# Étape 1 : paquets système de base
# -----------------------------------------------------------------------------
install_base_packages() {
    info "Mise à jour des sources APT..."
    sudo apt-get update -q

    info "Installation des paquets de base..."
    apt_install \
        ca-certificates curl git \
        build-essential make \
        python3 python3-venv python3-pip

    success "Paquets de base prêts."
}

# -----------------------------------------------------------------------------
# Étape 2 : dépendances de compilation pour pyenv
#   Liste volontairement large, filtrée par apt_install selon la distro.
# -----------------------------------------------------------------------------
install_build_deps() {
    info "Installation des dépendances de compilation pour pyenv..."
    apt_install \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libffi-dev liblzma-dev libgdbm-dev libnss3-dev \
        xz-utils tk-dev wget llvm \
        libncursesw5-dev libncurses5-dev

    success "Dépendances de compilation prêtes."
}

# -----------------------------------------------------------------------------
# Étape 3 : pyenv
# -----------------------------------------------------------------------------
install_pyenv() {
    if [ ! -d "$PYENV_ROOT" ]; then
        info "Clonage de pyenv dans ${PYENV_ROOT}..."
        git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
        success "pyenv installé."
    else
        info "Mise à jour de pyenv..."
        git -C "$PYENV_ROOT" pull --ff-only 2>/dev/null \
            || warn "Mise à jour de pyenv ignorée (vérifiez l'état du dépôt)."
        success "pyenv à jour : $(pyenv --version)."
    fi
}

# -----------------------------------------------------------------------------
# Étape 4 : plugin pyenv-virtualenv
# -----------------------------------------------------------------------------
install_pyenv_virtualenv() {
    if [ ! -d "$PYENV_VENV_PLUGIN" ]; then
        info "Clonage du plugin pyenv-virtualenv..."
        git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_VENV_PLUGIN"
        success "pyenv-virtualenv installé."
    else
        info "Mise à jour du plugin pyenv-virtualenv..."
        git -C "$PYENV_VENV_PLUGIN" pull --ff-only 2>/dev/null \
            || warn "Mise à jour de pyenv-virtualenv ignorée."
        success "pyenv-virtualenv à jour."
    fi
}

# -----------------------------------------------------------------------------
# Étape 5 : pipx dans un venv dédié
#   Stratégie : venv isolé dans ~/.local/venvs/pipx, lien symb vers ~/.local/bin.
#   Contourne PEP 668 (« externally managed environment ») des Debian/Ubuntu récents.
# -----------------------------------------------------------------------------
install_pipx() {
    command -v python3 >/dev/null 2>&1 \
        || die "python3 introuvable après installation. Vérifiez les paquets APT."

    mkdir -p "$(dirname "$PIPX_VENV")" "$PIPX_BIN_DIR"

    if [ ! -d "$PIPX_VENV" ]; then
        info "Création du venv dédié pipx : ${PIPX_VENV}..."
        python3 -m venv "$PIPX_VENV"
    fi

    info "Mise à jour de pip et pipx dans le venv..."
    "$PIPX_VENV/bin/python" -m pip install -U pip  >/dev/null
    "$PIPX_VENV/bin/python" -m pip install -U pipx >/dev/null

    ln -sf "$PIPX_VENV/bin/pipx" "${PIPX_BIN_DIR}/pipx"

    success "pipx installé : $(pipx --version)."
}

# -----------------------------------------------------------------------------
# Étape 6 : poetry via pipx
# -----------------------------------------------------------------------------
install_poetry() {
    if pipx list 2>/dev/null | grep -qE 'package poetry\b'; then
        info "Mise à jour de Poetry via pipx..."
        pipx upgrade poetry >/dev/null
        success "Poetry mis à jour : $(poetry --version)."
    elif command -v poetry >/dev/null 2>&1; then
        warn "Poetry est présent mais n'est pas géré par pipx."
        warn "Pour le migrer : désinstallez l'installation existante puis relancez ce script."
        warn "  ou lancez manuellement : pipx install poetry"
        return
    else
        info "Installation de Poetry via pipx..."
        pipx install poetry >/dev/null
        success "Poetry installé : $(poetry --version)."
    fi

    info "Configuration Poetry : virtualenvs.in-project = true..."
    poetry config virtualenvs.in-project true
    success "Poetry configuré."
}

# -----------------------------------------------------------------------------
# Étape 7 : fichier d'intégration shell
#   Chargé automatiquement par ~/.bashrc et ~/.zshrc via ~/.shellrc/rc.d/*.sh
#   Réécrit à chaque exécution → idempotent.
# -----------------------------------------------------------------------------
write_shell_rc() {
    mkdir -p "$RC_DIR"

    cat > "$RC_FILE" <<'SHELLRC'
# 20-python-dev.sh — pyenv + pipx + poetry
# Chargé automatiquement via ~/.shellrc/rc.d/*.sh

export PATH="$HOME/.local/bin:$PATH"
export PIPX_HOME="$HOME/.local/pipx"
export PIPX_BIN_DIR="$HOME/.local/bin"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv >/dev/null 2>&1; then
    if [ -n "${ZSH_VERSION-}" ]; then
        eval "$(pyenv init - zsh)"
        eval "$(pyenv virtualenv-init - zsh)"
    else
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"
    fi
fi
SHELLRC

    chmod 0644 "$RC_FILE"
    success "Fichier rc écrit : ${RC_FILE}."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    echo -e "\n${BOLD}=== Installation Python : pyenv + pipx + poetry ===${RESET}\n"

    check_root
    check_os

    # Tier 2 : préchauffage sudo + keepalive.
    # Le keepalive est nécessaire car la compilation de Python via pyenv peut dépasser 5 min.
    info "Droits administrateur requis pour les paquets système."
    sudo -v
    ( while true; do sudo -n true; sleep 50; done ) &
    _SUDO_KEEPALIVE=$!
    trap 'kill "${_SUDO_KEEPALIVE}" 2>/dev/null' EXIT INT TERM

    export DEBIAN_FRONTEND=noninteractive

    install_base_packages
    install_build_deps
    install_pyenv
    install_pyenv_virtualenv
    install_pipx
    install_poetry
    write_shell_rc

    echo -e "\n${GREEN}${BOLD}Installation terminée.${RESET}\n"
    echo -e "  pyenv     : ${PYENV_ROOT}"
    echo -e "  pipx      : ${PIPX_BIN_DIR}/pipx"
    echo -e "  poetry    : ${PIPX_BIN_DIR}/poetry"
    echo -e "  rc shell  : ${RC_FILE}\n"
    echo -e "${BOLD}Prochaines étapes :${RESET}"
    echo -e "  1) Ouvrez un nouveau terminal, ou sourcez le fichier rc :"
    echo -e "       ${CYAN}source ${RC_FILE}${RESET}"
    echo -e "  2) Vérifiez les versions :"
    echo -e "       ${CYAN}pyenv --version && pipx --version && poetry --version${RESET}"
    echo -e "  3) Installez une version de Python avec pyenv :"
    echo -e "       ${CYAN}pyenv install --list | grep '^\s*3\.'${RESET}"
    echo -e "       ${CYAN}pyenv install 3.12.x   # remplacez par la version souhaitée${RESET}"
    echo -e "       ${CYAN}pyenv global  3.12.x${RESET}\n"
}

main "$@"
