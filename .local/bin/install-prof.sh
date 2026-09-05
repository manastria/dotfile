#!/usr/bin/env bash
# NAME
#     install-prof.sh — prépare le compte « prof » de dépannage sur une VM étudiant
#
# SYNOPSIS
#     install-prof.sh [--branch BRANCHE] [-h]
#     curl -fsSL <url-du-script> | bash
#     curl -fsSL <url-du-script> | bash -s -- --branch dev1
#
# DESCRIPTION
#     Crée (ou réinitialise) un compte local « prof » sur la VM d'un étudiant,
#     membre des groupes adm et sudo, puis y déploie les dotfiles du dépôt via
#     yadm. Objectif : disposer en quelques secondes d'un environnement de
#     dépannage complet (accès root inclus) sans toucher au compte de
#     l'étudiant.
#
#     Le script se déroule en deux temps, dans deux contextes différents :
#
#       1. sous le compte de l'étudiant, qui dispose de sudo : création du
#          compte prof, mot de passe, appartenance aux groupes, installation
#          du paquet yadm ;
#       2. sous le compte prof : clonage des dotfiles.
#
#     Toutes les opérations qui exigent le sudo de l'étudiant sont donc
#     regroupées dans la phase 1, avant la bascule vers prof.
#
#     Le script est idempotent : relancé, il réinitialise le mot de passe et
#     réaligne les dotfiles sur la branche distante.
#
#     ATTENTION — le home du compte prof est remis à l'état du dépôt à chaque
#     exécution (« yadm reset --hard »). C'est voulu : prof est un compte de
#     dépannage jetable, dont la configuration doit être prévisible. Toute
#     modification locale des dotfiles de prof est perdue.
#
#     Le mot de passe du compte prof est public (il figure dans les supports
#     de cours) : c'est un compte de VM de travaux pratiques, pas un compte
#     exposé sur un réseau non maîtrisé.
#
# OPTIONS
#     --branch BRANCHE   Branche des dotfiles à déployer. Défaut : main.
#     -h, --help         Affiche cette aide.
#
# ENVIRONMENT
#     PROF_PASSWORD   Mot de passe du compte prof. Défaut : netlab123.
#     http_proxy      Proxy à utiliser. S'il n'est pas défini, le script teste
#     https_proxy     la présence du proxy de l'établissement (port TCP 3128)
#                     et l'active automatiquement le cas échéant.
#
# EXAMPLES
#     # Usage courant, depuis la session de l'étudiant
#     URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/main/.local/bin/install-prof.sh
#     curl -fsSL "$URL" | bash
#
#     # Déployer une branche de test plutôt que main
#     curl -fsSL "$URL" | bash -s -- --branch dev1
#
#     # Forcer un proxy que la détection automatique ne trouve pas
#     export http_proxy=http://172.16.0.1:3128
#     curl -fsSL "$URL" | bash
#
#     NOTE : raw.githubusercontent.com met les fichiers en cache 5 minutes.
#     Après un push, la commande peut encore servir la version précédente.
#
# EXIT CODES
#     0   Compte prof et dotfiles en place.
#     1   Erreur d'exécution : sudo refusé, échec de useradd, d'APT, de yadm.
#     2   Erreur d'usage : option inconnue ou argument manquant.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PROF_USER="prof"
readonly PROF_PASSWORD="${PROF_PASSWORD:-netlab123}"
readonly DOTFILES_REPO="https://github.com/manastria/dotfile.git"
readonly DEFAULT_DOTFILES_BRANCH="main"
readonly PROXY_HOST="172.16.0.1"
readonly PROXY_PORT="3128"

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
    # Réimprime le bloc d'en-tête manpage en retirant le préfixe « # ».
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
DOTFILES_BRANCH="$DEFAULT_DOTFILES_BRANCH"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch)
                [ -n "${2:-}" ] || usage_error "--branch attend un nom de branche."
                DOTFILES_BRANCH="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *)         usage_error "Option inconnue : $1" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Proxy de l'établissement
# -----------------------------------------------------------------------------
# Variables passées explicitement aux commandes lancées via sudo : celui-ci
# réinitialise l'environnement, et « sudo -E » est proscrit (il propagerait
# tout l'environnement de l'utilisateur, LD_PRELOAD compris).
PROXY_ENV=()

# Un ping ne prouve que la présence de la machine, pas celle du service : le
# port peut être fermé alors que l'ICMP répond, ou l'ICMP filtré alors que le
# proxy fonctionne. On teste donc directement le port TCP, via /dev/tcp — pas
# de dépendance à nc, absent de certaines images.
proxy_is_reachable() {
    timeout 1 bash -c "exec 3<>/dev/tcp/${PROXY_HOST}/${PROXY_PORT}" 2>/dev/null
}

detect_proxy() {
    # Normalisation : seule la forme minuscule est consultée ensuite, mais
    # curl et APT acceptent les deux graphies.
    if [ -z "${http_proxy:-}" ] && [ -n "${HTTP_PROXY:-}" ]; then
        export http_proxy="$HTTP_PROXY"
        export https_proxy="${HTTPS_PROXY:-$HTTP_PROXY}"
    fi

    if [ -n "${http_proxy:-}" ]; then
        info "Proxy hérité de l'environnement : ${http_proxy}"
    elif proxy_is_reachable; then
        export http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
        export https_proxy="$http_proxy"
        info "Proxy de l'établissement détecté : ${http_proxy}"
    else
        info "Aucun proxy détecté : connexion directe."
        return 0
    fi

    PROXY_ENV=(
        "http_proxy=${http_proxy}"
        "https_proxy=${https_proxy:-$http_proxy}"
        "no_proxy=${no_proxy:-localhost,127.0.0.1}"
    )
}

# -----------------------------------------------------------------------------
# Phase 1 — opérations privilégiées (sous le compte de l'étudiant)
# -----------------------------------------------------------------------------
_SUDO_KEEPALIVE_PID=""

request_sudo() {
    [ "$(id -u)" -eq 0 ] && return 0

    info "Des droits administrateur sont nécessaires (compte prof, paquet yadm)."
    sudo -v || die "Droits administrateur refusés."

    # Le clonage des submodules peut dépasser la validité du jeton sudo
    # (5 min par défaut) : on le rafraîchit en tâche de fond pour ne pas
    # redemander le mot de passe en cours de route.
    ( while true; do sudo -n true; sleep 50; done ) &
    _SUDO_KEEPALIVE_PID=$!
    trap 'kill "${_SUDO_KEEPALIVE_PID}" 2>/dev/null || true' EXIT INT TERM
}

ensure_prof_account() {
    if id "$PROF_USER" &>/dev/null; then
        info "Compte ${PROF_USER} déjà présent : réinitialisation du mot de passe."
    else
        info "Création du compte ${PROF_USER}..."
        sudo useradd --create-home --shell /bin/bash "$PROF_USER" \
            || die "Échec de « useradd ${PROF_USER} »."
        success "Compte ${PROF_USER} créé."
    fi

    # « echo » est un builtin : le mot de passe ne transite pas par la ligne
    # de commande d'un processus, donc reste invisible dans « ps ».
    echo "${PROF_USER}:${PROF_PASSWORD}" | sudo chpasswd \
        || die "Échec de la définition du mot de passe de ${PROF_USER}."

    # adm : lecture des journaux système (/var/log), utile pour diagnostiquer
    # une panne. sudo : élévation de privilèges pour la corriger. Un compte
    # de dépannage sans l'un des deux ne sert pas à grand-chose.
    sudo usermod -aG adm,sudo "$PROF_USER" \
        || die "Échec de l'ajout de ${PROF_USER} aux groupes adm/sudo."
}

install_yadm() {
    if command -v yadm >/dev/null 2>&1; then
        success "yadm déjà installé : $(command -v yadm)"
        return 0
    fi

    info "Installation de yadm (paquet APT)..."
    # Deux commandes séparées, jamais « apt-get update && apt-get install » :
    # dans un « A && B », l'échec de A n'interrompt pas le script malgré
    # set -e (errexit ne s'applique qu'au dernier maillon d'une liste ET/OU).
    sudo env "${PROXY_ENV[@]}" DEBIAN_FRONTEND=noninteractive apt-get update -qq \
        || die "Échec de « apt-get update » (proxy injoignable ?)."
    sudo env "${PROXY_ENV[@]}" DEBIAN_FRONTEND=noninteractive apt-get install -y yadm \
        || die "Échec de l'installation du paquet yadm."
    success "yadm installé."
}

# -----------------------------------------------------------------------------
# Phase 2 — dotfiles (exécutée sous le compte prof, sans privilèges)
# -----------------------------------------------------------------------------
setup_dotfiles() {
    local repo_dir="$HOME/.local/share/yadm/repo.git"

    # Le répertoire courant hérité peut être le home de l'étudiant, illisible
    # pour prof : on se replace dans le home du compte avant tout appel à yadm.
    cd "$HOME" || die "Impossible d'accéder à ${HOME}"

    command -v yadm >/dev/null 2>&1 \
        || die "yadm est introuvable et le compte $(id -un) ne peut pas l'installer."

    if [ -d "$repo_dir" ]; then
        info "Configuration existante : récupération des branches distantes..."
        # fetch plutôt que pull : le checkout forcé qui suit impose de toute
        # façon l'état distant, et un pull échouerait sur un conflit local.
        yadm fetch --prune origin || die "Échec de « yadm fetch »."
    else
        info "Clonage des dotfiles depuis ${DOTFILES_REPO}..."
        # Sans « -b » : yadm 2.x (Ubuntu 20.04) ne transmet pas cette option à
        # git. Le clone récupère de toute façon toutes les branches, celle qui
        # nous intéresse est sélectionnée juste après.
        yadm clone "$DOTFILES_REPO" || die "Échec de « yadm clone »."
    fi

    # -f : « yadm clone » ne remplace pas les fichiers déjà présents dans le
    # home (.bashrc, .profile créés par useradd) ; sans forçage, le dépôt
    # serait cloné sans que la configuration soit appliquée.
    # -B : (re)positionne la branche locale sur la branche distante, ce qui
    # permet aussi de passer de main à une branche de test d'une exécution
    # à l'autre.
    info "Bascule du home sur ${DOTFILES_BRANCH} (modifications locales écrasées)..."
    yadm checkout -f -B "$DOTFILES_BRANCH" "origin/${DOTFILES_BRANCH}" \
        || die "Échec de la bascule sur origin/${DOTFILES_BRANCH}."

    # Non bloquant : sans les submodules zsh (oh-my-zsh, powerlevel10k), le
    # shell démarre en mode dégradé mais le compte reste utilisable.
    info "Synchronisation des submodules zsh..."
    yadm submodule update --init --recursive \
        || warn "Submodules non synchronisés : la configuration zsh sera incomplète."

    success "Dotfiles déployés dans ${HOME}."
}

# Exécute setup_dotfiles sous l'identité de prof.
#
# Le script n'est PAS retéléchargé : ses fonctions sont sérialisées avec
# declare et injectées dans le bash lancé sous prof. Cela évite un second
# aller-retour réseau à travers le proxy, et garantit que les deux phases
# exécutent exactement la même version du code — ce qui n'était pas le cas
# avec un « curl | bash » relancé depuis la session prof.
#
# sudo -H (et non -i) : on veut HOME=/home/prof sans déclencher de shell de
# login, dont les fichiers d'initialisation viennent justement d'être
# remplacés par les dotfiles.
run_dotfiles_as_prof() {
    info "Bascule vers le compte ${PROF_USER}..."
    sudo -u "$PROF_USER" -H env "${PROXY_ENV[@]}" bash -s <<PAYLOAD
set -euo pipefail
$(declare -p RED GREEN YELLOW CYAN BOLD RESET)
$(declare -p DOTFILES_REPO DOTFILES_BRANCH)
$(declare -f info success warn error die setup_dotfiles)
setup_dotfiles
PAYLOAD
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    echo -e "\n${BOLD}=== Environnement ${PROF_USER} — installation ===${RESET}\n"
    detect_proxy

    # id -un plutôt que $USER : cette variable n'est pas fiable (non définie
    # dans un shell non interactif, ou héritée du compte appelant).
    if [ "$(id -un)" = "$PROF_USER" ]; then
        info "Session ${PROF_USER} détectée : déploiement des dotfiles uniquement."
        setup_dotfiles
    else
        request_sudo
        ensure_prof_account
        install_yadm
        run_dotfiles_as_prof
    fi

    echo
    success "Environnement ${PROF_USER} prêt."
    info "Ouvrir une session prof : ${BOLD}su - ${PROF_USER}${RESET}"
}

main "$@"
