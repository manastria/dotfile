#!/usr/bin/env bash
# NAME
#     yadm-check-submodules.sh — synchronise les submodules du dépôt yadm
#
# SYNOPSIS
#     yadm-check-submodules.sh [-n] [-h]
#
# DESCRIPTION
#     Alias de compatibilité : équivaut à « yadm-update-submodule sync ».
#     Remet les submodules du dépôt dotfiles géré par yadm (oh-my-zsh,
#     powerlevel10k, plugins zsh…) au commit épinglé par le dépôt. Conçu pour
#     être appelé après un « yadm pull », ou depuis dot-test.sh.
#
#     Ne tire jamais la dernière version upstream d'un submodule. Toute la
#     logique est dans git-update-submodule (sous-commande « sync ») ; ce
#     fichier ne la duplique pas. Voir docs/git-update-submodule.md.
#
# OPTIONS
#     -n, --dry-run   Signale les submodules désynchronisés sans rien
#                     modifier.
#     -h, --help      Affiche l'aide de git-update-submodule.
#
# ENVIRONMENT
#     YADM_REPO   Chemin du dépôt yadm.
#                 Défaut : ~/.local/share/yadm/repo.git
#
# EXAMPLES
#     # Usage courant, après un yadm pull
#     yadm-check-submodules.sh
#
#     # Diagnostic seul
#     yadm-check-submodules.sh --dry-run
#
# EXIT CODES
#     0   Submodules à jour, ou synchronisation réussie.
#     1   Erreur d'exécution : dépôt yadm introuvable, échec de git,
#         ou conflit de fusion dans un submodule.
#     2   Erreur d'usage : option inconnue.
set -euo pipefail

# Résolu à côté de ce fichier (voir yadm-update-submodule).
exec "$(dirname "$(readlink -f "$0")")/yadm-update-submodule" sync "$@"
