alias gitscriptexec="find . -regextype posix-egrep -regex \".*\.(sh|zsh)$\" | xargs git update-index --chmod=+x"
alias getperms="stat -c '%A %a'"
alias getrealpath="readlink -f "
alias df="df -x tmpfs -x devtmpfs --human-readable --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent"
alias ls="ls --color=auto --classify --tabsize=0 --group-directories-first -v" # --literal --color=auto --show-control-chars --human-readable --group-directories-first'

alias fzfon='[ -f ~/.fzf.bash ] && source ~/.fzf.bash'
alias fasdon='eval "$(fasd --init auto)"'
