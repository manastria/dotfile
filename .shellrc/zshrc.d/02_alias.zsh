# -*- mode: shell-script -*-


# alias l='exa -lbF --git'                                                # list, size, type, git
# alias ll='exa -lbGF --git'                                             # long list
# alias llm='exa -lbGd --git --sort=modified'                            # long list, modified date sort
# alias la='exa -lbhHigUmuSa --time-style=long-iso --git --color-scale'  # all list
# alias lx='exa -lbhHigUmuSa@ --time-style=long-iso --git --color-scale' # all + extended list
#
# # specialty views
# alias lS='exa -1'                                                              # one column, just names
# alias lt='exa --tree --level=2'                                         # tree





# Raccourcis pour 'ls'
if [ ! $(command -v exa) ]; then
	alias ll='ls -l'
	alias la='ls -lA'
	alias llm='ls -l | $PAGER'
	alias llv='ls -l | vimmanpager'
	##Classer par date
	alias lll='ls -l -t -h -r'
	alias llll='ls -l -t -h -r'
	alias lld='ls -l -d */ -h'
	alias l.='ls -d .*'
	alias lr='ls -R | grep ":$" | sed -e '\''s/:$//'\'' -e '\''s/[^-][^\/]*\//--/g'\'' -e '\''s/^/   /'\'' -e '\''s/-/|/'\'''
else
	alias ll='exa -ghHli'
	alias la='exa -la --git'
	alias llm='exa -l --git | $PAGER'
	alias llv='ls -l | vimmanpager'
	##Classer par date
	alias lll='exa -l --sort=modified --git'
	alias llll='exa -l --sort=modified --git'
	alias llt='exa -l --git --tree'
	alias lld='exa -l --group-directories-first'
	alias l.='ls -d .*'
	alias lr='ls -R | grep ":$" | sed -e '\''s/:$//'\'' -e '\''s/[^-][^\/]*\//--/g'\'' -e '\''s/^/   /'\'' -e '\''s/-/|/'\'''
fi




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
