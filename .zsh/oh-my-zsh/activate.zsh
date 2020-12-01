# -*- mode: shell-script -*-

# Path to your oh-my-zsh installation.
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="agnoster"


plugins=(
git
#git-extras
history
# python
# ansible
zsh-autosuggestions
zsh-completions
zsh-syntax-highlighting
)


source $ZSH/oh-my-zsh.sh
