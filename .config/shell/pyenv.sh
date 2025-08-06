#!/bin/sh
#
# ~/.config/shell/pyenv.sh
#
# Chargement et configuration de pyenv
# Ce script ne fait rien si pyenv n'est pas trouvé dans ~/.pyenv

# Définir le chemin racine de pyenv
export PYENV_ROOT="$HOME/.pyenv"

# Vérifier si le répertoire PYENV_ROOT existe bien
if [ -d "${PYENV_ROOT}" ]; then

  # 1. Ajouter le binaire de pyenv au PATH
  #    Cela permet de trouver la commande `pyenv` elle-même.
  export PATH="${PYENV_ROOT}/bin:${PATH}"

  # 2. Initialiser pyenv et les shims
  #    `pyenv init -` est la commande clé qui configure les shims.
  #    Les shims sont essentiels pour que pyenv puisse intercepter
  #    les appels à `python`, `pip`, etc.
  #    L'utilisation de `eval` est nécessaire pour que la commande
  #    puisse modifier l'environnement du shell courant.
  eval "$(pyenv init -)"

fi

