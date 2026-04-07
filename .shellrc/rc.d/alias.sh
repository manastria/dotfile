################################################################################
# +--------------------------------------------------------------------------+ #
# +                                                                          + #
# +                          SYSTEME DE FICHIERS                             + #
# +                                                                          + #
# +--------------------------------------------------------------------------+ #
################################################################################

# Navigation et affichage
alias ls='ls -N --show-control-chars --color=auto --classify --group-directories-first'
alias df="df -x tmpfs -x devtmpfs --human-readable --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent"
alias lsblkf='lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID,LABEL'

# --- Configuration des Alias de fichiers ---

if command -v eza >/dev/null 2>&1; then
    # 1. L'alias "quotidien" (propre, sans bling-bling, tri intelligent)
    # -lh : format liste + tailles lisibles (Ko, Mo)
    # --group-directories-first : dossiers en haut (respecte le tri '_' en tête)
    # --no-permissions --no-user : épure l'affichage pour l'usage personnel
    # --git : affiche l'état des fichiers dans les dépôts Git
    alias l='eza -lh --group-directories-first --no-permissions --no-user --git'

    # 2. Le format long standard (pour le travail plus technique)
    # Affiche les permissions et les propriétaires contrairement à l'alias 'l'
    alias ll='eza -lh --group-directories-first --git'

    # 3. Afficher tout (inclut les fichiers cachés commençant par un point)
    alias la='eza -lah --group-directories-first --git'

    # 4. Tri par date (les fichiers les plus récents en haut de liste)
    # --sort=modified : trie par date de modification
    alias lll='eza -lh --sort=modified --git'
    alias llll='lll'

    # 5. Vue en arborescence (remplace avantageusement votre ancien script 'lr')
    # --tree : affiche la hiérarchie
    # --level=2 : limite la profondeur pour ne pas saturer l'écran
    alias llt='eza -lh --tree --level=2 --git'

    # 6. Afficher uniquement les répertoires
    # -D : filtre pour ne montrer que les dossiers
    alias lld='eza -lhD --group-directories-first'

    # 7. Afficher uniquement les fichiers cachés
    alias l.='eza -ldh .*'

    # 8. Pagers (pour les dossiers contenant énormément de fichiers)
    # Utilise votre variable d'environnement $PAGER (souvent 'less')
    alias llm='eza -lh --git | $PAGER'

else
    # --- Fallback : Si eza n'est pas installé, on revient à ls classique ---
    alias l='ls -F --color=auto --group-directories-first'
    alias ll='ls -lh --group-directories-first'
    alias la='ls -lAh --group-directories-first'
    alias lll='ls -ltrh'
    alias lld='ls -ld */'
    alias l.='ls -d .*'
fi

# Note pour votre mémo : 
# Pour un format de date ISO (2026-02-16), ajoutez l'option : --time-style=long-iso

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
alias mdns-start='avahi-publish-address -R prof.local $(hostname -I | awk "{print \$1}") &>/dev/null & echo "✅ prof.local actif (PID $!)"'
alias mdns-stop='kill $(pgrep -f "avahi-publish.*prof.local") 2>/dev/null && echo "🛑 prof.local révoqué" || echo "rien à arrêter"'


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
