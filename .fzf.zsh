# Intégration shell fzf (complétion + raccourcis clavier)
# Requiert fzf >= 0.48 — installer via ~/.local/bin/install-fzf.sh
(( $+commands[fzf] )) && eval "$(fzf --zsh)"
