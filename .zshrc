# -*- mode: shell-script -*-

ZSH_PROFILE="base"

case $ZSH_PROFILE in
  omz)
    # Path to your oh-my-zsh installation.
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
    profile)
      # Path to your oh-my-zsh installation.
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      ;;
  esac
fi
