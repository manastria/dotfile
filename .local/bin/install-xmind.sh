#!/usr/bin/env bash
# NAME
#     install-xmind.sh — installe ou met à jour Xmind (paquet .deb officiel)
#
# SYNOPSIS
#     install-xmind.sh [-f] [--file FICHIER.deb] [--keep-deb DIR]
#                      [--no-apparmor] [-h]
#
# DESCRIPTION
#     Installe Xmind sur une Ubuntu de bureau, en particulier KUbuntu (KDE)
#     et XUbuntu (XFCE). Xmind n'est distribué ni par les dépôts Ubuntu ni
#     par un dépôt APT maison : l'éditeur ne publie qu'un fichier .deb
#     autonome, téléchargé depuis son site. Les mises à jour sont donc
#     manuelles — relancer ce script les applique.
#
#     Le script télécharge le .deb amd64 courant, l'installe avec apt (qui
#     résout les dépendances GTK/NSS de l'application Electron), puis règle
#     les deux points qui font échouer Xmind sur un bureau KDE ou XFCE :
#
#     Bac à sable Electron. Depuis Ubuntu 24.04, le noyau interdit par
#     défaut les espaces de noms utilisateur non privilégiés
#     (kernel.apparmor_restrict_unprivileged_userns=1), ce qui empêche
#     Chromium — donc Xmind — de démarrer. Le script installe un profil
#     AppArmor qui rend le droit à Xmind, plutôt que de désactiver la
#     protection pour tout le système ou de lancer l'application avec
#     --no-sandbox.
#
#     Trousseau de clés. Xmind dépend de libsecret et cherche un service
#     « Secret Service » sur le bus D-Bus de session pour stocker le jeton
#     de connexion au compte. GNOME en fournit un d'office, KDE et XFCE pas
#     toujours. Le script vérifie sa présence et indique le paquet à
#     installer selon le bureau détecté.
#
#     Le script ne télécharge rien si la version déjà installée correspond
#     à celle proposée en ligne (comparaison sur l'horodatage de build
#     présent à la fois dans le nom du fichier et dans la version dpkg).
#
# OPTIONS
#     -f, --force        Réinstalle même si la version en ligne est déjà
#                        installée, et ne pose pas la question.
#     --file FICHIER     Installe ce .deb local au lieu de télécharger.
#                        Utile hors ligne ou pour rejouer une version.
#     --keep-deb DIR     Copie le .deb téléchargé dans DIR avant de nettoyer
#                        le répertoire temporaire.
#     --no-apparmor      N'installe pas le profil AppArmor.
#     -h, --help         Affiche cette aide.
#
# EXAMPLES
#     # Installation ou mise à jour
#     install-xmind.sh
#
#     # Mise à jour forcée, en gardant le .deb pour un autre poste
#     install-xmind.sh --force --keep-deb ~/Téléchargements
#
#     # Installation d'un .deb déjà récupéré
#     install-xmind.sh --file ~/Téléchargements/Xmind-for-Linux-amd64bit-26.05.01106-202608091931.deb
#
# EXIT CODES
#     0   Xmind installé, ou déjà à jour, ou installation annulée.
#     1   Erreur d'exécution : architecture non supportée, dépendance
#         absente, téléchargement ou installation en échec.
#     2   Erreur d'usage : option inconnue, argument manquant, fichier
#         introuvable.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
# Point d'entrée officiel : une redirection 302 vers le .deb amd64 courant.
# C'est la seule URL stable — l'éditeur ne publie pas d'index de versions.
readonly DOWNLOAD_URL="https://www.xmind.app/zen/download/linux_deb/"
# Nom réel du paquet dans le .deb de l'éditeur (et non « xmind »).
readonly PACKAGE="xmind-vana"
readonly APPARMOR_PROFILE="/etc/apparmor.d/xmind"
readonly USERNS_SYSCTL="kernel.apparmor_restrict_unprivileged_userns"

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
    # Réimprime le bloc d'en-tête manpage (toutes les lignes de commentaire
    # qui suivent le shebang) en retirant le préfixe « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }
value_of() { [[ -n "$2" ]] || usage_error "$1 attend une valeur."; }

# -----------------------------------------------------------------------------
# Variables d'état
# -----------------------------------------------------------------------------
FORCE="no"
LOCAL_DEB=""
KEEP_DIR=""
WITH_APPARMOR="yes"
TMP_DIR=""
DEB_PATH=""
DESKTOP=""

# -----------------------------------------------------------------------------
# Analyse des arguments
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)    FORCE="yes"; shift ;;
            --file)        value_of "$1" "${2:-}"; LOCAL_DEB="$2"; shift 2 ;;
            --keep-deb)    value_of "$1" "${2:-}"; KEEP_DIR="$2"; shift 2 ;;
            --no-apparmor) WITH_APPARMOR="no"; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             usage_error "Option inconnue : $1" ;;
        esac
    done

    if [[ -n "$LOCAL_DEB" ]]; then
        [[ -f "$LOCAL_DEB" ]] || usage_error "Fichier introuvable : $LOCAL_DEB"
        LOCAL_DEB="$(readlink -f "$LOCAL_DEB")"
    fi
    if [[ -n "$KEEP_DIR" ]]; then
        [[ -d "$KEEP_DIR" ]] || usage_error "Répertoire introuvable : $KEEP_DIR"
    fi
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
# Tier 2 : le script mélange opérations utilisateur (téléchargement, sondage du
# bus D-Bus de session) et opérations système (apt, /etc/apparmor.d). Il doit
# tourner sous l'utilisateur : en root, le bus de session n'est pas le bon et la
# vérification du trousseau serait fausse.
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
    # L'éditeur ne publie qu'une build amd64 : pas d'arm64, pas de 32 bits.
    [[ "$arch" == "amd64" ]] || die "Architecture $arch non supportée : Xmind n'est publié qu'en amd64."
}

check_deps() {
    local cmd
    for cmd in curl dpkg dpkg-deb apt-get sudo; do
        command -v "$cmd" &>/dev/null || die "Dépendance manquante : $cmd"
    done
}

detect_desktop() {
    # XDG_CURRENT_DESKTOP vaut « KDE » sur KUbuntu, « XFCE » sur XUbuntu ;
    # il peut contenir plusieurs valeurs séparées par « : ».
    local raw="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-inconnu}}"
    case "${raw^^}" in
        *KDE*|*PLASMA*) DESKTOP="kde" ;;
        *XFCE*)         DESKTOP="xfce" ;;
        *)              DESKTOP="autre" ;;
    esac
    info "Bureau détecté : ${raw} (traité comme « ${DESKTOP} »)"
}

# Arrête le rafraîchisseur sudo et supprime le répertoire temporaire, quel que
# soit le chemin de sortie (succès, erreur, Ctrl-C).
cleanup() {
    [[ -n "${_SUDO_PID:-}" ]] && kill "$_SUDO_PID" 2>/dev/null
    [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
    return 0
}

sudo_warmup() {
    info "Des droits administrateur sont nécessaires pour installer le paquet."
    sudo -v || die "Élévation de privilèges refusée."
    # Le .deb pèse plus de 200 Mo : sur une liaison lente, le téléchargement
    # dépasse la durée de validité du jeton sudo. On le rafraîchit en fond.
    ( while true; do sudo -n true; sleep 50; done ) &
    _SUDO_PID=$!
    trap cleanup EXIT INT TERM
}

# -----------------------------------------------------------------------------
# Résolution de version
# -----------------------------------------------------------------------------
# Le nom du fichier publié (…-26.05.01106-202608091931.deb) et la version dpkg
# (26.5.1106-202608091931) ne se déduisent pas l'un de l'autre : les zéros de
# tête disparaissent. Seul l'horodatage de build final, identique dans les deux,
# permet une comparaison fiable — et évite un téléchargement de 200 Mo inutile.
build_id_of_string() {
    local s="$1"
    [[ "$s" =~ ([0-9]{12}) ]] && echo "${BASH_REMATCH[1]}" || echo ""
}

installed_version() {
    dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null || true
}

# Suit la redirection sans rien télécharger et renvoie l'URL finale du .deb.
resolve_remote_url() {
    local url
    url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$DOWNLOAD_URL")" \
        || die "Impossible de contacter ${DOWNLOAD_URL}"
    # Garde-fou indispensable : le site répond 200 à n'importe quel chemin sous
    # /zen/download/ et sert alors un vieux binaire Windows. Sans ce test, un
    # changement d'URL côté éditeur ferait installer n'importe quoi.
    [[ "$url" == *.deb ]] || die "L'URL résolue n'est pas un .deb : $url"
    echo "$url"
}

# -----------------------------------------------------------------------------
# Téléchargement et installation
# -----------------------------------------------------------------------------
download_deb() {
    local url="$1" name
    name="$(basename "$url")"
    TMP_DIR="$(mktemp -d)"
    # mktemp crée le répertoire en 0700 : apt, qui abandonne ses privilèges vers
    # l'utilisateur _apt pour lire le fichier, s'en plaindrait. On ouvre l'accès
    # en lecture pour éviter l'avertissement « Download is performed unsandboxed ».
    chmod 755 "$TMP_DIR"
    DEB_PATH="${TMP_DIR}/${name}"

    info "Téléchargement de ${name} (environ 230 Mo)…"
    curl -fSL --progress-bar -o "$DEB_PATH" "$url" \
        || die "Échec du téléchargement depuis $url"
    chmod 644 "$DEB_PATH"
}

verify_deb() {
    local pkg
    # dpkg-deb échoue si l'archive est tronquée ou n'est pas un .deb : c'est la
    # vérification d'intégrité, l'éditeur ne publiant aucune somme de contrôle.
    pkg="$(dpkg-deb -f "$DEB_PATH" Package 2>/dev/null)" \
        || die "Archive illisible ou corrompue : $DEB_PATH"
    [[ "$pkg" == "$PACKAGE" ]] \
        || die "Paquet inattendu dans l'archive : « $pkg » au lieu de « $PACKAGE »."
    info "Paquet vérifié : ${pkg} $(dpkg-deb -f "$DEB_PATH" Version)"
}

install_deb() {
    info "Installation du paquet (apt résout les dépendances)…"
    # apt plutôt que dpkg -i : les dépendances (libgtk-3-0, libnss3, libsecret…)
    # sont installées dans la foulée au lieu de laisser le paquet mal configuré.
    sudo apt-get install -y "$DEB_PATH" || die "Échec de l'installation du paquet."
    success "Paquet ${PACKAGE} installé."
}

keep_deb() {
    [[ -n "$KEEP_DIR" ]] || return 0
    cp "$DEB_PATH" "$KEEP_DIR/" && info "Copie du .deb conservée dans ${KEEP_DIR}/"
}

# -----------------------------------------------------------------------------
# Réglages post-installation
# -----------------------------------------------------------------------------
# Chemin réel du binaire, lu dans la liste des fichiers du paquet plutôt que
# codé en dur : l'éditeur a déjà changé la casse du répertoire (/opt/Xmind,
# /opt/XMind) d'une version à l'autre.
xmind_binary() {
    dpkg -L "$PACKAGE" 2>/dev/null \
        | grep -E '^/opt/[^/]+/[A-Za-z]*[Xx]mind$' \
        | head -1
}

configure_apparmor() {
    [[ "$WITH_APPARMOR" == "yes" ]] || { info "Profil AppArmor ignoré (--no-apparmor)."; return 0; }

    local restricted
    restricted="$(sysctl -n "$USERNS_SYSCTL" 2>/dev/null || echo "")"
    if [[ "$restricted" != "1" ]]; then
        info "Espaces de noms utilisateur non restreints : aucun profil AppArmor nécessaire."
        return 0
    fi
    if ! command -v apparmor_parser &>/dev/null; then
        warn "AppArmor actif mais apparmor_parser introuvable : profil non installé."
        warn "Si Xmind ne démarre pas, installez le paquet apparmor."
        return 0
    fi

    local bin
    bin="$(xmind_binary)"
    if [[ -z "$bin" ]]; then
        warn "Binaire Xmind introuvable dans le paquet : profil AppArmor non installé."
        return 0
    fi

    info "Installation du profil AppArmor pour ${bin}…"
    # Profil « unconfined » qui n'accorde qu'une chose : le droit de créer des
    # espaces de noms utilisateur (userns). C'est la méthode retenue par Ubuntu
    # pour les navigateurs empaquetés hors dépôts. L'alternative — passer le
    # sysctl à 0 ou lancer avec --no-sandbox — affaiblirait tout le système ou
    # désactiverait le bac à sable de Xmind.
    sudo tee "$APPARMOR_PROFILE" >/dev/null <<PROFILE
# Profil généré par install-xmind.sh
# Autorise Xmind (Electron/Chromium) à créer des espaces de noms utilisateur,
# nécessaires à son bac à sable, sans toucher au réglage global
# ${USERNS_SYSCTL}.
abi <abi/4.0>,
include <tunables/global>

profile xmind "${bin}" flags=(unconfined) {
  userns,

  include if exists <local/xmind>
}
PROFILE

    if sudo apparmor_parser -r "$APPARMOR_PROFILE" 2>/dev/null; then
        success "Profil AppArmor chargé : ${APPARMOR_PROFILE}"
    else
        warn "Le profil AppArmor n'a pas pu être chargé (syntaxe ABI trop récente ?)."
        warn "Supprimez ${APPARMOR_PROFILE} et relancez avec --no-apparmor si Xmind refuse de démarrer."
    fi
}

check_secret_service() {
    # Sans service « Secret Service », Xmind démarre mais ne conserve pas la
    # session du compte : l'utilisateur doit se reconnecter à chaque lancement.
    if ! command -v gdbus &>/dev/null; then
        info "gdbus absent : vérification du trousseau de clés ignorée."
        return 0
    fi
    # Deux listes à interroger, et pas une seule : gnome-keyring déclare un
    # service D-Bus activable à la demande (ListActivatableNames), tandis que
    # KWallet occupe le nom org.freedesktop.secrets au vol via
    # org.kde.secretservicecompat, sans fichier de service — il n'apparaît donc
    # que dans les noms déjà pris (ListNames).
    local method
    for method in ListNames ListActivatableNames; do
        if gdbus call --session --dest org.freedesktop.DBus \
                --object-path /org/freedesktop/DBus \
                --method "org.freedesktop.DBus.${method}" 2>/dev/null \
                | grep -q "org.freedesktop.secrets"; then
            success "Trousseau de clés disponible (org.freedesktop.secrets)."
            return 0
        fi
    done

    warn "Aucun trousseau de clés (org.freedesktop.secrets) sur le bus de session."
    warn "Xmind ne pourra pas mémoriser la connexion à votre compte."
    case "$DESKTOP" in
        kde)  warn "Sur KUbuntu : sudo apt install kwalletmanager kwallet-pam" ;;
        xfce) warn "Sur XUbuntu : sudo apt install gnome-keyring seahorse" ;;
        *)    warn "Installez gnome-keyring (GTK) ou kwalletmanager (KDE), puis rouvrez la session." ;;
    esac
}

refresh_desktop_db() {
    # KDE et XFCE relisent le menu au démarrage : sans ce rafraîchissement,
    # l'entrée Xmind peut n'apparaître qu'à la session suivante.
    if command -v update-desktop-database &>/dev/null; then
        sudo update-desktop-database /usr/share/applications &>/dev/null || true
    fi
    if command -v gtk-update-icon-cache &>/dev/null; then
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor &>/dev/null || true
    fi
}

verify_install() {
    local version bin
    version="$(installed_version)"
    [[ -n "$version" ]] || die "${PACKAGE} introuvable après installation."
    bin="$(xmind_binary)"
    success "Xmind ${BOLD}${version}${RESET} installé."
    [[ -n "$bin" ]] && info "Binaire : ${bin}"
    info "Lancement : depuis le menu des applications, ou « xmind » si le lien est dans le PATH."
    info "Mise à jour : relancez ce script (Xmind n'a pas de dépôt APT)."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo -e "\n${BOLD}=== Installation de Xmind ===${RESET}\n"

    check_not_root
    check_arch
    check_deps
    detect_desktop

    local current current_build
    current="$(installed_version)"
    [[ -n "$current" ]] && info "Version déjà installée : ${current}"

    if [[ -n "$LOCAL_DEB" ]]; then
        DEB_PATH="$LOCAL_DEB"
        sudo_warmup
        verify_deb
    else
        local url remote_build
        info "Résolution de la version publiée…"
        url="$(resolve_remote_url)"
        remote_build="$(build_id_of_string "$(basename "$url")")"
        current_build="$(build_id_of_string "$current")"
        info "Build publiée : ${remote_build:-inconnue}"

        if [[ -n "$remote_build" && "$remote_build" == "$current_build" && "$FORCE" != "yes" ]]; then
            success "Xmind ${current} est déjà à jour. Rien à faire."
            info "Utilisez --force pour réinstaller malgré tout."
            exit 0
        fi
        if [[ -n "$current" && "$FORCE" != "yes" ]]; then
            read -r -p "$(echo -e "${YELLOW}Mettre à jour vers la build ${remote_build} ?${RESET} [O/n] ")" answer
            [[ "$answer" =~ ^[nN]$ ]] && { info "Installation annulée."; exit 0; }
        fi

        sudo_warmup
        download_deb "$url"
        verify_deb
        keep_deb
    fi

    install_deb
    configure_apparmor
    check_secret_service
    refresh_desktop_db
    verify_install
}

main "$@"
