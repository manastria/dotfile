#!/bin/sh
# ~/.shellrc/rc.d/10-locale-check.sh
# Avertit si la locale effective de la session n'est pas en UTF-8.
#
# Pourquoi : sans UTF-8, des outils comme lsblk ou tree basculent en ASCII
# (`- au lieu de └─) et les accents s'affichent mal. Cas typique : Raspberry Pi
# fraîchement installé, LANG pointant vers une locale non générée.
#
# Désactivation : `touch ~/.config/no_locale_check`

# Sentinelle : permet de couper l'avertissement sur une machine donnée
[ -f "$HOME/.config/no_locale_check" ] && return 0

command -v locale >/dev/null 2>&1 || return 0

# `locale charmap` donne le jeu de caractères réellement actif, en tenant compte
# de la priorité LC_ALL > LC_CTYPE > LANG et de l'existence de la locale générée
# (une locale absente retombe sur ANSI_X3.4-1968, c'est-à-dire l'ASCII).
_locale_charmap="$(locale charmap 2>/dev/null)"

case "$_locale_charmap" in
    UTF-8|utf8|UTF8) ;;
    *)
        printf '[ATTENTION] Locale non UTF-8 (jeu de caractères : %s, LANG=%s).\n' \
            "${_locale_charmap:-inconnu}" "${LANG:-<vide>}" >&2
        printf '            Corriger : sudo dpkg-reconfigure locales (ou raspi-config), puis se reconnecter.\n' >&2
        ;;
esac

unset _locale_charmap
