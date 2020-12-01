# -*- mode: shell-script -*-

ZSH_PROFILE="omzp10"

case $ZSH_PROFILE in
  omz)
    # Path to your oh-my-zsh installation.
    source "${HOME}/.zsh/oh-my-zsh/activate.zsh"
    ;;
  omzp10)
    # Path to your oh-my-zsh installation.
    ZSH_THEME="powerlevel10k/powerlevel10k"
    source "${HOME}/.zsh/oh-my-zsh/activate.zsh"
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
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      ;;
  esac
fi
