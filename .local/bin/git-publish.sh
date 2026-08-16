#!/usr/bin/env bash
# NAME
#     git-publish.sh — publie le contenu de « dev » sur « main » en un seul
#     commit instantané, sans y reporter l'historique de travail
#
# SYNOPSIS
#     git-publish.sh [MESSAGE]
#
# DESCRIPTION
#     Modèle « branche de travail / branche de publication » : main n'est pas
#     une fusion de dev, mais une suite de photographies successives de son
#     arborescence. Chaque exécution remplace intégralement le contenu de main
#     par celui de dev et l'enregistre en UN commit, si bien que main garde un
#     historique linéaire et lisible pendant que dev conserve ses commits de
#     travail, ses WIP et ses corrections. Les branches source et cible sont
#     figées en tête de script (SOURCE_BRANCH / TARGET_BRANCH).
#
# OPTIONS
#     MESSAGE   Libellé de la publication, inséré dans le sujet du commit
#               (« 📦 Publish: MESSAGE »). Facultatif : s'il est absent, le
#               script le demande de façon interactive. Le commit reçoit
#               toujours en pied de message la référence « dev@<sha> » du
#               commit source, seul lien de traçabilité entre les deux
#               branches puisqu'elles ne partagent aucune ascendance.
#
# EXAMPLES
#     # Publier avec le message donné en argument
#     git-publish.sh "Ajout du chapitre sur les VLAN"
#
#     # Sans argument : le message est demandé à l'écran
#     git-publish.sh
#
#     # Enchaîner après un commit de travail sur dev
#     git commit -am "relecture" && git-publish.sh "Corrections de relecture"
#
# EXIT CODES
#     0      Publication effectuée, retour sur la branche source.
#     1      Refus avant toute modification : mauvaise branche courante, ou
#            working tree non propre.
#     autre  Code de la commande git ayant échoué (set -e). Attention : une
#            erreur survenant après le basculement laisse le dépôt sur la
#            branche cible, arborescence en cours de remplacement.
set -euo pipefail

# Configuration
SOURCE_BRANCH="dev"
TARGET_BRANCH="main"

# Vérifications préalables
# Exiger d'être sur la branche source n'est pas qu'un garde-fou de confort :
# tout le reste du script suppose cet état de départ, jusqu'au retour final.
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT" != "$SOURCE_BRANCH" ]; then
    echo "❌ Tu dois être sur la branche $SOURCE_BRANCH (actuellement sur $CURRENT)"
    exit 1
fi

# Garde-fou critique : plus bas, « git rm -rf . » efface l'arborescence.
# Tout ce qui n'est pas commité serait perdu sans recours possible, puisque
# aucun commit ne permettrait de le retrouver. --porcelain couvre aussi les
# fichiers non suivis ('??'), qui disparaîtraient de la même manière.
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working tree pas propre. Commit ou stash d'abord."
    exit 1
fi

# Message de commit
# « ${1:-} » et non « $1 » : sous set -u, référencer un paramètre absent
# ferait avorter le script au lieu de basculer sur la saisie interactive.
MSG="${1:-}"
if [ -z "$MSG" ]; then
    read -rp "📦 Message de publication : " MSG
fi

# Capture le SHA source avant de changer de branche
# Indispensable ici et pas plus bas : après le checkout, HEAD désigne la
# branche cible et on enregistrerait le SHA de main dans sa propre référence.
SOURCE_SHA=$(git rev-parse --short HEAD)

# Synchronise avec GitHub
# --rebase : rapatrier d'éventuels commits distants sans créer de commit de
# fusion, pour que dev reste linéaire et que le SHA publié désigne bien le
# sommet réel du travail.
echo "⬇️  Pull $SOURCE_BRANCH..."
git pull origin "$SOURCE_BRANCH" --rebase

# Publication
echo "🚀 Publication sur $TARGET_BRANCH..."
git checkout "$TARGET_BRANCH"
# Échec toléré : à la toute première publication, main peut n'exister que
# localement et n'avoir aucun homologue distant à récupérer.
git pull origin "$TARGET_BRANCH" 2>/dev/null || true
# Vider puis recopier, plutôt que copier par-dessus : « git checkout dev -- . »
# seul ne fait qu'ajouter et écraser. Sans ce rm préalable, un fichier
# supprimé dans dev survivrait indéfiniment sur main.
git rm -rf . --quiet
# Recharge index et working tree depuis l'arborescence de dev. Seul le
# CONTENU est repris : l'historique de main n'est pas touché, d'où le commit
# unique qui suit au lieu d'une greffe des commits de dev.
git checkout "$SOURCE_BRANCH" -- .
git commit -m "📦 Publish: $MSG

Source: $SOURCE_BRANCH@$SOURCE_SHA"
git push origin "$TARGET_BRANCH"

# Retour
# Repose sur la branche de travail : sans ça, le prochain commit de
# l'utilisateur atterrirait sur main et casserait le modèle.
git checkout "$SOURCE_BRANCH"
echo "✅ Publié ($SOURCE_BRANCH@$SOURCE_SHA → $TARGET_BRANCH)"
