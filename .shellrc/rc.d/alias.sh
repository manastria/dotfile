alias gitscriptexec="find . -regextype posix-egrep -regex \".*\.(sh|zsh)$\" | xargs git update-index --chmod=+x"
alias getperms="stat -c '%A %a'"
alias getrealpath="readlink -f "
alias df="df -x tmpfs -x devtmpfs --human-readable --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent"

