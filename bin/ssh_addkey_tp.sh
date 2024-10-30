#!/bin/sh

###############################################################
#  TITRE: Script d'ajout de clés SSH
#
#  AUTEUR:   manastria (adaptation)
#  VERSION: 1.1
#  CREATION: 2022-02-01
#  MODIFIE: 2024-07-01
#
#  DESCRIPTION: Ce script ajoute des clés SSH au fichier authorized_keys
#               en évitant les doublons et en configurant correctement les
#               permissions du répertoire .ssh.
#
#  INSTRUCTIONS D'UTILISATION:
#  1. Exécuter le script en tant qu'utilisateur dont vous souhaitez configurer les clés SSH.
#     ./add_ssh_keys.sh
#  2. Vérifier que les clés ont été ajoutées correctement.
#
#  DEPENDANCES:
#  - Aucune dépendance spécifique.
#
#  HISTORIQUE DES VERSIONS:
#  - 1.0: Version initiale.
#  - 1.1: Ajout de la vérification des doublons et amélioration des messages de journalisation.
#
#  CONTACT:
###############################################################


# Arrête le script en cas d'erreur
set -e

# Variables pour les clés SSH
KEY1="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDc+e2L7GFcoWgE2qhVpQmBq2jiCZtXj1vIpFG/+N7Yw TP04"

# Fonction pour ajouter une clé SSH si elle n'existe pas déj�
add_ssh_key() {
    KEY=$1
    if grep -qF "$KEY" ~/.ssh/authorized_keys; then
        echo "La clé SSH est déjà présente : $KEY"
    else
        echo "$KEY" >> ~/.ssh/authorized_keys
        echo "Clé SSH ajoutée : $KEY"
    fi
}

# Crée le répertoire .ssh s'il n'existe pas
setup_ssh_directory() {
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    echo "Répertoire .ssh et fichier authorized_keys créés ou déjà existants."
}

# Remplace authorized_keys s'il est un lien symbolique et qu'un fichier authorized_keys2 existe
replace_symlink() {
    # Vérifie si authorized_keys est un lien symbolique (-L) et si authorized_keys2 est un fichier régulier (-f).
    # Si ces deux conditions sont vraies, le lien symbolique est remplacé par authorized_keys2.
    if [ -L ~/.ssh/authorized_keys -a -f ~/.ssh/authorized_keys2 ]; then
        rm ~/.ssh/authorized_keys
        mv ~/.ssh/authorized_keys2 ~/.ssh/authorized_keys
        echo "Lien symbolique authorized_keys remplacé par le fichier authorized_keys2."
    fi
}

# Crée un lien symbolique vers authorized_keys
create_symlink() {
    # Supprime authorized_keys2 s'il existe (fichier ou lien symbolique)
    if [ -e ~/.ssh/authorized_keys2 ]; then
        rm ~/.ssh/authorized_keys2
    fi
    ln -sf ~/.ssh/authorized_keys ~/.ssh/authorized_keys2
    echo "Lien symbolique ~/.ssh/authorized_keys2 créé ou mis à jour."
}

# Définit les permissions
set_permissions() {
    chmod -R 700 ~/.ssh
    chmod 0600 ~/.ssh/authorized_keys*
    echo "Permissions définies pour le répertoire .ssh et les fichiers authorized_keys."
}

# Exécution des fonctions
setup_ssh_directory
add_ssh_key "$KEY1"
replace_symlink
create_symlink
set_permissions

echo "Configuration des clés SSH terminée avec succès."
