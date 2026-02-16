# -*- mode: shell-script -*-

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################


# Affiche les processus avec les colonnes essentielles pour une analyse rapide :
#   - PPID : PID du processus parent.
#   - PID  : Identifiant du processus.
#   - STAT : État du processus (Running, Sleeping, etc.).
#   - TTY  : Terminal associé au processus (ou ? si aucun).
#   - USER : Utilisateur propriétaire du processus.
#   - CMD  : Commande utilisée pour démarrer le processus.
alias psess='ps -o ppid,pid,stat,tty,user,cmd' # Affichage des processus avec les colonnes essentielles

# Affiche l'arborescence complète des processus à partir du shell courant.
# Options :
#   -p : Affiche les PIDs (identifiants des processus).
#   -c : Désactive le regroupement des processus similaires.
#   -l : Évite la troncature des lignes longues.
alias treeproc='pstree -p -c -l $$'
alias stree='pstree -p -c -l $$' # Contraction de "Shell Tree", indiquant l’arborescence des processus autour du shell.

# Affiche tous les processus enfants de terminator
alias termtree='pstree -p -c -l $(ps -o ppid= -p $$)'
