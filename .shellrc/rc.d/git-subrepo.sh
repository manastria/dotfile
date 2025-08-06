#!/bin/sh

# Charge git-subrepo si le répertoire ${HOME}/src/git-subrepo existe
if [ -d ${HOME}/src/git-subrepo ]; then
  source ${HOME}/src/git-subrepo/.rc
fi
# vim: ft=zsh
