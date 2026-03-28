# Fonction plutôt qu'alias, pour passer le chemin converti
gk() {
  local winpath
  winpath=$(wslpath -w "${1:-.}")
  gitkraken.exe -p "$winpath" &
}
