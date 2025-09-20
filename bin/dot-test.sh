#!/usr/bin/env bash
# Usage: ./dot-test.sh {create|reset-home|install|delete|status} [USER] [REPO]
set -euo pipefail

USER_NAME=${2:-testdot}
REPO_URL=${3:-https://github.com/manastria/dotfile}
DEFAULT_BRANCH=${DEFAULT_BRANCH:-main}
HOME_DIR=/home/"$USER_NAME"

log(){ printf '[dot-test] %s\n' "$*"; }
usage(){ echo "Usage: $0 {create|reset-home|install|delete|status} [USER] [REPO]"; }

ensure_user_exists(){ id "$USER_NAME" >/dev/null 2>&1 || { echo "Utilisateur '$USER_NAME' absent. Lance: $0 create $USER_NAME"; exit 1; }; }
require_cmd(){ command -v "$1" >/dev/null 2>&1 || { echo "Erreur: '$1' introuvable."; exit 127; }; }

create_user(){
  log "Création de l'utilisateur '$USER_NAME'…"
  sudo adduser --gecos "" --disabled-password "$USER_NAME"
  log "OK. Pour tester: sudo -i -u $USER_NAME"
}

reset_home(){
  ensure_user_exists
  log "Réinitialisation du HOME depuis /etc/skel…"
  sudo rm -rf "$HOME_DIR"
  sudo mkdir -p "$HOME_DIR"
  sudo cp -r /etc/skel/. "$HOME_DIR"
  sudo chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR"
  log "HOME réinitialisé."
}

install(){
  ensure_user_exists
  require_cmd yadm
  YADM_BIN=$(command -v yadm)

  log "Installation des dotfiles (shallow, branch=$DEFAULT_BRANCH)…"

  # On passe les variables au sous-shell via l'environnement et on utilise un heredoc.
  sudo -iu "$USER_NAME" env \
    YADM_BIN="$YADM_BIN" \
    REPO_URL="$REPO_URL" \
    DEFAULT_BRANCH="$DEFAULT_BRANCH" \
    bash -s <<'EOS'
set -euo pipefail
echo "[install] whoami=$(id -un) home=$HOME pwd=$(pwd)"
# Idempotent: si le dépôt yadm existe déjà, on met simplement à jour.
if [ -d "$HOME/.local/share/yadm/repo.git" ]; then
  "$YADM_BIN" remote set-url origin "$REPO_URL" || true
  "$YADM_BIN" fetch --depth=1 --prune origin "$DEFAULT_BRANCH"
  "$YADM_BIN" reset --hard origin/"$DEFAULT_BRANCH"
else
  cd "$HOME"
  "$YADM_BIN" clone --depth=1 --single-branch --branch "$DEFAULT_BRANCH" "$REPO_URL"
  # Par sécurité si on relance install plus tard :
  "$YADM_BIN" fetch --depth=1 origin "$DEFAULT_BRANCH" || true
  "$YADM_BIN" reset --hard origin/"$DEFAULT_BRANCH"
fi

# Sous-modules/plugins via ton script perso, s'il existe et est exécutable
if [ -x "$HOME/bin/yadm_check_submodules.sh" ]; then
  echo "[install] yadm_check_submodules.sh…"
  "$HOME/bin/yadm_check_submodules.sh" || true
fi

echo "[install] HEAD: $("$YADM_BIN" rev-parse --short HEAD 2>/dev/null || echo n/a)"
EOS

  log "Installation terminée."
  log "Ouvre une session de test avec: sudo -i -u $USER_NAME"
}

delete_user(){
  log "Suppression de l'utilisateur '$USER_NAME' (et de son HOME)…"
  sudo deluser --remove-home "$USER_NAME"
  log "Utilisateur supprimé."
}

status(){
  ensure_user_exists
  sudo -iu "$USER_NAME" bash -lc '
    set -euo pipefail
    echo "[status] yadm: $(command -v yadm || echo ABSENT)"
    if [ -d "$HOME/.local/share/yadm/repo.git" ]; then
      echo "[status] repo.git: PRESENT"
      echo "[status] branch: $(yadm rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a)"
      echo "[status] upstream: $(yadm rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo n/a)"
      echo "[status] HEAD: $(yadm rev-parse --short HEAD 2>/dev/null || echo n/a)"
    else
      echo "[status] repo.git: ABSENT"
    fi
  '
}

case "${1:-}" in
  create)      create_user ;;
  reset-home)  reset_home ;;
  install)     install ;;
  delete)      delete_user ;;
  status)      status ;;
  *)           usage; exit 1 ;;
esac
