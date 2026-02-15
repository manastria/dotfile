################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                          SYSTEME DE FICHIERS                             + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

# Navigation et affichage
alias ls="ls --color=auto --classify --tabsize=0 --group-directories-first -v"
alias df="df -x tmpfs -x devtmpfs --human-readable --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent"

# Informations sur les fichiers
alias getperms="stat -c '%A %a %U %G'"                    # Affiche permissions, proprietaire et groupe
alias getrealpath="readlink -f "                           # Resout le chemin absolu d'un fichier

# Sauvegarde / restauration des permissions
alias backup_permissions="stat -c '%a %U %G' fichier_cible > permissions_owner_group.txt"
alias restore_permissions="read chmod_value owner group && chmod \$chmod_value fichier_cible && chown \$owner:\$group fichier_cible"

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                            RECHERCHE / GREP                              + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

alias grepcolor='grep --color=always'

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                  GIT                                     + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

# Rend executables tous les scripts .sh et .zsh dans l'index git
alias gitscriptexec="find . -regextype posix-egrep -regex \".*\.(sh|zsh)$\" | xargs git update-index --chmod=+x"

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                 RESEAU                                   + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

alias ipb='ip -c -br a'                                                # Adresses IP (format court, colore)
alias nm-con-status='nmcli -f NAME,TYPE,DEVICE,STATE con show'         # Etat des connexions NetworkManager

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                  SSH                                     + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

alias sshpw='ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password'  # Force l'authentification par mot de passe
alias sshtest='ssh -o IdentitiesOnly=yes'                                          # Envoie uniquement les cles specifiees

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                              PGP / GPG                                   + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

# Export / import de cles
alias pgp_export_public='function gpg_export() { gpg --export --export-options no-export-minimal,no-export-clean -a -o "$1.asc" "$1"; }; gpg_export'
alias pgp_export_private='function gpg_export_private() { gpg --armor --export-secret-keys --export-options export-backup --output "$1-private.asc" "$1"; }; gpg_export_private'
alias pgp_import_private='function gpg_import_private() { gpg --import-options restore,keep-ownertrust --import "$1-private.asc"; }; gpg_import_private'

# Publication sur serveur de cles
alias pgp_publish_openpgp='function pgp_publish_openpgp() { gpg --export "$1" | curl -T - https://keys.openpgp.org; }; pgp_publish_openpgp'

################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                          OUTILS INTERACTIFS                              + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################



################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                                 DOCKER                                   + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

# --- Compose : commandes courantes ---
alias dcu="docker compose up"
alias dcud="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs"
alias dcs="docker compose ps"
alias dce="docker compose exec"

# --- Compose : developpement / reconstruction ---
alias dcr="docker compose down && docker compose up"
alias dcuf="docker compose up --force-recreate"
alias dcre="docker compose down --volumes --remove-orphans && docker compose up --build"

# --- Compose : monitoring et debogage ---
alias dclf="docker compose logs -f --tail=50"

# --- Docker : monitoring et debogage ---
alias dpsa="docker ps -a"
alias dstat="docker stats"
alias dci="docker inspect"

# --- Nettoyage cible ---
alias dils='docker images -f "dangling=true"'                          # Liste les images orphelines
alias dip="docker image prune -f"                                      # Supprime les images orphelines
alias dcrmoff='docker rm $(docker ps -aq -f "status=exited")'          # Supprime les conteneurs arretes
alias dvls="docker volume ls"                                          # Liste les volumes
alias dvp="docker volume prune -f"                                     # Supprime les volumes inutilises
alias dnls="docker network ls"                                         # Liste les reseaux
alias dnp="docker network prune -f"                                    # Supprime les reseaux inutilises

# --- Nettoyage complet ---
alias dcclean="docker system prune -af && docker volume prune -f"
alias dcxclean="docker compose down --volumes --remove-orphans && docker system prune -af && docker volume prune -f"
