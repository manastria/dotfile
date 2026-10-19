#!/usr/bin/env bash
# NAME
#     install-fonts.sh - installe des polices (.ttf/.otf/.ttc) pour l'utilisateur courant
#
# SYNOPSIS
#     install-fonts.sh [--force] [RÉPERTOIRE]
#     install-fonts.sh -h | --help
#
# DESCRIPTION
#     Cherche récursivement les fichiers .ttf, .otf et .ttc (insensible à la casse)
#     dans RÉPERTOIRE, les copie dans ~/.local/share/fonts puis reconstruit
#     le cache des polices avec fc-cache. Aucun droit root n'est nécessaire :
#     le script refuse d'ailleurs de tourner en root.
#     Les fichiers sont copiés à plat. Une police déjà présente dans la
#     destination n'est jamais écrasée (elle est ignorée avec un avertissement),
#     sauf avec --force. Deux polices de même nom dans des sous-dossiers
#     différents sont donc aussi ignorées après la première ; avec --force,
#     la dernière gagne (avertissement).
#     Le script est relançable sans risque.
#
# OPTIONS
#     RÉPERTOIRE   répertoire contenant les polices (défaut : répertoire courant)
#     -f, --force  écrase les polices déjà installées
#     -h, --help   affiche cette aide
#
# EXAMPLES
#     install-fonts.sh                      # polices du répertoire courant
#     install-fonts.sh ~/Downloads/FiraCode # polices d'un dossier dézippé
#     install-fonts.sh --force .            # réinstalle en écrasant l'existant
#
# EXIT CODES
#     0   succès (ou aide affichée, ou toutes les polices déjà présentes)
#     1   erreur : option inconnue, répertoire introuvable, aucune police,
#         fc-cache absent, exécution en root
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly DEST_DIR="$HOME/.local/share/fonts"

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Arguments et vérifications préalables
# -----------------------------------------------------------------------------
SRC_DIR="."
FORCE="no"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Aide : l'en-tête, de la ligne 2 jusqu'à la première ligne vide
            -h|--help) sed -n '2,/^$/{/^$/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
            -f|--force) FORCE="yes"; shift ;;
            -*) die "Option inconnue : $1 (voir --help)" ;;
            *)  SRC_DIR="$1"; shift ;;
        esac
    done
}

check_prereqs() {
    # Écrire dans $HOME en root créerait des fichiers appartenant à root
    if [ "$(id -u)" -eq 0 ]; then
        echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
        echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
        exit 1
    fi
    [ -d "$SRC_DIR" ] || die "Le répertoire '$SRC_DIR' n'existe pas."
    command -v fc-cache &>/dev/null \
        || die "fc-cache introuvable (installer le paquet fontconfig)."
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
install_fonts() {
    local file name count=0 skipped=0
    # Noms déjà vus pendant cette exécution, pour repérer les collisions
    declare -A seen=()

    mkdir -p "$DEST_DIR"
    info "Recherche de polices dans : $SRC_DIR"

    # -print0 / read -d '' : noms avec espaces ou retours à la ligne sûrs
    while IFS= read -r -d '' file; do
        name="$(basename "$file")"
        if [[ -e "$DEST_DIR/$name" && "$FORCE" != "yes" ]]; then
            warn "Déjà présent, ignoré : $name (--force pour écraser)"
            skipped=$((skipped + 1))
            continue
        fi
        if [[ -n "${seen[$name]:-}" ]]; then
            warn "Doublon '$name' : '$file' remplace '${seen[$name]}'."
        fi
        seen[$name]="$file"
        cp -v "$file" "$DEST_DIR/"
        count=$((count + 1))
    done < <(find "$SRC_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" \) -print0)

    if [ "$count" -eq 0 ]; then
        [ "$skipped" -gt 0 ] || die "Aucune police (.ttf/.otf/.ttc) trouvée dans '$SRC_DIR'."
        success "Rien à installer : ${skipped} police(s) déjà présente(s)."
        return 0
    fi

    info "Mise à jour du cache des polices..."
    fc-cache -f
    success "${BOLD}${count}${RESET} fichier(s) installé(s) dans $DEST_DIR (${skipped} ignoré(s))."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    echo -e "\n${BOLD}=== Installation de polices (utilisateur) ===${RESET}\n"
    check_prereqs
    install_fonts
}

main "$@"
