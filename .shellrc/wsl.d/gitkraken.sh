

# Trouve automatiquement la dernière version installée
GITKRAKEN_DIR=$(find /mnt/c/Users/jpdem/AppData/Local/gitkraken -maxdepth 1 -name "app-*" -type d 2>/dev/null | sort -V | tail -1)
[ -n "$GITKRAKEN_DIR" ] && export PATH="$PATH:$GITKRAKEN_DIR"

# Fonction plutôt qu'alias, pour passer le chemin converti
gk() {
  local winpath
  winpath=$(wslpath -w "${1:-.}")
  gitkraken.exe -p "$winpath" &
}
