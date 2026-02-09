#!/bin/bash

# Chemins des dossiers pour la vérification
THEME_DIR="/usr/share/themes/Arc"
THEME_DARK_DIR="/usr/share/themes/Arc-Dark"

# 1. Vérifier si les deux variantes du thème sont installées
if [ ! -d "$THEME_DIR" ] || [ ! -d "$THEME_DARK_DIR" ]; then
    zenity --error --title="Thème manquant" \
    --text="L'une des variantes du thème « Arc » est manquante.\n\nInstallez-les avec :\nsudo apt install arc-theme"
    exit 1
fi

# 2. Identifier le thème actuel via xfconf-query
# CLI (Command Line Interface) pour interroger les réglages XFCE
PREVIOUS_THEME=$(xfconf-query -c xsettings -p /Net/ThemeName)

# 3. Logique de bascule et définition du nouveau thème
if [ "$PREVIOUS_THEME" = "Arc" ]; then
    NEW_THEME="Arc-Dark"
    ICON="weather-night" # Icône pour la notification
else
    NEW_THEME="Arc"
    ICON="weather-sunny"
fi

# 4. Application du changement de thème GTK (GIMP Toolkit)
xfconf-query -c xsettings -p /Net/ThemeName -s "$NEW_THEME"

# 5. Feedback utilisateur via une notification système
# Utilisation de notify-send pour le mode « bavard »
notify-send -i "$ICON" "Style visuel mis à jour" \
"Ancien thème : « $PREVIOUS_THEME »\nNouveau thème : « $NEW_THEME »"