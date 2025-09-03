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
)


source $ZSH/oh-my-zsh.sh
