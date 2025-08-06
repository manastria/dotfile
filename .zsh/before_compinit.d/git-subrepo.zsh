#!/bin/sh

# Charge git-subrepo si le répertoire ${HOME}/src/git-subrepo existe
if [ -d ${HOME}/src/git-subrepo ]; then
  fpath=('${HOME}/src/git-subrepo/share/zsh-completion' $fpath)
fi
# vim: ft=zsh
