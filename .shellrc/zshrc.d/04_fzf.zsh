#!/usr/bin/env bash

# ----------------------------------------
# Définition des raccourcis clavier pour fzf
# ----------------------------------------

# Un tableau FZF_BINDARGS est créé pour stocker diverses associations entre les touches 
# de raccourcis et leurs actions correspondantes lors de l'utilisation de fzf. 
# Par exemple, 'f1:execute(less -f {})' permet d'exécuter la commande 'less -f' 
# sur l'élément sélectionné lorsque l'utilisateur appuie sur 'F1'.
FZF_BINDARGS=(
    'f1:execute(less -f {})'
    'alt-a:toggle-all'
    'alt-c:deselect-all'
    'ctrl-x:execute(vim {+})'
    'ctrl-y:execute-silent(echo {} | xsel -b)+abort'
    'ctrl-p:toggle-preview'
    'pgup:half-page-up'
    'pgdn:half-page-down'
    'shift-up:preview-page-up'
    'shift-down:preview-page-down'
)

# --------------------------------------------------------
# Transformation du tableau FZF_BINDARGS en chaîne unique
# --------------------------------------------------------

# Ici, nous convertissons le tableau FZF_BINDARGS en une chaîne de caractères.
# - printf -v FZF_BINDARGS "%s," "${FZF_BINDARGS[@]}" : Concatène chaque élément du tableau
#   en une seule chaîne, les séparant par des virgules.
# - FZF_BINDARGS="${FZF_BINDARGS%,}" : Supprime la virgule superflue à la fin de la chaîne.
# - FZF_BINDARGS="${FZF_BINDARGS//, /,}" : Supprime les espaces après les virgules.
printf -v FZF_BINDARGS "%s," "${FZF_BINDARGS[@]}"
FZF_BINDARGS="${FZF_BINDARGS%,}"
FZF_BINDARGS="${FZF_BINDARGS//, /,}"

# -----------------------------------------------------------
# Configuration des variables d'environnement pour utiliser fzf
# -----------------------------------------------------------

# Les variables d'environnement suivantes sont configurées pour personnaliser 
# le comportement de fzf lorsqu'il est appelé dans le shell.
# - FZF_PREVIEW_ARGS : Utilisé pour déterminer comment les prévisualisations des fichiers 
#   sont générées avec l'outil batcat.
# - FZF_DEFAULT_COMMAND : La commande utilisée par défaut pour trouver les fichiers 
#   à filtrer avec fzf.
# - FZF_DEFAULT_OPTS : Définit les options utilisées par fzf par défaut, incluant 
#   les raccourcis clavier que nous avons définis dans FZF_BINDARGS.
# - FZF_ALT_C_COMMAND : Définit la commande utilisée pour trouver les répertoires 
#   quand ALT+C est utilisÃ© avec fzf.
# - FZF_ALT_C_OPTS : Configure l'aperçu pour la navigation de répertoire avec ALT+C 
#   pour montrer une arborescence du répertoire actuellement sélectionné avec 'tree'.

export FZF_PREVIEW_ARGS="batcat --style=numbers --color=always {} | head -500"
export FZF_DEFAULT_COMMAND="fdfind -H ."
export FZF_DEFAULT_OPTS="--bind '${FZF_BINDARGS}'"
export FZF_ALT_C_COMMAND="fdfind -H --type d"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# ---------------------------------------------------------
# Configuration Vim pour une mise en forme du script adéquate
# ---------------------------------------------------------

# Cette ligne de commentaire est utilisée pour configurer l'éditeur de texte Vim 
# pour utiliser des paramètres spécifiques de mise en forme et de style 
# lors de l'édition de ce script.
# - ft=sh : Définit le type de fichier (filetype) comme script shell.
# - sts=2, ts=2, sw=2 : Configure les options d'espacement et de tabulation.
# - tw=120 : Définit la largeur du texte à 120 caractères.
# - et : Utilise des espaces plutÃ´t que des tabulations pour l'indentation.

# vim: set ft=sh sts=2 ts=2 sw=2 tw=120 et :

