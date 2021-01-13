alias gitscriptexec="find . -regextype posix-egrep -regex ".*\.(sh|zsh)$" | xargs git update-index --chmod=+x"

