#!/bin/bash

# -e: Quitte immédiatement si une commande échoue.
# -u: Traite les variables non définies comme une erreur.
# -o pipefail: Fait échouer un pipeline si l'une de ses commandes échoue.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# --- Installation de software-properties-common ---
# S'assure que la commande 'add-apt-repository' est disponible.
# L'option '-y' répond automatiquement 'oui' à la confirmation.
echo "INFO: Installation des dépendances nécessaires..."
apt-get update
apt-get install -y software-properties-common

# --- Ajout du PPA de CopyQ et installation ---
# Le PPA (Personal Package Archive) est la source officielle pour les versions à jour de CopyQ.
echo "INFO: Ajout du PPA ppa:hluk/copyq..."
add-apt-repository -y ppa:hluk/copyq

echo "INFO: Mise à jour des listes de paquets..."
apt-get update

echo "INFO: Installation de CopyQ..."
apt-get install -y copyq

echo "✅ Installation de CopyQ terminée avec succès."

exit 0
