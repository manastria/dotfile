# -*- mode: shell-script -*-

# ==============================================================================
# CONFIGURATION DE ZSH-AUTOSUGGESTIONS (Optimisée pour clavier compact)
# ==============================================================================

# --- 1. Stratégies de recherche et gestion de la mémoire tampon (*buffer*) ---

# Définit l'ordre des sources de suggestions : d'abord l'historique, puis les complétions natives.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
# -> COMMENTÉ / SUPPRIMÉ : Par défaut, ce paramètre bride l'extension. Le *buffer* représente 
# la ligne de commande en cours de saisie. Si elle dépasse le nombre de caractères indiqué (ici 20), 
# le *plugin* s'arrête complètement de chercher. Pour éviter d'être bloqué lors de la saisie de longs 
# chemins de fichiers ou de commandes complexes, on supprime cette limite en commentant la ligne.


# --- 2. Documentation des déclencheurs (*widgets* de la ZLE - *Zsh Line Editor*) ---
#
# Le *plugin* utilise ces cinq tableaux pour associer un comportement aux *widgets* (les fonctions 
# internes du *shell*) lorsque ces derniers sont appelés au clavier :
#
# - ZSH_AUTOSUGGEST_CLEAR_WIDGETS   : Efface immédiatement la suggestion en gris (ex: touche Entrée ou Ctrl+R).
# - ZSH_AUTOSUGGEST_ACCEPT_WIDGETS  : Valide la totalité de la suggestion en cours (ex: touche Fin).
# - ZSH_AUTOSUGGEST_EXECUTE_WIDGETS : Valide la suggestion et l'exécute instantanément (vide par défaut).
# - ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS : Accepte la suggestion uniquement jusqu'à la position du curseur.
# - ZSH_AUTOSUGGEST_IGNORE_WIDGETS  : L'action s'exécute normalement sans modifier la suggestion en gris.


# --- 3. Personnalisation du comportement (Bascule des *widgets*) ---
#
# Pour un clavier compact, on souhaite que la commande de marche avant standard (Ctrl+F) 
# valide la suggestion caractère par caractère au lieu de la gober entièrement.

# Étape A : On RETIRE le comportement d'acceptation complète pour la marche avant
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#forward-char}")
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#vi-forward-char}")

# Étape B : On L'AJOUTE au tableau de l'acceptation partielle
# L'opérateur « += » permet d'ajouter nos éléments en préservant le reste du tableau natif.
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS+=(forward-char vi-forward-char)


# --- 4. Explication de la syntaxe avancée de retrait Zsh ---
#
# La formule utilisée ci-dessus : "${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#forward-char}"
# Elle s'appuie sur des fonctionnalités puissantes du *shell* :
# - « ZSH_AUTOSUGGEST_ACCEPT_WIDGETS » : C'est le tableau que l'on inspecte.
# - « :#forward-char » : L'opérateur « :# » demande à Zsh de filtrer le tableau et d'exclure 
#   tout élément qui correspond exactement au motif qui suit (ici, le nom du *widget*).
# - « (@) » : C'est un *flag* (indicateur) interne qui force l'interprétation sous forme de 
#   véritable tableau (*array*), garantissant que chaque élément reste bien distinct.
# - Les guillemets doubles « "..." » : Travaillent de concert avec le *flag* (@) pour empêcher 
#   le découpage accidentel des éléments s'ils contenaient des espaces.


# --- 5. Rappel de la navigation en mode Emacs (*emacs mode*) ---
#
# Sur ton clavier compact, aucun besoin d'ajouter des lignes « bindkey ». Zsh associe 
# déjà nativement ces raccourcis aux *widgets* que notre *plugin* intercepte désormais :
#
# - Ctrl + F (déclenche forward-char) -> Avance d'un caractère (validation partielle)
# - Alt + F  (déclenche forward-word) -> Avance d'un mot (validation partielle par défaut)
# - Ctrl + E (déclenche end-of-line)  -> Va en fin de ligne (validation complète de la suggestion)
