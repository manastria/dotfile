#!/bin/sh
#
# Configure le PATH pour pipx de manière sécurisée et idempotente (sans duplication).
#
# C'est une pratique standard pour s'assurer que les exécutables
# installés par l'utilisateur (par exemple via `pipx` ou `pip --user`)
# sont automatiquement disponibles dans le shell.

# Chemin des binaires locaux de l'utilisateur
LOCAL_BIN_DIR="$HOME/.local/bin"

# Condition principale : le répertoire existe-t-il ?
if [ -d "$LOCAL_BIN_DIR" ]; then

  # Ajoute le chemin au PATH uniquement s'il n'y est pas déjà.
  # Cette méthode robuste évite les doublons dans la variable PATH.
  case ":$PATH:" in
    *":$LOCAL_BIN_DIR:"*)
      # Le chemin est déjà dans le PATH, on ne fait rien.
      ;;
    *)
      # Le chemin n'est pas dans le PATH, on l'ajoute au début.
      export PATH="$LOCAL_BIN_DIR:$PATH"
      ;;
  esac
fi

# Supprime la variable pour ne pas polluer l'environnement du shell
unset LOCAL_BIN_DIR
