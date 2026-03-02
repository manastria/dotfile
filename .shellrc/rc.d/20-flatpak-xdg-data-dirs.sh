#!/bin/sh
# ~/.shellrc/rc.d/20-flatpak-xdg-data-dirs.sh
# Flatpak: rendre visibles les lanceurs .desktop (XFCE/Whisker)

# Si flatpak n'est pas installé, inutile de toucher à XDG_DATA_DIRS
command -v flatpak >/dev/null 2>&1 || return 0

SYS_FP="/var/lib/flatpak/exports/share"
USR_FP="$HOME/.local/share/flatpak/exports/share"

# Rien à faire si les exports Flatpak n'existent pas
[ -d "$SYS_FP" ] || [ -d "$USR_FP" ] || return 0

# Fonction: teste si un répertoire est déjà présent dans une variable de type PATH
has_path_entry() {
  # $1 = variable (ex: "$XDG_DATA_DIRS"), $2 = entrée à chercher
  case ":$1:" in
    *":$2:"*) return 0 ;;
    *)        return 1 ;;
  esac
}

XDG="${XDG_DATA_DIRS:-}"

# Ajouter /var/lib/flatpak/exports/share si absent
if [ -d "$SYS_FP" ] && ! has_path_entry "$XDG" "$SYS_FP"; then
  XDG="$SYS_FP${XDG:+:$XDG}"
fi

# Ajouter ~/.local/share/flatpak/exports/share si absent
if [ -d "$USR_FP" ] && ! has_path_entry "$XDG" "$USR_FP"; then
  XDG="$USR_FP${XDG:+:$XDG}"
fi

# Assurer un fallback minimal si XDG était vide
if [ -z "$XDG" ]; then
  XDG="/usr/local/share:/usr/share"
fi

export XDG_DATA_DIRS="$XDG"
unset SYS_FP USR_FP XDG
