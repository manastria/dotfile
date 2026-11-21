#!/usr/bin/env bash
# NAME
#     configure-vscode.sh — applique une configuration VS Code par profil
#
# SYNOPSIS
#     configure-vscode.sh [-p PROFIL]... [-n] [-E] [-i] [-d DIR] [-l] [-h]
#
# DESCRIPTION
#     Applique à VS Code une configuration décrite par des fichiers versionnés
#     dans ~/.config/vscode-profils/ : réglages (settings.json), raccourcis
#     clavier (keybindings.json) et extensions (extensions.txt, thèmes inclus).
#
#     Remplace la synchronisation intégrée de VS Code quand la configuration
#     diffère selon la machine (classe, maison…). Chaque profil est un
#     sous-répertoire ; le profil « base » est toujours appliqué en premier,
#     puis les profils demandés avec -p, dans l'ordre (le dernier l'emporte).
#
#     Fusion, jamais écrasement complet :
#       - settings.json    : chaque clé des profils est IMPOSÉE ; les autres
#                            clés du fichier local sont conservées.
#       - keybindings.json : les raccourcis manquants sont ajoutés ; les
#                            raccourcis personnels de la machine sont conservés.
#       - extensions.txt   : les extensions manquantes sont installées ; rien
#                            n'est jamais désinstallé.
#
#     Le script est idempotent : une seconde exécution ne change rien. Avant
#     toute modification d'un fichier, une copie « .bak-AAAAMMJJ_HHMMSS » est
#     créée à côté. Les fichiers de profil acceptent les commentaires et les
#     virgules finales (JSONC), comme VS Code.
#
#     Attention : quand settings.json ou keybindings.json est modifié, il est
#     réécrit en JSON standard et les commentaires qu'il contenait sont perdus
#     (ils restent dans la copie .bak). Un fichier déjà conforme n'est pas
#     réécrit.
#
# OPTIONS
#     -p, --profil NOM   Profil à appliquer après « base ». Répétable.
#     -n, --dry-run      Affiche ce qui serait modifié, sans rien écrire
#                        ni installer.
#     -E, --no-extensions
#                        Ne touche pas aux extensions (réglages et raccourcis
#                        seulement).
#     -i, --insiders     Cible VS Code Insiders (code-insiders) au lieu de code.
#     -d, --config-dir DIR
#                        Répertoire des profils (défaut :
#                        ~/.config/vscode-profils, ou $XDG_CONFIG_HOME).
#     -l, --list         Liste les profils disponibles et quitte.
#     -h, --help         Affiche cette aide.
#
# EXAMPLES
#     # Voir ce que ferait le profil « classe », sans rien modifier
#     configure-vscode.sh -p classe -n
#
#     # Appliquer le profil « maison »
#     configure-vscode.sh -p maison
#
#     # Seulement la configuration commune (base)
#     configure-vscode.sh
#
#     # Réglages et raccourcis uniquement, sans installer d'extension
#     configure-vscode.sh -p classe -E
#
# EXIT CODES
#     0   Configuration appliquée (ou déjà conforme).
#     1   Erreur d'exécution : python3 ou code absent, JSON local illisible,
#         échec d'installation d'une extension.
#     2   Erreur d'usage : option inconnue, profil introuvable.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly DEFAULT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vscode-profils"
readonly BASE_PROFILE="base"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

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

usage() {
    # Réimprime l'en-tête manpage (commentaires après le shebang) sans le
    # préfixe « # » ; par motif plutôt que par numéros de ligne pour rester
    # juste si l'en-tête évolue.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# Refuse une option à valeur laissée sans argument (sinon « shift 2 » échoue
# et set -e quitte silencieusement).
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
PROFILES=()
DRY_RUN="no"
WITH_EXTENSIONS="yes"
INSIDERS="no"
CONFIG_DIR="$DEFAULT_CONFIG_DIR"
LIST_ONLY="no"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--profil)        value_of "--profil" "${2-}";      PROFILES+=("$2"); shift 2 ;;
            -d|--config-dir)    value_of "--config-dir" "${2-}";  CONFIG_DIR="$2"; shift 2 ;;
            -n|--dry-run)       DRY_RUN="yes"; shift ;;
            -E|--no-extensions) WITH_EXTENSIONS="no"; shift ;;
            -i|--insiders)      INSIDERS="yes"; shift ;;
            -l|--list)          LIST_ONLY="yes"; shift ;;
            -h|--help)          usage; exit 0 ;;
            *)                  usage_error "Option inconnue : $1" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
CODE_BIN="code"
USER_DIR=""

# Tier 3 : le script écrit dans ~/.config et installe des extensions dans le
# profil de l'utilisateur ; lancé en root, il créerait des fichiers root dans
# son home.
check_not_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
        echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
        exit 1
    fi
}

check_prereqs() {
    command -v python3 >/dev/null 2>&1 \
        || die "'python3' est requis (fusion des fichiers JSON)."

    local config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
    if [[ "$INSIDERS" == "yes" ]]; then
        CODE_BIN="code-insiders"
        USER_DIR="$config_root/Code - Insiders/User"
    else
        USER_DIR="$config_root/Code/User"
    fi

    if [[ "$WITH_EXTENSIONS" == "yes" ]]; then
        command -v "$CODE_BIN" >/dev/null 2>&1 \
            || die "'$CODE_BIN' introuvable (voir install-vscode.sh), ou utiliser --no-extensions."
    fi
}

# Noms des profils disponibles : sous-répertoires de CONFIG_DIR.
available_profiles() {
    find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

list_profiles() {
    [[ -d "$CONFIG_DIR" ]] || die "Répertoire des profils introuvable : $CONFIG_DIR"
    info "Profils dans $CONFIG_DIR :"
    available_profiles | sed 's/^/    /'
}

# Ordre d'application : base, puis les profils demandés. Le profil « base »
# explicitement redemandé n'est pas appliqué deux fois.
LAYERS=()

resolve_layers() {
    [[ -d "$CONFIG_DIR" ]] || die "Répertoire des profils introuvable : $CONFIG_DIR (voir --config-dir)"
    [[ -d "$CONFIG_DIR/$BASE_PROFILE" ]] || die "Profil obligatoire manquant : $CONFIG_DIR/$BASE_PROFILE"

    LAYERS=("$BASE_PROFILE")
    local p
    for p in "${PROFILES[@]}"; do
        [[ "$p" == "$BASE_PROFILE" ]] && continue
        if [[ ! -d "$CONFIG_DIR/$p" ]]; then
            error "Profil inconnu : $p"
            echo "Profils disponibles : $(available_profiles | tr '\n' ' ')" >&2
            exit 2
        fi
        LAYERS+=("$p")
    done
}

# Liste, dans l'ordre des couches, les fichiers « $1 » qui existent.
layer_files() {
    local name="$1" layer
    for layer in "${LAYERS[@]}"; do
        [[ -f "$CONFIG_DIR/$layer/$name" ]] && echo "$CONFIG_DIR/$layer/$name"
    done
    return 0
}

# -----------------------------------------------------------------------------
# Fusion JSON (settings.json et keybindings.json)
# -----------------------------------------------------------------------------
# Code retour de merge_json.py : 0 = fichier modifié, 3 = déjà conforme.
readonly RC_UNCHANGED=3

# merge_json MODE CIBLE FICHIER...
#   MODE = settings | keybindings
# Le script Python est embarqué : bash ne sait pas lire du JSONC (commentaires,
# virgules finales) et jq non plus. « python3 -I » ignore l'environnement et le
# répertoire courant (aucun module tiers ne peut être chargé par accident).
merge_json() {
    local mode="$1" target="$2"; shift 2
    python3 -I - "$mode" "$target" "$DRY_RUN" "$TIMESTAMP" "$@" <<'PY'
import json, os, shutil, sys

mode, target, dry_run, stamp, *sources = sys.argv[1:]
dry_run = dry_run == "yes"


def parse_jsonc(text, path):
    """Parse du JSON avec commentaires // et /* */ et virgules finales."""
    out, i, n = [], 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:      # séquence d'échappement : on la recopie
                out.append(text[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):       # commentaire de ligne
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):       # commentaire de bloc
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        elif c in "]}":                      # virgule finale : retirée
            j = len(out) - 1
            while j >= 0 and out[j] in " \t\r\n":
                j -= 1
            if j >= 0 and out[j] == ",":
                del out[j]
            out.append(c)
        else:
            out.append(c)
        i += 1
    cleaned = "".join(out)
    if not cleaned.strip():
        return None
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        sys.exit(f"JSON illisible dans {path} : {e}")


def load(path, expected):
    if not os.path.exists(path):
        return expected()
    with open(path, encoding="utf-8") as f:
        data = parse_jsonc(f.read(), path)
    if data is None:
        return expected()
    if not isinstance(data, expected):
        sys.exit(f"{path} : type JSON inattendu ({type(data).__name__}).")
    return data


def short(v):
    s = json.dumps(v, ensure_ascii=False)
    return s if len(s) <= 60 else s[:57] + "..."


expected = dict if mode == "settings" else list
current = load(target, expected)
changes = []

if mode == "settings":
    wanted = {}
    for src in sources:
        wanted.update(load(src, dict))        # la dernière couche l'emporte
    for key, value in wanted.items():
        if key not in current:
            changes.append(f"+ {key} = {short(value)}")
            current[key] = value
        elif current[key] != value:
            changes.append(f"~ {key} : {short(current[key])} -> {short(value)}")
            current[key] = value
else:
    have = {json.dumps(e, sort_keys=True) for e in current}
    for src in sources:
        for entry in load(src, list):
            sig = json.dumps(entry, sort_keys=True)
            if sig not in have:               # ajout seulement si absent
                have.add(sig)
                current.append(entry)
                changes.append(f"+ {entry.get('key', '?')} -> {entry.get('command', '?')}")

for line in changes:
    print(line)

if not changes:
    sys.exit(3)

if not dry_run:
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if os.path.exists(target):
        shutil.copy2(target, f"{target}.bak-{stamp}")
    # Écriture atomique : un plantage ne laisse jamais un fichier tronqué.
    tmp = f"{target}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(current, f, indent=4, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, target)
PY
}

# apply_json LIBELLE MODE FICHIER_CIBLE NOM_FICHIER_PROFIL
apply_json() {
    local label="$1" mode="$2" target="$3" name="$4"
    local files=() f
    while IFS= read -r f; do files+=("$f"); done < <(layer_files "$name")

    if [[ ${#files[@]} -eq 0 ]]; then
        info "$label : aucun fichier $name dans les profils, ignoré."
        return 0
    fi

    local output rc=0
    output="$(merge_json "$mode" "$target" "${files[@]}")" || rc=$?

    case "$rc" in
        0)
            echo "$output" | sed 's/^/    /'
            if [[ "$DRY_RUN" == "yes" ]]; then
                info "$label : $(echo "$output" | wc -l) modification(s) à faire (simulation) — $target"
            else
                success "$label : $(echo "$output" | wc -l) modification(s) — $target"
            fi
            ;;
        "$RC_UNCHANGED") success "$label : déjà conforme." ;;
        *) die "$label : fusion impossible (voir le message ci-dessus)." ;;
    esac
}

# -----------------------------------------------------------------------------
# Extensions
# -----------------------------------------------------------------------------
install_extensions() {
    local files=() f
    while IFS= read -r f; do files+=("$f"); done < <(layer_files "extensions.txt")

    # Liste souhaitée : commentaires (#) et lignes vides retirés, doublons
    # supprimés en gardant l'ordre.
    local wanted=()
    if [[ ${#files[@]} -gt 0 ]]; then
        mapfile -t wanted < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "${files[@]}" | awk 'NF && !seen[tolower($0)]++')
    fi

    if [[ ${#wanted[@]} -eq 0 ]]; then
        info "Extensions : aucune extension demandée."
        return 0
    fi

    # Les identifiants d'extension sont insensibles à la casse : comparaison
    # en minuscules des deux côtés.
    local installed
    installed="$("$CODE_BIN" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

    local ext failed=0 added=0
    for ext in "${wanted[@]}"; do
        if grep -qxF "${ext,,}" <<<"$installed"; then
            continue
        fi
        if [[ "$DRY_RUN" == "yes" ]]; then
            echo "    + $ext"
            added=$((added + 1))
        elif "$CODE_BIN" --install-extension "$ext" >/dev/null 2>&1; then
            echo "    + $ext"
            added=$((added + 1))
        else
            warn "Échec d'installation : $ext"
            failed=$((failed + 1))
        fi
    done

    if [[ "$DRY_RUN" == "yes" ]]; then
        info "Extensions : $added à installer (simulation), $((${#wanted[@]} - added)) déjà présente(s)."
    elif [[ $failed -gt 0 ]]; then
        die "Extensions : $failed échec(s) sur ${#wanted[@]} (identifiant erroné, ou pas de réseau ?)."
    else
        success "Extensions : $added installée(s), $((${#wanted[@]} - added)) déjà présente(s)."
    fi
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    if [[ "$LIST_ONLY" == "yes" ]]; then
        list_profiles
        exit 0
    fi

    check_not_root
    check_prereqs
    resolve_layers

    echo -e "\n${BOLD}=== Configuration de VS Code ===${RESET}\n"
    info "Profils    : ${LAYERS[*]}"
    info "Cible      : $USER_DIR"
    [[ "$DRY_RUN" == "yes" ]] && warn "Simulation (--dry-run) : rien ne sera écrit ni installé."
    echo

    apply_json "Réglages  " settings    "$USER_DIR/settings.json"    "settings.json"
    apply_json "Raccourcis" keybindings "$USER_DIR/keybindings.json" "keybindings.json"

    if [[ "$WITH_EXTENSIONS" == "yes" ]]; then
        install_extensions
    else
        info "Extensions : ignorées (--no-extensions)."
    fi

    echo
}

main "$@"
