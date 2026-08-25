#!/usr/bin/env bash
# NAME
#     install-projecteur.sh — installe Projecteur (pointeur laser Logitech Spotlight)
#
# SYNOPSIS
#     install-projecteur.sh [-f] [--from-source] [--branch REF] [--src-dir DIR]
#                           [--jobs N] [--deps-only] [-h]
#
# DESCRIPTION
#     Projecteur (https://github.com/gbin/Projecteur) est un pointeur laser
#     virtuel pour les télécommandes de présentation Logitech Spotlight : le
#     spot est dessiné à l'écran, donc visible dans un partage d'écran, un
#     enregistrement et sur le vidéoprojecteur, contrairement à un vrai laser.
#
#     Projecteur n'est pas dans les dépôts Debian/Ubuntu. Le script propose
#     deux voies :
#
#     Paquet publié (défaut). Télécharge le .deb de la dernière release GitHub
#     correspondant à la distribution, et l'installe avec apt. Quelques
#     centaines de kilo-octets, quelques secondes. La release la plus récente
#     date d'octobre 2023 et vise au mieux Ubuntu 23.04, mais le binaire reste
#     compatible avec les Ubuntu ultérieures : Qt 5.15 y est toujours fourni,
#     et « libqt5widgets5t64 » déclare « Provides: libqt5widgets5 », ce qui
#     satisfait la dépendance figée dans le paquet.
#
#     Compilation (--from-source). Clone le dépôt et compile. Utile pour
#     obtenir les correctifs postérieurs à la dernière release, ou la
#     réécriture Plasma 6. Compte plusieurs centaines de mégaoctets de paquets
#     de développement. Deux branches amont existent :
#
#       legacy/qt5   Version Qt5 / X11, multi-bureaux : XFCE (XUbuntu), KDE,
#                    et Wayland via XWayland. C'est la branche des releases.
#       develop      Réécriture native KDE Plasma. Exige Plasma 6.7+, Qt 6.10+,
#                    KPipeWire 6.7+, LayerShellQt 6.7+ et une session Wayland.
#                    Ubuntu 26.04 ne fournit que Plasma 6.6 : cette branche n'y
#                    est pas compilable, le script le vérifie et le dit.
#
#     Dans les deux cas, le script charge le module uinput et le rend
#     persistant, puis recharge les règles udev.
#
# OPTIONS
#     -f, --force      Réinstalle même si la version publiée est déjà
#                      installée, sans poser de question.
#     --from-source    Compile depuis les sources au lieu d'installer le
#                      paquet publié.
#     --branch REF     Branche ou tag à compiler : « legacy/qt5 », « develop »,
#                      « auto » (défaut) ou toute autre référence Git.
#                      Implique --from-source.
#     --src-dir DIR    Répertoire des sources (défaut : ~/.local/src/Projecteur).
#     --jobs N         Tâches de compilation parallèles (défaut : nproc).
#     --deps-only      Installe les dépendances de compilation et s'arrête.
#                      Implique --from-source.
#     -h, --help       Affiche cette aide.
#
# EXAMPLES
#     # Installation rapide depuis le paquet publié
#     install-projecteur.sh
#
#     # Compiler la branche courante pour les correctifs récents
#     install-projecteur.sh --from-source
#
#     # XUbuntu, ou KDE en session X11 : imposer la version Qt5/X11
#     install-projecteur.sh --branch legacy/qt5
#
#     # Préparer une machine sans compiler tout de suite
#     install-projecteur.sh --deps-only
#
# EXIT CODES
#     0   Projecteur installé, déjà à jour, dépendances installées
#         (--deps-only), ou installation annulée.
#     1   Erreur d'exécution : lancement en root, architecture non supportée,
#         aucun paquet adapté publié, dépendance APT introuvable, versions
#         insuffisantes pour la branche demandée, échec du téléchargement, du
#         clone, de la compilation ou de l'installation.
#     2   Erreur d'usage : option inconnue, argument manquant.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly REPO_SLUG="gbin/Projecteur"
readonly REPO_URL="https://github.com/${REPO_SLUG}.git"
readonly RELEASES_API="https://api.github.com/repos/${REPO_SLUG}/releases/latest"
readonly PACKAGE="projecteur"
readonly BRANCH_LEGACY="legacy/qt5"
readonly BRANCH_DEVELOP="develop"
readonly MODULES_CONF="/etc/modules-load.d/projecteur.conf"
readonly DESKTOP_SYSTEM="/usr/local/share/applications/projecteur.desktop"
readonly DESKTOP_OVERRIDE="${HOME}/.local/share/applications/projecteur.desktop"
readonly OVERRIDE_MARKER="X-Generated-By=install-projecteur.sh"

# Dépendances de compilation de la branche Qt5/X11. libudev-dev n'est là que
# pour fournir udev.pc, dont CMake tire le répertoire des règles udev.
readonly -a DEPS_LEGACY=(
    build-essential cmake git pkg-config lsb-release libudev-dev
    qtbase5-dev qtdeclarative5-dev libqt5x11extras5-dev
    qml-module-qtquick2 qml-module-qtgraphicaleffects
)

# Dépendances de la branche Plasma 6 / Qt 6 / Wayland, déduites des
# find_package() du CMakeLists amont — le projet ne documente les noms de
# paquets que pour Arch Linux. Voir install_build_deps() : chaque nom est
# vérifié dans APT avant l'appel à apt-get.
readonly -a DEPS_DEVELOP=(
    build-essential cmake git pkg-config lsb-release gettext
    extra-cmake-modules
    qt6-base-dev qt6-base-dev-tools qt6-declarative-dev
    qt6-shadertools-dev qt6-wayland-dev
    libkf6config-dev libkf6configwidgets-dev libkf6coreaddons-dev
    libkf6dbusaddons-dev libkf6globalaccel-dev libkf6i18n-dev
    libkf6notifications-dev libkf6package-dev libkirigami-dev
    libkf6widgetsaddons-dev libkf6windowsystem-dev libkf6xmlgui-dev
    libkpipewire-dev liblayershellqtinterface-dev libplasma-dev
)

# Versions minimales exigées par la branche develop, telles qu'écrites dans ses
# find_package(). Chaque entrée associe un paquet APT au composant qu'il fournit.
readonly -a DEVELOP_MIN_VERSIONS=(
    "qt6-base-dev:6.10"
    "extra-cmake-modules:6.7"
    "libkf6config-dev:6.7"
    "libkpipewire-dev:6.7"
    "liblayershellqtinterface-dev:6.7"
    "libplasma-dev:6.7"
)

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
    # Réimprime le bloc d'en-tête manpage (les lignes de commentaire qui
    # suivent le shebang) en retirant le préfixe « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Variables d'état
# -----------------------------------------------------------------------------
FROM_SOURCE="no"
FORCE="no"
BRANCH="auto"
SRC_DIR="${HOME}/.local/src/Projecteur"
JOBS="$(nproc 2>/dev/null || echo 2)"
DEPS_ONLY="no"
BUILD_DIR=""
TMP_DIR=""
INSTALLED_SOMETHING="no"
SESSION_TYPE=""
DESKTOP=""

# -----------------------------------------------------------------------------
# Analyse des arguments
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)    FORCE="yes"; shift ;;
            --from-source) FROM_SOURCE="yes"; shift ;;
            # --branch et --deps-only n'ont de sens que pour la compilation :
            # les activer sans exiger --from-source évite un refus inutile.
            --branch)      value_of "$1" "${2:-}"; BRANCH="$2"; FROM_SOURCE="yes"; shift 2 ;;
            --deps-only)   DEPS_ONLY="yes"; FROM_SOURCE="yes"; shift ;;
            --src-dir)     value_of "$1" "${2:-}"; SRC_DIR="$2"; shift 2 ;;
            --jobs)        value_of "$1" "${2:-}"; JOBS="$2"; shift 2 ;;
            -h|--help)     usage; exit 0 ;;
            *)             usage_error "Option inconnue : $1" ;;
        esac
    done
    [[ "$JOBS" =~ ^[0-9]+$ ]] || usage_error "--jobs attend un entier : $JOBS"
    # Chemin absolu obligatoire : « apt-get install » n'accepte un fichier que
    # si son chemin contient une barre oblique.
    SRC_DIR="$(readlink -m "$SRC_DIR")"
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
# Tier 2 : sources, compilation et téléchargement appartiennent à l'utilisateur ;
# seules l'installation des paquets et les règles udev exigent root. En root, les
# sources atterriraient dans /root et la session graphique détectée serait fausse.
check_not_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        error "Ce script ne doit pas être lancé en root."
        error "Relancez-le sans sudo : il demandera le mot de passe au besoin."
        exit 1
    fi
}

check_arch() {
    local arch
    arch="$(dpkg --print-architecture)"
    # Les releases amont ne publient que du x86_64. En compilation, rien
    # n'empêche une autre architecture, d'où la restriction au seul chemin
    # « paquet publié ».
    if [[ "$FROM_SOURCE" == "no" && "$arch" != "amd64" ]]; then
        die "Aucun paquet publié pour l'architecture ${arch}. Essayez --from-source."
    fi
}

check_deps() {
    local cmd
    for cmd in apt-get apt-cache dpkg sudo curl; do
        command -v "$cmd" &>/dev/null || die "Dépendance manquante : $cmd"
    done
}

detect_session() {
    SESSION_TYPE="${XDG_SESSION_TYPE:-inconnu}"
    local raw="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-inconnu}}"
    case "${raw^^}" in
        *KDE*|*PLASMA*) DESKTOP="kde" ;;
        *XFCE*)         DESKTOP="xfce" ;;
        *)              DESKTOP="autre" ;;
    esac
    info "Session : ${raw} / ${SESSION_TYPE}"
}

sudo_warmup() {
    info "Des droits administrateur sont nécessaires (paquet, règles udev)."
    sudo -v || die "Élévation de privilèges refusée."
    # Une compilation dure plusieurs minutes : sans rafraîchissement, le jeton
    # sudo expirerait avant l'étape d'installation.
    ( while true; do sudo -n true; sleep 50; done ) &
    _SUDO_PID=$!
    trap cleanup EXIT INT TERM
}

cleanup() {
    [[ -n "${_SUDO_PID:-}" ]] && kill "$_SUDO_PID" 2>/dev/null
    [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
    return 0
}

installed_version() {
    dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Voie 1 — paquet publié
# -----------------------------------------------------------------------------
# Les releases nomment leurs paquets « projecteur-<ver>_<distro>-<rel>-x86_64.deb »
# et s'arrêtent à ubuntu-23.04. On retient donc la version publiée la plus élevée
# qui ne dépasse pas celle du système ; à défaut (distribution plus ancienne que
# tout ce qui est publié), la plus basse disponible.
select_asset_url() {
    local distro release json
    distro="$(. /etc/os-release && echo "${ID}")"
    release="$(. /etc/os-release && echo "${VERSION_ID}")"
    info "Distribution : ${distro} ${release}" >&2

    json="$(curl -fsSL "$RELEASES_API")" || die "Impossible d'interroger l'API GitHub."

    TAG="$(echo "$json" | grep -m1 '"tag_name"' | cut -d'"' -f4)"
    [[ -n "$TAG" ]] || die "Impossible de lire le numéro de la dernière release."
    info "Dernière release : ${TAG}" >&2

    # Extraction des URL de paquets .deb de la distribution courante, triées par
    # version de distribution croissante (« sort -V » ordonne 20.04 < 20.10 < 23.04).
    local -a urls=()
    mapfile -t urls < <(echo "$json" \
        | grep -o "https://[^\"]*/projecteur-[^\"]*_${distro}-[0-9.]*-x86_64\.deb" \
        | sort -V -t'-' -k3)
    [[ ${#urls[@]} -gt 0 ]] || die "Aucun paquet publié pour la distribution « ${distro} »."

    local url chosen="" asset_rel
    for url in "${urls[@]}"; do
        asset_rel="$(basename "$url" | sed -E "s/.*_${distro}-([0-9.]+)-x86_64\.deb/\1/")"
        # dpkg --compare-versions ordonne correctement « 23.04 » et « 9 ».
        if dpkg --compare-versions "$asset_rel" le "$release"; then
            chosen="$url"
        fi
    done
    [[ -n "$chosen" ]] || chosen="${urls[0]}"

    asset_rel="$(basename "$chosen" | sed -E "s/.*_${distro}-([0-9.]+)-x86_64\.deb/\1/")"
    if [[ "$asset_rel" != "$release" ]]; then
        info "Aucun paquet pour ${distro} ${release} : repli sur celui de ${distro} ${asset_rel}." >&2
    fi
    echo "$chosen"
}

install_release_package() {
    local url deb name current new_version
    url="$(select_asset_url)"
    name="$(basename "$url")"

    TMP_DIR="$(mktemp -d)"
    # mktemp crée en 0700 ; apt abandonne ses privilèges vers l'utilisateur _apt
    # pour lire le fichier et signalerait sinon un téléchargement « unsandboxed ».
    chmod 755 "$TMP_DIR"
    deb="${TMP_DIR}/${name}"

    info "Téléchargement de ${name}…"
    curl -fSL --progress-bar -o "$deb" "$url" || die "Échec du téléchargement depuis $url"
    chmod 644 "$deb"

    # dpkg-deb échoue sur une archive tronquée : c'est la seule vérification
    # d'intégrité possible, aucune somme de contrôle n'étant publiée.
    local pkg
    pkg="$(dpkg-deb -f "$deb" Package 2>/dev/null)" || die "Archive illisible : $deb"
    [[ "$pkg" == "$PACKAGE" ]] || die "Paquet inattendu : « $pkg » au lieu de « $PACKAGE »."
    new_version="$(dpkg-deb -f "$deb" Version)"

    current="$(installed_version)"
    if [[ -n "$current" ]]; then
        info "Version déjà installée : ${current}"
        if [[ "$current" == "$new_version" && "$FORCE" != "yes" ]]; then
            success "Projecteur ${current} est déjà à jour : rien à installer."
            info "Utilisez --force pour réinstaller, --from-source pour compiler plus récent."
            # « return » et non « exit » : les étapes suivantes (lanceur Wayland,
            # vérification) restent utiles même sans réinstallation, et c'est par
            # elles qu'une machine installée avant l'ajout du lanceur le reçoit.
            return 0
        fi
    fi

    # Simulation avant l'installation réelle : le paquet fige des dépendances
    # Qt5 datant de 2023, dont certaines n'existent plus sous leur ancien nom.
    # Elles restent satisfaites par les paquets « t64 », qui déclarent un
    # « Provides » de l'ancien nom — mais autant le vérifier que le supposer.
    info "Vérification des dépendances du paquet…"
    if ! apt-get -s install "$deb" &>/dev/null; then
        error "Apt ne peut pas satisfaire les dépendances de ${name} :"
        apt-get -s install "$deb" 2>&1 | grep -E "^ |E:" | head -10 >&2
        die "Essayez --from-source pour compiler contre les bibliothèques du système."
    fi

    # Mot de passe demandé seulement maintenant : tout ce qui pouvait échouer
    # sans droits (résolution, téléchargement, intégrité, dépendances) a été
    # fait. Inutile de faire saisir un mot de passe pour renoncer ensuite.
    sudo_warmup
    info "Installation du paquet…"
    sudo apt-get install -y "$deb" || die "Échec de l'installation du paquet."
    INSTALLED_SOMETHING="yes"
    success "Paquet ${PACKAGE} ${new_version} installé."
}

# -----------------------------------------------------------------------------
# Voie 2 — compilation
# -----------------------------------------------------------------------------
# Version candidate d'un paquet APT, débarrassée de l'époque (« 4: ») et de la
# révision Debian, pour être comparable au numéro amont exigé par CMake.
# Renvoie une chaîne vide dans les deux cas d'indisponibilité qu'APT distingue :
# nom inconnu (aucune sortie) et nom connu sans version installable
# (« Candidat : (aucun) »). Les appelants n'ont ainsi qu'un seul cas à tester.
apt_candidate_version() {
    local version
    version="$(apt-cache policy "$1" 2>/dev/null \
        | awk '/Candidat|Candidate/ { print $2; exit }' \
        | sed -E 's/^[0-9]+://; s/[-+~].*$//')"
    case "$version" in
        ''|'(aucun)'|'(none)') return 0 ;;
        *) echo "$version" ;;
    esac
}

# Renvoie 0 si toutes les versions exigées par la branche develop sont
# disponibles ; sinon 1, en listant ce qui manque.
develop_requirements_met() {
    local quiet="${1:-no}" entry pkg min have ok=0
    for entry in "${DEVELOP_MIN_VERSIONS[@]}"; do
        pkg="${entry%%:*}"
        min="${entry##*:}"
        have="$(apt_candidate_version "$pkg")"
        if [[ -z "$have" ]]; then
            [[ "$quiet" == "yes" ]] || warn "Paquet absent des dépôts : ${pkg} (requis ≥ ${min})"
            ok=1
        elif ! dpkg --compare-versions "$have" ge "$min"; then
            [[ "$quiet" == "yes" ]] || warn "${pkg} : version ${have} disponible, ${min} requise."
            ok=1
        fi
    done
    return "$ok"
}

resolve_branch() {
    if [[ "$BRANCH" != "auto" ]]; then
        info "Branche imposée : ${BRANCH}"
        # Une branche explicitement demandée n'est pas contournée en silence :
        # mieux vaut le dire avant le clone et l'installation des dépendances.
        if [[ "$BRANCH" == "$BRANCH_DEVELOP" ]] && ! develop_requirements_met; then
            die "La branche ${BRANCH_DEVELOP} n'est pas compilable ici. Utilisez --branch ${BRANCH_LEGACY}."
        fi
        return 0
    fi

    info "Choix automatique de la branche…"
    if [[ "$DESKTOP" == "kde" && "$SESSION_TYPE" == "wayland" ]] && develop_requirements_met yes; then
        BRANCH="$BRANCH_DEVELOP"
        success "Session Plasma/Wayland et dépendances suffisantes : branche ${BRANCH}."
        return 0
    fi

    BRANCH="$BRANCH_LEGACY"
    if [[ "$DESKTOP" == "kde" && "$SESSION_TYPE" == "wayland" ]]; then
        info "Branche ${BRANCH} retenue : la version Plasma 6 native n'est pas compilable ici."
        develop_requirements_met || true
        warn "Sous Wayland, la version Qt5/X11 tourne via XWayland : le spot peut"
        warn "ne pas se superposer correctement aux fenêtres natives Wayland."
    else
        info "Branche ${BRANCH} retenue : version Qt5/X11, multi-bureaux."
    fi
}

install_build_deps() {
    local -a wanted=() missing=() to_install=()
    if [[ "$BRANCH" == "$BRANCH_DEVELOP" ]]; then
        wanted=("${DEPS_DEVELOP[@]}")
    else
        wanted=("${DEPS_LEGACY[@]}")
    fi

    local pkg
    for pkg in "${wanted[@]}"; do
        # Un seul nom inconnu ferait échouer apt-get sur la liste entière, avec
        # un message peu exploitable. On sépare donc les introuvables pour les
        # nommer : les paquets Qt/KDE changent de nom d'une Ubuntu à l'autre.
        if [[ -z "$(apt_candidate_version "$pkg")" ]]; then
            missing+=("$pkg")
        elif ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Paquets introuvables dans les dépôts : ${missing[*]}"
        error "Vérifiez que les composants « main » et « universe » sont activés,"
        error "ou adaptez la liste DEPS_* du script à votre version d'Ubuntu."
        exit 1
    fi

    if [[ ${#to_install[@]} -eq 0 ]]; then
        success "Dépendances de compilation déjà présentes."
        return 0
    fi

    info "Installation de ${#to_install[@]} paquet(s) : ${to_install[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${to_install[@]}" || die "Échec de l'installation des dépendances."
    success "Dépendances installées."
}

fetch_sources() {
    if [[ -d "${SRC_DIR}/.git" ]]; then
        info "Mise à jour des sources dans ${SRC_DIR}…"
        git -C "$SRC_DIR" fetch --tags --prune origin || die "Échec de git fetch."
        git -C "$SRC_DIR" checkout "$BRANCH" || die "Branche introuvable : $BRANCH"
        # --ff-only : une compilation locale ne doit jamais produire de commit
        # de fusion dans un dépôt que l'utilisateur n'a pas vocation à modifier.
        git -C "$SRC_DIR" pull --ff-only || warn "Impossible d'avancer la branche (modifications locales ?)."
    else
        info "Clone de ${REPO_URL} dans ${SRC_DIR}…"
        mkdir -p "$(dirname "$SRC_DIR")"
        # Clone complet, sans --depth : le numéro de version vient de
        # « git describe » (cmake/modules/GitVersion.cmake). Un clone superficiel
        # sans tags donnerait une version bidon dans le paquet et dans --version.
        git clone --branch "$BRANCH" "$REPO_URL" "$SRC_DIR" || die "Échec du clone."
    fi
    info "Commit : $(git -C "$SRC_DIR" describe --tags --always 2>/dev/null || echo inconnu)"
}

build_sources() {
    BUILD_DIR="${SRC_DIR}/build"

    info "Configuration CMake…"
    # Préfixe /usr/local, comme les paquets publiés : le .desktop y est trouvé
    # par les menus (XDG_DATA_DIRS inclut /usr/local/share) et l'installation ne
    # marche pas sur les fichiers d'un paquet système.
    cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DPACKAGE_TARGETS=ON \
        || die "Échec de la configuration CMake. Voir les messages ci-dessus."

    info "Compilation (${JOBS} tâche(s) parallèles)…"
    cmake --build "$BUILD_DIR" --parallel "$JOBS" || die "Échec de la compilation."
    success "Compilation terminée."
}

package_and_install() {
    info "Fabrication du paquet .deb (cible dist-package)…"
    # dist-package plutôt que « cmake --install » : le résultat reste connu de
    # dpkg, donc désinstallable par « apt remove ».
    cmake --build "$BUILD_DIR" --target dist-package || die "Échec de la cible dist-package."

    local deb
    deb="$(find "$BUILD_DIR" -maxdepth 2 -name '*.deb' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2-)"
    [[ -n "$deb" ]] || die "Aucun .deb produit dans ${BUILD_DIR}."
    info "Paquet produit : $(basename "$deb")"

    info "Installation du paquet…"
    # --allow-downgrades : revenir d'une compilation récente au paquet publié,
    # ou d'une branche à l'autre, ne doit pas buter sur un refus d'apt.
    sudo apt-get install -y --allow-downgrades "$deb" || die "Échec de l'installation du paquet."
    INSTALLED_SOMETHING="yes"
    success "Paquet ${PACKAGE} installé."
}

# -----------------------------------------------------------------------------
# Réglages post-installation
# -----------------------------------------------------------------------------
# Projecteur capte le périphérique puis réinjecte les événements par /dev/uinput.
# Les règles udev du paquet donnent l'accès à l'utilisateur de la session
# (TAG+="uaccess"), mais le module doit être chargé — et l'être encore après un
# redémarrage, ce que le postinst amont ne garantit pas.
setup_uinput() {
    # Trois états possibles, qu'il faut distinguer avant d'agir :
    #   /dev/uinput absent                      -> il faut charger le module
    #   /dev/uinput présent, /sys/module absent -> uinput est intégré au noyau
    #   /dev/uinput présent, /sys/module présent-> module chargé, à rendre persistant
    if [[ ! -e /dev/uinput ]]; then
        info "Chargement du module uinput…"
        sudo modprobe uinput || warn "Impossible de charger uinput."
    fi

    if [[ ! -e /dev/uinput ]]; then
        warn "/dev/uinput reste absent : la réinjection des touches ne fonctionnera pas."
        warn "Projecteur affichera le spot, mais les boutons du présentateur seront inertes."
        return 0
    fi

    if [[ ! -d /sys/module/uinput ]]; then
        # Compilé en dur (CONFIG_INPUT_UINPUT=y) : il n'y a rien à charger au
        # démarrage, et un fichier modules-load.d ne servirait qu'à encombrer.
        # C'est le cas des noyaux Ubuntu récents.
        info "uinput est intégré au noyau : aucun chargement à prévoir au démarrage."
        return 0
    fi

    if [[ ! -f "$MODULES_CONF" ]]; then
        info "Chargement de uinput au démarrage : ${MODULES_CONF}"
        echo "uinput" | sudo tee "$MODULES_CONF" >/dev/null
    fi
}

# Sous une session Wayland, Qt5 choisit tout seul son plugin « wayland ». Or
# Projecteur rend son incrustation traversable par Qt::WindowTransparentForInput,
# drapeau que le plugin Wayland de Qt5 n'implémente pas : la fenêtre plein écran
# avale alors tous les clics, et la souris reste prisonnière tant que
# l'application n'est pas tuée.
#
# L'amont ne gère ce cas que pour la plateforme « xcb » : son contournement
# (masquer la fenêtre quand le spot s'éteint) est conditionné à
# « platformName() == "xcb" && isWayland() », dans src/projecteurapp.cc. Forcer
# QT_QPA_PLATFORM=xcb fait donc passer Projecteur par XWayland et active ce
# contournement. Sans cela, l'application est inutilisable sur session Wayland.
setup_wayland_launcher() {
    [[ "$SESSION_TYPE" == "wayland" ]] || return 0

    # La branche develop est nativement Wayland : lui imposer XWayland serait
    # une régression, pas un correctif.
    if [[ "$FROM_SOURCE" == "yes" && "$BRANCH" == "$BRANCH_DEVELOP" ]]; then
        return 0
    fi

    if [[ ! -f "$DESKTOP_SYSTEM" ]]; then
        warn "Lanceur système introuvable (${DESKTOP_SYSTEM}) : lanceur Wayland non installé."
        return 0
    fi

    # Même prudence que pour les profils AppArmor : un lanceur personnel que ce
    # script n'a pas écrit peut porter des réglages voulus par l'utilisateur.
    if [[ -f "$DESKTOP_OVERRIDE" ]] && ! grep -q "$OVERRIDE_MARKER" "$DESKTOP_OVERRIDE"; then
        warn "Un lanceur personnel existe déjà et n'a pas été écrit par ce script :"
        warn "  ${DESKTOP_OVERRIDE}"
        warn "Il est conservé. Si le spot bloque la souris, ajoutez-y :"
        warn "  Exec=env QT_QPA_PLATFORM=xcb /usr/local/bin/projecteur"
        return 0
    fi

    info "Session Wayland : installation d'un lanceur forçant XWayland…"
    mkdir -p "$(dirname "$DESKTOP_OVERRIDE")"
    # Régénéré à chaque exécution à partir du fichier du paquet, pour suivre un
    # éventuel changement amont (icône, catégories, nom du binaire).
    {
        sed 's|^Exec=|Exec=env QT_QPA_PLATFORM=xcb |' "$DESKTOP_SYSTEM"
        echo "$OVERRIDE_MARKER"
    } > "$DESKTOP_OVERRIDE"

    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$(dirname "$DESKTOP_OVERRIDE")" 2>/dev/null || true
    fi
    success "Lanceur Wayland installé : ${DESKTOP_OVERRIDE}"
}

reload_udev() {
    info "Rechargement des règles udev…"
    sudo udevadm control --reload-rules || warn "Échec de « udevadm control --reload-rules »."
    sudo udevadm trigger || warn "Échec de « udevadm trigger »."
}

verify_install() {
    command -v projecteur &>/dev/null || die "« projecteur » introuvable dans le PATH après installation."
    local version
    version="$(projecteur --version 2>/dev/null | head -1 || true)"
    success "Projecteur installé : ${BOLD}${version:-version inconnue}${RESET}"
    info "Binaire : $(command -v projecteur)"

    echo
    # Le rebranchement n'a de sens que si les règles udev viennent d'être
    # posées ; le répéter à chaque exécution ferait douter d'une installation
    # qui n'a pourtant rien changé.
    if [[ "$INSTALLED_SOMETHING" == "yes" ]]; then
        info "Étapes suivantes :"
        info "  1. Rebranchez le récepteur USB (ou reconnectez le Bluetooth) :"
        info "     les règles udev ne s'appliquent qu'à la connexion du périphérique."
        info "  2. Lancez Projecteur depuis le menu des applications."
        info "  3. Périphérique non détecté ? projecteur -d"
    else
        info "Périphérique non détecté ? projecteur -d"
    fi
    if [[ -f "$DESKTOP_OVERRIDE" ]] && grep -q "$OVERRIDE_MARKER" "$DESKTOP_OVERRIDE"; then
        echo
        warn "Le lanceur du menu force XWayland, mais pas un lancement en terminal."
        warn "Depuis un terminal, utilisez : QT_QPA_PLATFORM=xcb projecteur"
    fi
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo -e "\n${BOLD}=== Installation de Projecteur ===${RESET}\n"

    check_not_root
    check_arch
    check_deps
    detect_session

    if [[ "$FROM_SOURCE" == "yes" ]]; then
        resolve_branch
        sudo_warmup
        install_build_deps
        if [[ "$DEPS_ONLY" == "yes" ]]; then
            success "Dépendances prêtes (--deps-only). Rien d'autre n'a été fait."
            exit 0
        fi
        fetch_sources
        build_sources
        package_and_install
    else
        # sudo_warmup est appelé depuis install_release_package, une fois les
        # vérifications passées.
        install_release_package
    fi

    # Les étapes système ne servent que si quelque chose vient d'être installé ;
    # les exécuter sinon ferait demander le mot de passe pour rien.
    if [[ "$INSTALLED_SOMETHING" == "yes" ]]; then
        setup_uinput
        reload_udev
    fi
    setup_wayland_launcher
    verify_install
}

main "$@"
