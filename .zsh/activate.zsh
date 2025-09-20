# -*- mode: shell-script -*-

# Path to your oh-my-zsh installation.
export ZSH="${HOME}/.oh-my-zsh"

# Définir le chemin de vos customs ($ZSH_CUSTOM)
export ZSH_CUSTOM="${HOME}/.zsh/custom"

# Si le theme n'est pas défini
if (( ! ${+ZSH_THEME} )); then
  ZSH_THEME="agnoster"
fi


plugins=(
# ansible
# python
#git-extras
colored-man-pages
colorize
command-not-found
debian
direnv
genpass
git
history
rsync
sudo
systemadmin
systemd
z
safe-paste
zsh-autosuggestions
zsh-completions
zsh-dircolors-solarized
zsh-syntax-highlighting
#zsh-vi-mode
atuin
)


# =============================================================
# MA CONFIGURATION PERSONNALISÉE DU TITRE DE FENÊTRE
# =============================================================

# 1. Définir une fonction pour mettre à jour le titre
set_custom_window_title() {
    print -Pn "\e]0;%m: %~\a"
}

# 2. Ajouter cette fonction à la liste des fonctions `precmd`
#    Utiliser `+=` pour ne pas écraser les fonctions existantes
precmd_functions+=(set_custom_window_title)


source $ZSH/oh-my-zsh.sh
