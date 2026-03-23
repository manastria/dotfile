#!/bin/bash

# ==============================================================================
# Script pour mettre à jour les dépôts Git locaux connectés à GitHub.
#
# Objectif: Parcourir les sous-répertoires, identifier les dépôts Git
#           pointant vers un remote GitHub, et exécuter 'git fetch'.
#
# Prérequis: La CLI GitHub 'gh' doit être installée.
#            (sudo apt install gh) et authentifiée ('gh auth login').
# ==============================================================================

# --- Configuration ---
# Répertoire contenant vos dépôts Git.
# Mettez "." pour le répertoire courant, ou un chemin absolu/relatif.
BASE_DIR="."

# --- Couleurs pour un affichage plus clair ---
COLOR_GREEN=$(tput setaf 2)
COLOR_YELLOW=$(tput setaf 3)
COLOR_BLUE=$(tput setaf 4)
COLOR_RED=$(tput setaf 1)
COLOR_RESET=$(tput sgr0)

# --- Début du script ---
echo "${COLOR_BLUE}Lancement de la mise à jour des dépôts Git...${COLOR_RESET}"
echo ""

# 1. Vérification de l'authentification GitHub
echo "🔄 Vérification de l'authentification GitHub..."
if ! gh auth status &> /dev/null; then
    echo "${COLOR_RED}Erreur : Vous n'êtes pas authentifié sur GitHub.${COLOR_RESET}"
    echo "Veuillez exécuter la commande ${COLOR_YELLOW}'gh auth login'${COLOR_RESET} pour vous connecter."
    exit 1
fi
echo "${COLOR_GREEN}Authentification réussie.${COLOR_RESET}"
echo ""

# Vérifier si le répertoire de base existe
if [ ! -d "$BASE_DIR" ]; then
    echo "${COLOR_RED}Erreur : Le répertoire de base '$BASE_DIR' n'existe pas.${COLOR_RESET}"
    exit 1
fi

# Se déplacer dans le répertoire de base pour simplifier les chemins
cd "$BASE_DIR" || exit

# 2. Parcours des sous-répertoires
for d in */; do
    # Vérifier si l'élément est bien un répertoire
    if [ ! -d "$d" ]; then
        continue
    fi

    repo_name=${d%/} # Enlève le '/' final pour un affichage propre

    # 3. Vérifier si c'est un dépôt Git
    if [ -d "$d.git" ]; then
        # 4. Vérifier si un remote pointe vers github.com
        #    'git -C "$d"' exécute la commande dans le répertoire $d sans s'y déplacer
        #    'grep -q' est silencieux et renvoie un statut de succès si le motif est trouvé
        if git -C "$d" remote -v | grep -q "github.com"; then
            echo "${COLOR_BLUE}Mise à jour de '$repo_name'...${COLOR_RESET}"
            # 5. Exécution du fetch
            #    --prune supprime les branches locales qui n'existent plus sur le remote
            #    --all récupère depuis tous les remotes
            if git -C "$d" fetch --all --prune; then
                echo "${COLOR_GREEN}Succès.${COLOR_RESET}"
            else
                echo "${COLOR_RED}Échec de la mise à jour pour '$repo_name'.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_YELLOW}Ignoré : '$repo_name' n'est pas connecté à GitHub (dépôt local).${COLOR_RESET}"
        fi
    else
        echo "${COLOR_YELLOW}Ignoré : '$repo_name' n'est pas un dépôt Git.${COLOR_RESET}"
    fi
    echo "-----------------------------------------------------"
done

echo "${COLOR_GREEN}🎉 Script terminé ! Tous les dépôts GitHub sont à jour.${COLOR_RESET}"
