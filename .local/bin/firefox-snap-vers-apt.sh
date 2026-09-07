#!/usr/bin/env bash
#
# firefox-snap-vers-apt.sh
#
# Bascule Firefox du paquet Snap vers le paquet .deb officiel publié par
# Mozilla sur packages.mozilla.org. Objectif : la sandbox du paquet Snap
# empêche l'extension KeePassXC-Browser de communiquer correctement avec
# KeePassXC (messagerie native bloquée par le confinement) ; le paquet
# .deb officiel n'a pas cette limitation.
#
# Usage : firefox-snap-vers-apt.sh (relance automatique avec sudo)
#
# Idempotent : peut être relancé sans risque sur un poste déjà migré.
# Les profils Firefox ne sont pas repris depuis le Snap (nouveau profil
# vide sous ~/.mozilla/firefox/ pour chaque utilisateur) — sans
# conséquence si un profil vide par groupe est de toute façon recréé à
# chaque séance.

set -euo pipefail

# Toutes les opérations sont systèmes (/etc/apt, apt, snap) : relance
# automatique en root, sans -E pour ne pas propager l'environnement
# utilisateur (readlink -f car ~/.local/bin n'est pas dans le
# secure_path de sudo).
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

echo "== État actuel du poste =="

FIREFOX_SNAP=0
if snap list firefox &>/dev/null; then
    echo "- Firefox est installé en Snap : bascule vers le paquet .deb Mozilla."
    FIREFOX_SNAP=1
else
    echo "- Firefox n'est pas (ou plus) installé en Snap."
fi

if snap list keepassxc &>/dev/null; then
    echo
    echo "ATTENTION : KeePassXC est lui aussi installé en Snap sur ce poste."
    echo "La messagerie native peut rester instable même après cette bascule"
    echo "de Firefox, le confinement pouvant aussi s'appliquer côté KeePassXC."
    echo "Si le problème persiste après ce script, vérifier une installation"
    echo ".deb ou AppImage de KeePassXC à la place du Snap."
fi

echo
echo "== Ajout du dépôt APT officiel de Mozilla =="

install -d -m 0755 /etc/apt/keyrings

wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

FINGERPRINT_ATTENDUE="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"

# gpg a besoin d'un répertoire de configuration (GNUPGHOME) existant : avec
# -n (dry-run), il refuse de le créer lui-même et échoue de façon fatale si
# le trousseau de l'utilisateur courant (ici root, sous sudo) n'a jamais
# servi. On utilise donc un répertoire jetable, propre à cet appel.
GPG_HOME="$(mktemp -d)"
trap 'rm -rf "$GPG_HOME"' EXIT
chmod 700 "$GPG_HOME"

FINGERPRINT_OBTENUE=$(
    gpg --homedir "$GPG_HOME" -n -q --import --import-options import-show \
        /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null \
    | awk '/pub/{getline; gsub(/^ +| +$/,""); print}'
)

echo "Empreinte attendue : $FINGERPRINT_ATTENDUE"
echo "Empreinte obtenue  : $FINGERPRINT_OBTENUE"
if [[ "$FINGERPRINT_OBTENUE" != "$FINGERPRINT_ATTENDUE" ]]; then
    echo "-> Les deux empreintes ne correspondent pas exactement à la lecture" >&2
    echo "   automatique (l'affichage gpg peut varier selon la version)." >&2
    echo "   Comparer les deux lignes ci-dessus à l'œil avant de continuer." >&2
fi

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    > /etc/apt/sources.list.d/mozilla.list

cat > /etc/apt/preferences.d/mozilla <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

echo
echo "== Installation du paquet .deb =="

apt update

# Le paquet firefox transitionnel d'Ubuntu (celui qui redirige vers le Snap)
# porte un epoch "1:" qui le fait toujours gagner, en version, face au vrai
# paquet Mozilla (ex. 1:1snap1-0ubuntu8 > 155.0.1~build1) : le pin à lui
# seul ne suffit pas, --allow-downgrades est nécessaire pour l'installer.
apt install -y --allow-downgrades firefox

if [[ "$FIREFOX_SNAP" -eq 1 ]]; then
    echo
    echo "== Retrait de l'ancien Firefox Snap =="
    snap remove --purge firefox
fi

echo
echo "== Terminé =="
echo "Dans KeePassXC : Outils > Paramètres > Intégration navigateur,"
echo "décocher puis recocher la case Firefox pour régénérer le fichier de"
echo "messagerie native, puis relancer la connexion depuis l'extension."
