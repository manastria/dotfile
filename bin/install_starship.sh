#!/bin/bash
# ~/bin/install-extras.sh

echo "Installation des outils supplémentaires..."

# 1. Installation de Starship (localement, sans sudo)
if ! command -v starship &> /dev/null; then
    echo "Installation de Starship..."
    # L'option -y évite la demande de confirmation
    curl -sS https://starship.rs/install.sh | sh -s -- -y
else
    echo "Starship est déjà installé."
fi

# 2. Gestion des Nerd Fonts
echo ""
echo "--------------------------------------------------------"
echo "ATTENTION : Pour les icônes, une Nerd Font est requise."
echo "Starship fonctionnera sans, mais avec des symboles de remplacement."
echo ""
echo "Action manuelle requise :"
echo "1. Téléchargez une police (ex: FiraCode Nerd Font sur https://www.nerdfonts.com)"
echo "2. Installez-la dans le système ou configurez votre terminal pour l'utiliser."
echo "--------------------------------------------------------"

echo "Installation terminée. Ouvrez un nouveau terminal pour voir les changements."
