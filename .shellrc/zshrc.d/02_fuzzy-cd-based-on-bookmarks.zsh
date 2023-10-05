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

# Définitions
MARKS_DIR="$XDG_DATA_HOME/marks"
DB_FILE="$MARKS_DIR/marks.sqlite"

# Création du répertoire s'il n'existe pas
mkdir -p "$MARKS_DIR"

# Création de la base de données et de la table si elles n'existent pas
if [ ! -f "$DB_FILE" ]; then
	echo "Creating marks database..."
    sqlite3 "$DB_FILE" << 'INIT'
    CREATE TABLE marks (
      dir VARCHAR(200) UNIQUE,
      weight INTEGER
    );
    CREATE INDEX _dir ON marks (dir);
INIT
fi

