################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

alias grepcolor='grep --color=always'

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

alias gitscriptexec="find . -regextype posix-egrep -regex \".*\.(sh|zsh)$\" | xargs git update-index --chmod=+x"

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################
alias getperms="stat -c '%A %a %U %G'"
alias getrealpath="readlink -f "
alias df="df -x tmpfs -x devtmpfs --human-readable --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent"
alias ls="ls --color=auto --classify --tabsize=0 --group-directories-first -v" # --literal --color=auto --show-control-chars --human-readable --group-directories-first'
alias backup_permissions="stat -c '%a %U %G' fichier_cible > permissions_owner_group.txt"
alias restore_permissions="read chmod_value owner group && chmod $chmod_value fichier_cible && chown $owner:$group fichier_cible"

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

alias fzfon='[ -f ~/.fzf.bash ] && source ~/.fzf.bash'
alias fasdon='eval "$(fasd --init auto)"'

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################


alias nm-con-status='nmcli -f NAME,TYPE,DEVICE,STATE con show' # --active

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                SECTION 01                                + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################


alias pgp_export_public='function gpg_export() { gpg --export --export-options no-export-minimal,no-export-clean -a -o "$1.asc" "$1"; }; gpg_export'
alias pgp_publish_openpgp='function pgp_publish_openpgp() { gpg --export "$1" | curl -T - https://keys.openpgp.org; }; pgp_publish_openpgp'
alias pgp_export_private='function gpg_export_private() { gpg --armor --export-secret-keys --export-options export-backup --output "$1-private.asc" "$1"; }; gpg_export_private'
alias pgp_import_private='function gpg_import_private() { gpg --import-options restore,keep-ownertrust --import "$1-private.asc"; }; gpg_import_private'


# Démarrer rapidement les conteneurs (mode interactif)
alias dcu="docker compose up"

# Démarrer en arrière-plan (detach)
alias dcud="docker compose up -d"

# Redémarrer proprement (arrêt + relance)
alias dcr="docker compose down && docker compose up"

# Reconstruire et relancer
alias dcrb="docker compose down && docker compose up --build"

# Supprimer volumes + rebuild complet
alias dcpurge="docker compose down -v --remove-orphans && docker compose up --build"

# Arrêter
alias dcd="docker compose down"

# Voir les logs
alias dcl="docker compose logs -f"

# Voir l'état
alias dcs="docker compose ps"

# Ouvrir un shell dans un conteneur (usage : dce <nom_service>)
alias dce="docker compose exec"

# Nettoyer tous les conteneurs, volumes et images non utilisés
alias dcclean="docker system prune -af && docker volume prune -f"



# Lance les services Docker (en arrière-plan)
alias webup="docker compose up -d"

# Arrête les services Docker
alias webstop="docker compose down"

# Affiche l'adresse IP de la VM (pour y accéder depuis Windows)
alias webip="ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1"




alias gulp="docker compose exec node gulp"
alias npm-install="docker compose exec node npm install"
alias gulp-watch="docker compose exec node gulp watch"
