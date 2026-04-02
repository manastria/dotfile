# Mode emacs (défaut zsh)
bindkey -e

# Lier les raccourcis clavier spécifiés
bindkey '^Q' push-line              # Ctrl + Q

# Assurez-vous que run-help est correctement lié
autoload -Uz run-help
bindkey '\eh' run-help              # Alt + h
