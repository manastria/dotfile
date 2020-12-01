# -*- mode: shell-script -*-

# Path to your oh-my-zsh installation.
export ZSH="${HOME}/.oh-my-zsh"

# Si le theme n'est pas défini
if (( ! ${+ZSH_THEME} )); then
  ZSH_THEME="agnoster"
fi


plugins=(
git
#git-extras
history
# python
# ansible
zsh-autosuggestions
zsh-completions
zsh-syntax-highlighting
z
)


source $ZSH/oh-my-zsh.sh
