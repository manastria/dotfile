#!/bin/bash

echo "Vérification de l'état des submodules..."

# La commande magique :
# - `yadm submodule status --recursive` : vérifie l'état de tous les submodules, même imbriqués.
# - `grep -q '^[-+]'` : cherche silencieusement (`-q`) les lignes qui commencent (`^`) par un `-` ou un `+`.
#   grep renvoie un code de sortie 0 (succès) s'il trouve une correspondance, et 1 (échec) sinon.

if yadm submodule status --recursive | grep -q '^[-+]'; then
    echo "⚠️  Mise à jour des submodules requise."
    echo "Lancement du téléchargement et de la mise à jour..."
    
    # La commande de mise à jour (qui, elle, a besoin d'internet)
    yadm submodule update --init --recursive
    
    echo "✅  Submodules synchronisés."
else
    echo "✅  Tous les submodules sont déjà à jour."
fi
