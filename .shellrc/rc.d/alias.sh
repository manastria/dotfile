alias gitscriptexec="find . -regextype posix-egrep -regex \".*\.(sh|zsh)$\" | xargs git update-index --chmod=+x"
alias getperms="stat -c '%A %a %U %G'"
alias getrealpath="readlink -f "
alias df="df -x tmpfs -x devtmpfs --human-readable --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent"
alias ls="ls --color=auto --classify --tabsize=0 --group-directories-first -v" # --literal --color=auto --show-control-chars --human-readable --group-directories-first'

alias fzfon='[ -f ~/.fzf.bash ] && source ~/.fzf.bash'
alias fasdon='eval "$(fasd --init auto)"'

alias backup_permissions="stat -c '%a %U %G' fichier_cible > permissions_owner_group.txt"
alias restore_permissions="read chmod_value owner group && chmod $chmod_value fichier_cible && chown $owner:$group fichier_cible"
