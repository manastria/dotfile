#-------------------
# Alias
#-------------------
# la couleur pour chaque type de fichier, les répertoires s'affichent en premier
alias ls='ls -h --color --group-directories-first'
# affiche les fichiers cachés
alias lsa='ls -A'
# affiche en mode liste détail
alias ll='ls -ls'
# affiche en mode liste détail + fichiers cachés
alias lla='ls -Al'
# tri par extension
alias lx='ls -lXB'
 # tri par taille, le plus lourd à la fin
alias lk='ls -lSr'
# tri par date de modification, la plus récente à la fin
alias lc='ls -ltcr'
# tri par date d’accès, la plus récente à la fin
alias lu='ls -ltur'
# tri par date, la plus récente à la fin
alias lt='ls -ltr'
# Pipe a travers 'more'
alias lm='ls -al | more'
# ls récurssif
alias lr='ls -lR'
# affciche sous forme d'arborescence, nécessite le paquet tree
alias tree='tree -Csu'
# affiche les dernière d'un fichier log (par exemple) en live
#alias voirlog='tail -f'
# commande df avec l'option -human
alias df='df -kTh'
# commande du avec l'option -human
alias du='du -kh'
# commande du avec l'option -human, au niveau du répertoire courant
alias duc='du -kh --max-depth=1'
# commande free avec l'option affichage en Mo
alias free='free -m'
# nécessite le paquet "htop", un top amélioré et en couleur
#alias top='htop'
# faire une recherche dans l'historique de commande
#alias shistory='history | grep'
# raccourci history
#alias h='history'

# Ajout log en couleurs
ctail() { tail -n 80 -f $1 | ccze -A; }
cless() { ccze -A < $1 | less -R; }

# Afficher les permissions en octal
lso() { ls -l "$@" | awk '{k=0;for(i=0;i<=8;i++)k+=((substr($1,i+2,1)~/[rwx]/)*2^(8-i));if(k)printf(" %0o ",k);print}'; }

# ZSH
alias zzz1='TERM=xterm-256color ZSH_PROFILE=omzp10s tmux'
alias zzz2='TERM=xterm-256color ZSH_PROFILE=base zsh -i'

alias fzfon='[ -f ~/.fzf.bash ] && source ~/.fzf.bash'
alias fasdon='eval "$(fasd --init auto)"'

