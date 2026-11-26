#!/usr/bin/env bash
# git-depannage.sh — Alias Git temporaires et diagnostic de dépôt, pour dépanner sur le poste d'un étudiant
#
# NAME
#     git-depannage.sh — raccourcis Git et commande de diagnostic, sans toucher à la configuration
#
# SYNOPSIS
#     . <(curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/main/.shellrc/depannage/git-depannage.sh)
#     . ~/.shellrc/depannage/git-depannage.sh
#     gdiag [N]        gdiag -h
#     gaide
#
# DESCRIPTION
#     Fichier À SOURCER (pas à exécuter) dans un terminal bash ou zsh. Il définit,
#     pour le shell courant seulement :
#       - des alias courts (gs, gl, gll, gls, gd, gdc, gdh, ga, gc, gsw, grv, gsl) ;
#       - gdiag  : état complet du dépôt en une commande, en lecture seule ;
#       - gaide  : rappel de la liste des alias.
#     Rien n'est écrit sur le disque : ni ~/.gitconfig, ni .git/config, ni
#     fichier temporaire. Tout disparaît à la fermeture du terminal. Aucune
#     commande définie ici ne modifie le dépôt.
#     Ce fichier n'est PAS chargé par .bashrc/.zshrc (dossier hors bashrc.d,
#     zshrc.d et rc.d) : il ne s'active que si on le source à la main.
#
# OPTIONS (gdiag)
#     N            nombre de commits affichés dans l'historique (défaut : 10)
#     -h, --help   résumé de l'usage
#
# EXAMPLES
#     gdiag        # état du dépôt courant, 10 derniers commits
#     gdiag 25     # idem avec 25 commits
#     gaide        # liste des alias disponibles
#
# EXIT CODES (gdiag)
#     0  diagnostic affiché
#     1  le répertoire courant n'est pas dans un dépôt Git
#     2  argument invalide
#
# Pas de « set -e » / « set -u » ici : ce fichier s'exécute dans le shell de
# l'étudiant, une erreur ne doit jamais fermer sa session. Tous les noms
# internes sont préfixés par _gdep_ ou _GDEP_ pour ne pas polluer son shell.

# -----------------------------------------------------------------------------
# Garde : refuser l'exécution directe
# -----------------------------------------------------------------------------
# « return » n'est valide que dans un fichier sourcé : l'astuce détecte donc
# l'exécution directe, où les alias seraient définis dans un sous-shell
# aussitôt perdu.
if ! (return 0 2>/dev/null); then
    echo "[ERREUR]    Ce fichier se source, il ne s'exécute pas." >&2
    echo "            Utilisez : . $0" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Alias
# -----------------------------------------------------------------------------
# Liste « nom|commande|description », alimentée par _gdep_alias pour que gaide
# affiche exactement ce qui est défini (une seule source de vérité).
_GDEP_LISTE=""

# _gdep_alias NOM COMMANDE DESCRIPTION : définit l'alias et le mémorise pour gaide.
_gdep_alias() {
    # alias "nom=commande" : les guillemets protègent les espaces et les « % » de COMMANDE
    alias "$1=$2"
    _GDEP_LISTE="${_GDEP_LISTE}${1}|${2}|${3}
"
}

# Format de log : hash, références (branches, tags, HEAD), titre, auteur.
# %C(auto) laisse Git décider de la couleur (aucune si la sortie est redirigée).
_gdep_alias gs  'git status -sb' 'état court : branche et une ligne par fichier'
_gdep_alias gl  'git log --graph --all --format="%C(auto)%h%d %s (%an)"' 'graphe de toutes les branches, avec auteur'
_gdep_alias gll 'git log --graph --all --name-status --format="%C(auto)%h%d %s (%an)"' 'gl + fichiers touchés (A/M/D/R)'
_gdep_alias gls 'git log --graph --all --stat --format="%C(auto)%h%d %s (%an)"' 'gl + volume des changements'
_gdep_alias gd  'git diff' 'modifications non indexées'
_gdep_alias gdc 'git diff --cached' 'modifications indexées (après git add)'
_gdep_alias gdh 'git diff HEAD' 'tout, indexé ou non, par rapport au dernier commit'
_gdep_alias ga  'git add' 'indexer un fichier'
_gdep_alias gc  'git commit' 'créer un commit'
_gdep_alias gsw 'git switch' 'changer de branche'
_gdep_alias grv 'git remote -v' 'adresses des dépôts distants'
_gdep_alias gsl 'git stash list' 'travail mis de côté'

# -----------------------------------------------------------------------------
# Fonctions internes d'affichage
# -----------------------------------------------------------------------------
# Titre de section : en gras cyan sur un terminal, en clair si la sortie est redirigée.
_gdep_titre() {
    if [ -t 1 ]; then
        printf '\n\033[1;36m== %s ==\033[0m\n' "$1"
    else
        printf '\n== %s ==\n' "$1"
    fi
}

# Piste de dépannage : texte seulement, la commande n'est jamais exécutée.
_gdep_astuce() {
    printf '  -> %s\n' "$*"
}

# _gdep_existe CHEMIN : vrai si le fichier/dossier interne de Git existe.
# --git-path résout le bon emplacement même pour un worktree ou un submodule,
# où « .git » est un fichier et non un dossier.
_gdep_existe() {
    [ -e "$(git rev-parse --git-path "$1")" ]
}

# -----------------------------------------------------------------------------
# gaide : rappel des alias
# -----------------------------------------------------------------------------
gaide() {
    # zsh exécute le dernier maillon d'un pipeline dans le shell courant : sans
    # « local », les variables de la boucle fuiraient chez l'étudiant.
    local _n _c _d
    printf 'Alias Git temporaires (propres à ce terminal) :\n\n'
    # IFS='|' découpe nom|commande|description ; la commande ne contient jamais de « | ».
    printf '%s' "$_GDEP_LISTE" | while IFS='|' read -r _n _c _d; do
        printf '  %-4s %s\n' "$_n" "$_d"
        printf '       %s\n' "$_c"
    done
    printf '\nCommande de diagnostic : gdiag [N]  (état complet, lecture seule)\n'
}

# -----------------------------------------------------------------------------
# gdiag : diagnostic complet du dépôt courant
# -----------------------------------------------------------------------------
gdiag() {
    local nb="10" libre="oui" conflits

    case "${1:-}" in
        -h|--help)
            printf 'Usage : gdiag [N]\n'
            printf '  Affiche l'"'"'état du dépôt courant (lecture seule) : HEAD et fichiers,\n'
            printf '  opération en cours, conflits, N derniers commits (défaut 10),\n'
            printf '  stash et dépôts distants.\n'
            return 0 ;;
        '') ;;
        *[!0-9]*)
            echo "[ERREUR]    Argument invalide : « $1 » (nombre de commits attendu)." >&2
            return 2 ;;
        *) nb="$1" ;;
    esac

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "[ERREUR]    Pas dans un dépôt Git (ou dépôt nu)." >&2
        return 1
    fi

    # --- 1. HEAD et fichiers ---
    _gdep_titre "État de HEAD et des fichiers"
    git status -sb

    # --- 2. Opération interrompue ---
    # Chaque opération laisse un marqueur dans le répertoire Git ; leur présence
    # est le seul moyen fiable de savoir qu'une opération est « en cours ».
    _gdep_titre "Opération en cours"
    if _gdep_existe MERGE_HEAD; then
        libre="non"
        echo "Fusion (merge) en cours."
        _gdep_astuce "Annuler : git merge --abort"
    fi
    if _gdep_existe rebase-merge || _gdep_existe rebase-apply; then
        libre="non"
        if _gdep_existe rebase-apply/applying; then
            echo "Application de patchs (git am) en cours."
            _gdep_astuce "Annuler : git am --abort"
        else
            echo "Rebasage (rebase) en cours."
            _gdep_astuce "Annuler : git rebase --abort   |   Poursuivre après résolution : git rebase --continue"
        fi
    fi
    if _gdep_existe CHERRY_PICK_HEAD; then
        libre="non"
        echo "Cherry-pick en cours."
        _gdep_astuce "Annuler : git cherry-pick --abort"
    fi
    if _gdep_existe REVERT_HEAD; then
        libre="non"
        echo "Revert en cours."
        _gdep_astuce "Annuler : git revert --abort"
    fi
    if _gdep_existe BISECT_LOG; then
        libre="non"
        echo "Recherche par bissection (bisect) en cours."
        _gdep_astuce "Terminer : git bisect reset"
    fi

    # symbolic-ref échoue quand HEAD pointe directement sur un commit.
    if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
        printf 'HEAD détachée sur %s' "$(git rev-parse --short HEAD 2>/dev/null)"
        if [ "$libre" = "oui" ]; then
            printf '.\n'
            _gdep_astuce "Aucun commit créé : git switch -   |   Commits créés : git switch -c sauvetage"
            libre="non"
        else
            # HEAD est détachée par construction pendant un rebase ou un bisect.
            printf ' (normal pendant cette opération).\n'
        fi
    fi
    [ "$libre" = "oui" ] && echo "Aucune."

    # Fichiers non fusionnés (filtre U) : conflits, y compris hors merge (stash pop…).
    conflits="$(git diff --name-only --diff-filter=U)"
    if [ -n "$conflits" ]; then
        echo "Fichiers en conflit :"
        printf '%s\n' "$conflits" | sed 's/^/  /'
        _gdep_astuce "Après résolution : git add <fichier>, puis poursuivre l'opération"
    fi

    # --- 3. Historique ---
    _gdep_titre "Historique ($nb derniers commits, toutes branches)"
    # rev-parse --verify échoue dans un dépôt sans commit, où git log afficherait une erreur.
    if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
        # --no-pager : le diagnostic doit s'afficher d'un bloc, sans passer par less.
        git --no-pager log --graph --all -n "$nb" --format="%C(auto)%h%d %s (%an)"
    else
        echo "(aucun commit)"
    fi

    # --- 4. Stash ---
    _gdep_titre "Travail mis de côté (stash)"
    if [ -n "$(git stash list)" ]; then
        git stash list
    else
        echo "(aucun)"
    fi

    # --- 5. Dépôts distants ---
    _gdep_titre "Dépôts distants"
    if [ -n "$(git remote)" ]; then
        git remote -v
    else
        echo "(aucun)"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Fin du chargement
# -----------------------------------------------------------------------------
echo "Alias Git temporaires chargés (gaide : liste, gdiag : diagnostic). Rien n'est écrit sur le disque."
