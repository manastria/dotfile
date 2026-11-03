EDITOR=vim

# Pager : less avec F (quitte si tout tient sur un écran), R (affiche les
# couleurs ANSI), X (ne vide pas l'écran à la sortie), K (quitte sur Ctrl-C),
# S (ne replie pas les lignes longues). Les options passent par LESS pour que
# PAGER reste un simple nom de commande (zsh ne découpe pas $PAGER sans guillemets).
export LESS=FRXKS
export PAGER=less
