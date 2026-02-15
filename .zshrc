# -*- mode: shell-script -*-

ZSH_PROFILE="${ZSH_PROFILE:-base}"

#export TERM=xterm-256color

mkdir -p $HOME/.zsh/before_compinit.d
# Load all files from .zsh/before_compinit.d directory
if [ -d $HOME/.zsh/before_compinit.d ]; then
  for file in $HOME/.zsh/before_compinit.d/**/*.zsh; do
    source $file
  done
fi


case $ZSH_PROFILE in
  base)
    source "${HOME}/.zsh/config/zshrc.base"
    ;;
  omz)
    source "${HOME}/.zsh/activate.zsh"
    ;;
  *)
    # Convention : ZSH_PROFILE = suffixe du fichier p10k
    # Ex: ZSH_PROFILE=simple → .zsh/powerlevel10k/p10k.zsh.simple
    ZSH_THEME="powerlevel10k/powerlevel10k"
    source "${HOME}/.zsh/activate.zsh"
    local pfile="${HOME}/.zsh/powerlevel10k/p10k.zsh.${ZSH_PROFILE}"
    if [[ -f ${pfile} ]]; then
      source ${pfile}
    fi
    ;;
esac


#
# Call directories scripts
#
mkdir -p $HOME/.shellrc/zshrc.d $HOME/.shellrc/rc.d
# Load all files from .shell/zshrc.d directory
if [ -d $HOME/.shellrc/zshrc.d ]; then
  for file in $HOME/.shellrc/zshrc.d/**/*.zsh; do
    source $file
  done
fi

# Load all files from .shell/rc.d directory
if [ -d $HOME/.shellrc/rc.d ]; then
  for file in $HOME/.shellrc/rc.d/*.sh; do
    source $file
  done
fi


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
