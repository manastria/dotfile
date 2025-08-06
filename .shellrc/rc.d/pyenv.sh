# Vérifie si pyenv est installé
# Si le répertoire ~/.pyenv/bin existe
if [ -d "$HOME/.pyenv/bin" ]; then
    # Ajoute le répertoire ~/.pyenv/bin au PATH
    export PATH="$HOME/.pyenv/bin:$PATH"
    # Initialise pyenv
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi
