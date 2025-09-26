# Charger bash-preexec le plus tôt possible pour permettre des hooks multiples
# (Starship + Atuin) sans écraser PROMPT_COMMAND.

# Installer au besoin (1re fois) — silencieux, idempotent
if [ ! -f "$HOME/.bash-preexec.sh" ]; then
  curl -fsSL https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh \
    -o "$HOME/.bash-preexec.sh" || return
fi

# Charger (évite les doubles chargements)
# shellcheck disable=SC1090
source "$HOME/.bash-preexec.sh"
