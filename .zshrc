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
  omz)
    # Path to your oh-my-zsh installation.
    source "${HOME}/.zsh/activate.zsh"
    ;;
  omzp10*)
    # Path to your oh-my-zsh installation.
    ZSH_THEME="powerlevel10k/powerlevel10k"
    source "${HOME}/.zsh/activate.zsh"
    ;;
  base)
    source "${HOME}/.zsh/config/zshrc.base"
    ;;
  *)
    ;;
esac


if [[ $ZSH_THEME =~ '.*powerlevel10k.*' ]]; then
  case $ZSH_PROFILE in
    omzp10)
      PFILE=${HOME}/.zsh/powerlevel10k/p10k.zsh.powerline
      [[ ! -f ${PFILE} ]] || source ${PFILE}
      ;;
    omzp10s)
      PFILE=${HOME}/.zsh/powerlevel10k/p10k.zsh.simple
      [[ ! -f ${PFILE} ]] || source ${PFILE}
      ;;
    omzp10writer)
      PFILE=${HOME}/.zsh/powerlevel10k/p10k.zsh.writer
      [[ ! -f ${PFILE} ]] || source ${PFILE}
      ;;
  esac
fi


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
