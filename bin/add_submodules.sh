#!/bin/bash

#-------------------------------------------------------------------------------
# Script SÉCURISÉ pour ajouter Oh My Zsh, les plugins et les thèmes Zsh
# en tant que submodules Git "shallow" dans un dépôt yadm.
#
# AMÉLIORATION :
# - Teste si le répertoire du submodule existe déjà avant de l'ajouter.
# - Affiche des messages clairs si le submodule est ignoré.
# - N'utilise plus `|| true`, rendant le script plus strict et lisible.
#-------------------------------------------------------------------------------

# Arrête le script immédiatement si une commande non testée échoue.
set -e

# --- LISTES DES DÉPENDANCES ---
# Ajoutez simplement les URLs Git de vos plugins et thèmes ici.

PLUGINS_URLS=(
  "https://github.com/zsh-users/zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-completions"
  "https://github.com/manastria/zsh-dircolors-solarized.git"
  "https://github.com/zsh-users/zsh-syntax-highlighting.git"
  "https://github.com/jeffreytse/zsh-vi-mode"
)

THEMES_URLS=(
  "https://github.com/romkatv/powerlevel10k.git"
)

# --- LOGIQUE DU SCRIPT ---

echo "🚀 Démarrage de l'ajout des submodules Zsh (mode sécurisé)..."

# 1. Ajout de Oh My Zsh (cas spécial)
echo "› Traitement du submodule pour Oh My Zsh..."
OMZ_PATH=".zsh/oh-my-zsh"
OMZ_URL="https://github.com/ohmyzsh/ohmyzsh.git"

# On teste l'existence du répertoire de destination
if [ -d "$OMZ_PATH" ]; then
  echo "  [INFO] Le répertoire Oh My Zsh existe déjà, on passe."
else
  echo "  [AJOUT] Clonage de Oh My Zsh..."
  git submodule add --depth 1 "$OMZ_URL" "$OMZ_PATH"
  git config -f .gitmodules "submodule.$OMZ_PATH.shallow" true
fi
echo

# 2. Ajout des plugins (boucle)
echo "› Traitement des submodules pour les plugins..."
PLUGINS_BASE_PATH=".zsh/custom/plugins"
for url in "${PLUGINS_URLS[@]}"; do
  repo_name=$(basename "$url" .git)
  plugin_path="$PLUGINS_BASE_PATH/$repo_name"
  
  if [ -d "$plugin_path" ]; then
    echo "  [INFO] Le plugin '$repo_name' existe déjà, on passe."
  else
    echo "  [AJOUT] Clonage du plugin '$repo_name'..."
    git submodule add --depth 1 "$url" "$plugin_path"
    git config -f .gitmodules "submodule.$plugin_path.shallow" true
  fi
done
echo

# 3. Ajout des thèmes (boucle)
echo "› Traitement des submodules pour les thèmes..."
THEMES_BASE_PATH=".zsh/custom/themes"
for url in "${THEMES_URLS[@]}"; do
  repo_name=$(basename "$url" .git)
  theme_path="$THEMES_BASE_PATH/$repo_name"
  
  if [ -d "$theme_path" ]; then
    echo "  [INFO] Le thème '$repo_name' existe déjà, on passe."
  else
    echo "  [AJOUT] Clonage du thème '$repo_name'..."
    git submodule add --depth 1 "$url" "$theme_path"
    git config -f .gitmodules "submodule.$theme_path.shallow" true
  fi
done
echo

# --- FIN ---
echo "✅ Script terminé."
echo "Si des submodules ont été ajoutés, n'oubliez pas de valider les changements avec :"
echo "   git add .gitmodules .zsh/"
echo "   git commit -m \"feat: Ajouter les submodules Zsh\""
