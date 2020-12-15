# -*- mode: shell-script -*-

# Path to your oh-my-zsh installation.
export ZSH="${HOME}/.oh-my-zsh"

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
zsh-autosuggestions
zsh-completions
zsh-dircolors-solarized
zsh-syntax-highlighting
)


source $ZSH/oh-my-zsh.sh
