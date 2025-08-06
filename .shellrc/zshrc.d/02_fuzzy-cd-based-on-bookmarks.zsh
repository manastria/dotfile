# XDG configuration home
if [[ -z $XDG_CONFIG_HOME ]]
then
   export XDG_CONFIG_HOME=$HOME/.config
fi

# XDG data home
if [[ -z $XDG_DATA_HOME ]]
then
   export XDG_DATA_HOME=$HOME/.local/share
fi


# Le répertoire à ajouter à fpath
NEW_FPATH_DIR="$HOME/.zsh/autoload/fuzzy"

# Vérification de l'existence du répertoire et de son absence dans fpath
if [[ -d "$NEW_FPATH_DIR" ]] && [[ ":$fpath:" != *":$NEW_FPATH_DIR:"* ]]; then
    fpath=("$NEW_FPATH_DIR" $fpath)
fi

autoload -Uz c             ## fuzzy cd
autoload -Uz ccleanup      ## bookmarks cleanup
autoload -Uz update_marks  ## bookmarks update


chpwd_functions+=(update_marks)

###########################
# Create database
###########################

#!/bin/bash

# Nom personnalisé pour le processus lors de l'envoi des logs à journalctl
PROCESS_NAME="fuzzy-cd"

# Envoyer un log indiquant le début de l'exécution du script
logger -t "$PROCESS_NAME" "Démarrage du script."

# Créer le dossier pour la base de données si nécessaire
mkdir -p "${XDG_DATA_HOME}/marks"

# Vérifier le succès de la création du dossier
if [ $? -eq 0 ]; then
    logger -t "$PROCESS_NAME" "Dossier ${XDG_DATA_HOME}/marks créé ou déjà existant."
else
    # Si le dossier n'a pas été créé, envoyer un log d'erreur et quitter le script
    logger -t "$PROCESS_NAME" "Erreur lors de la création du dossier ${XDG_DATA_HOME}/marks."
    exit 1
fi

# Vérifiez si la table "marks" existe déjà dans la base de données
TABLE_EXISTS=$(sqlite3 "${XDG_DATA_HOME}/marks/marks.sqlite" "SELECT name FROM sqlite_master WHERE type='table' AND name='marks';")

# Si la table "marks" n'existe pas, procédez à sa création
if [ -z "$TABLE_EXISTS" ]; then
    sqlite3 "${XDG_DATA_HOME}/marks/marks.sqlite" << 'INIT'
CREATE TABLE marks (
  dir VARCHAR(200) UNIQUE,
  weight INTEGER
);

CREATE INDEX _dir ON marks (dir);
INIT
    # Vérifier le succès de la création de la table
    if [ $? -eq 0 ]; then
        logger -t "$PROCESS_NAME" "Table 'marks' créée avec succès."
    else
        # Si la table n'a pas été créée, envoyer un log d'erreur et quitter le script
        logger -t "$PROCESS_NAME" "Erreur lors de la création de la table 'marks'."
        exit 1
    fi
else
    # Si la table "marks" existe déjà, envoyer un log pour l'indiquer
    logger -t "$PROCESS_NAME" "La table 'marks' existe déjà."
fi

# Envoyer un log indiquant la fin de l'exécution du script
logger -t "$PROCESS_NAME" "Fin du script."
