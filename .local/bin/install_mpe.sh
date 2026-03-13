#!/bin/bash

# Script d'installation de Master PDF Editor pour XUbuntu
# Utilise le dépôt APT officiel de l'éditeur

set -e  # Arrête le script en cas d'erreur

# 1. Vérification des droits d'administration
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo."
  exit 1
fi

echo "--- Début de l'installation de Master PDF Editor ---"

# 2. Installation des dépendances nécessaires (curl et gpg)
echo "Vérification des outils système..."
apt update && apt install -y curl gpg

# 3. Ajout de la clé GPG (GNU Privacy Guard)
# On télécharge la clé et on l'enregistre dans le dossier des porte-clefs sécurisés
echo "Ajout de la clé de signature du dépôt..."
curl -s http://repo.code-industry.net/deb/pubmpekey.asc | gpg --dearmor | sudo tee /usr/share/keyrings/pubmpekey.gpg > /dev/null

# 4. Configuration du dépôt APT
# Création d'un fichier de source moderne (format DEB822)
echo "Configuration du dépôt Master PDF Editor..."
echo "Types: deb
URIs: http://repo.code-industry.net/deb
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/pubmpekey.gpg" | sudo tee /etc/apt/sources.list.d/master-pdf-editor.sources > /dev/null

# 5. Mise à jour et installation
echo "Mise à jour des index de paquets..."
apt update

echo "Installation de Master PDF Editor 5..."
apt install -y master-pdf-editor-5

echo "--- Installation terminée avec succès ! ---"
echo "Vous pouvez lancer l'application via votre menu XFCE ou en tapant 'master-pdf-editor-5'."
