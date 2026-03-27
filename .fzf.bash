# Intégration shell fzf (complétion + raccourcis clavier)
# Requiert fzf >= 0.48 — installer via ~/.local/bin/install-fzf.sh
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"
