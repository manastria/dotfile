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
#     membre des groupes adm et sudo, autorisé en SSH par clé publique, puis y
#     déploie les dotfiles du dépôt via yadm. Objectif : disposer en quelques
#     secondes d'un environnement de dépannage complet (accès root inclus,
#     joignable à distance) sans toucher au compte de l'étudiant.
#
#     Le script se déroule en deux temps, dans deux contextes différents :
#
#       1. sous le compte de l'étudiant, qui dispose de sudo : création du
#          compte prof, mot de passe, appartenance aux groupes, clé SSH
#          autorisée, installation du paquet yadm ;
#       2. sous le compte prof : clonage des dotfiles.
#
#     Toutes les opérations qui exigent le sudo de l'étudiant sont donc
#     regroupées dans la phase 1, avant la bascule vers prof.
#
#     Le script et les dotfiles vivent dans le même dépôt : si --branch désigne
#     une branche différente de celle depuis laquelle le script a été récupéré
#     par curl, il se retélécharge depuis la bonne branche et se relance tout
#     seul (une fois), afin que le code exécuté et les dotfiles déployés
#     proviennent toujours de la même branche. Ce mécanisme ne se déclenche
#     jamais sur une exécution locale (bash install-prof.sh) : seul l'usage
#     curl | bash est concerné.
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
#     PROF_PASSWORD    Mot de passe du compte prof. Défaut : netlab123.
#     PROF_SSH_PUBKEY  Clé publique à autoriser dans ~prof/.ssh/authorized_keys.
#                      Chaîne vide pour ne pas toucher au fichier. Défaut :
#                      une clé ed25519 fixe, embarquée dans le script.
#     http_proxy       Proxy à utiliser. S'il n'est pas défini, le script
#     https_proxy      teste la présence du proxy de l'établissement (port TCP
#                      3128) et l'active automatiquement le cas échéant.
#
# EXAMPLES
#     # Usage courant, depuis la session de l'étudiant
#     URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/${BRANCH:-main}/.local/bin/install-prof.sh
#     curl -fsSL "$URL" | bash -s
#
#     # Tester une branche de développement : un seul BRANCH à changer, script
#     # ET dotfiles suivent (le script se relance seul si l'URL ne suivait pas)
#     BRANCH=dev1
#     URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/${BRANCH:-main}/.local/bin/install-prof.sh
#     curl -fsSL "$URL" | bash -s -- --branch "$BRANCH"
#
#     # Forcer un proxy que la détection automatique ne trouve pas
#     export http_proxy=http://172.16.0.1:3128
#     URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/${BRANCH:-main}/.local/bin/install-prof.sh
#     curl -fsSL "$URL" | bash -s
#
#     NOTE : BRANCH doit toujours être définie AVANT la ligne URL=... qui s'en
#     sert : le shell substitue sa valeur au moment de CETTE affectation, pas
#     plus tard quand $URL est utilisée. Redéfinir BRANCH après coup ne change
#     plus rien à une URL déjà construite.
#
#     NOTE : raw.githubusercontent.com met les fichiers en cache 5 minutes.
#     Après un push, la commande peut encore servir la version précédente.
#
# EXIT CODES
#     0   Compte prof et dotfiles en place.
#     1   Erreur d'exécution : sudo refusé, échec de useradd, d'APT, de yadm,
#         ou de la relance automatique depuis une autre branche.
#     2   Erreur d'usage : option inconnue ou argument manquant.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PROF_USER="prof"
readonly PROF_PASSWORD="${PROF_PASSWORD:-netlab123}"
readonly PROF_SSH_PUBKEY="${PROF_SSH_PUBKEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDc+e2L7GFcoWgE2qhVpQmBq2jiCZtXj1vIpFG/+N7Yw}"
readonly DOTFILES_REPO="https://github.com/manastria/dotfile.git"
readonly DEFAULT_DOTFILES_BRANCH="main"
readonly SCRIPT_RAW_URL_BASE="https://raw.githubusercontent.com/manastria/dotfile/refs/heads"
readonly SCRIPT_RAW_PATH=".local/bin/install-prof.sh"
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
# Auto-relance depuis la bonne branche (usage curl | bash uniquement)
# -----------------------------------------------------------------------------
# Le script et les dotfiles vivent dans le même dépôt : demander --branch dev1
# doit faire tourner le install-prof.sh de dev1, pas seulement y aligner les
# dotfiles. Or le contenu déjà exécuté à cet instant est celui de l'URL passée
# à curl, indépendamment de --branch. Si les deux divergent, on se retélécharge
# depuis la bonne branche et on se relance avec les mêmes arguments.
relaunch_from_branch_if_needed() {
    # En usage « curl | bash », $0 vaut « bash » : bash lit le script depuis
    # l'entrée standard, il n'existe aucun fichier de ce nom en pratique. Une
    # exécution locale (bash install-prof.sh, ./install-prof.sh) a un $0 qui
    # pointe vers un fichier réel : on ne retélécharge jamais dans ce cas, pour
    # ne pas écraser des modifications non poussées en cours de test.
    [ -f "$0" ] && return 0

    # Garde-fou anti-boucle : la version relancée exporte cette variable avant
    # de s'exécuter, pour ne jamais tenter une seconde relance.
    [ -n "${_INSTALL_PROF_RELAUNCHED:-}" ] && return 0

    # Rien à faire si on déploie déjà la branche par défaut : la version
    # récupérée par le curl initial (sur main, par convention) convient.
    [ "$DOTFILES_BRANCH" = "$DEFAULT_DOTFILES_BRANCH" ] && return 0

    command -v curl >/dev/null 2>&1 \
        || die "curl est requis pour relancer le script depuis la branche ${DOTFILES_BRANCH}."

    local url script_content
    url="${SCRIPT_RAW_URL_BASE}/${DOTFILES_BRANCH}/${SCRIPT_RAW_PATH}"
    info "Version de la branche ${DOTFILES_BRANCH} demandée : relance depuis ${url}..."
    script_content="$(curl -fsSL "$url")" \
        || die "Échec du téléchargement du script depuis la branche ${DOTFILES_BRANCH}."
    [ -n "$script_content" ] \
        || die "Script vide reçu depuis la branche ${DOTFILES_BRANCH} (branche inexistante ?)."

    exec env _INSTALL_PROF_RELAUNCHED=1 bash -c "$script_content" bash "$@"
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

ensure_prof_ssh_key() {
    [ -n "$PROF_SSH_PUBKEY" ] || return 0

    local home_dir prof_group ssh_dir authorized_keys
    # « || die » directement sur l'affectation : sous set -e, l'échec de
    # « getent » (utilisateur introuvable) interromprait sinon le script
    # avant que le test « [ -n "$home_dir" ] » n'ait la moindre chance de
    # s'exécuter, avec un exit code brut et aucun message.
    home_dir="$(getent passwd "$PROF_USER" | cut -d: -f6)" \
        || die "Impossible de déterminer le home de ${PROF_USER} (getent)."
    [ -n "$home_dir" ] || die "Home introuvable pour ${PROF_USER} (champ vide chez getent)."
    prof_group="$(id -gn "$PROF_USER")" || die "Impossible de déterminer le groupe de ${PROF_USER}."
    ssh_dir="${home_dir}/.ssh"
    authorized_keys="${ssh_dir}/authorized_keys"

    sudo install -d -m 700 -o "$PROF_USER" -g "$prof_group" "$ssh_dir" \
        || die "Échec de la création de ${ssh_dir}."

    if sudo grep -qxF "$PROF_SSH_PUBKEY" "$authorized_keys" 2>/dev/null; then
        info "Clé SSH déjà autorisée pour ${PROF_USER}."
    else
        info "Ajout de la clé SSH publique pour ${PROF_USER}..."
        echo "$PROF_SSH_PUBKEY" | sudo tee -a "$authorized_keys" >/dev/null \
            || die "Échec de l'écriture dans ${authorized_keys}."
    fi

    # Toujours réappliqués, y compris quand la clé était déjà présente : un
    # « authorized_keys » avec de mauvaises permissions fait échouer sshd
    # silencieusement (StrictModes), sans que rien ne le signale ici.
    sudo chown "${PROF_USER}:${prof_group}" "$authorized_keys" \
        || die "Échec du changement de propriétaire de ${authorized_keys}."
    sudo chmod 600 "$authorized_keys" \
        || die "Échec du changement des permissions de ${authorized_keys}."
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
    relaunch_from_branch_if_needed "$@"

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
        ensure_prof_ssh_key
        install_yadm
        run_dotfiles_as_prof
    fi

    echo
    success "Environnement ${PROF_USER} prêt."
    info "Ouvrir une session prof : ${BOLD}su - ${PROF_USER}${RESET}"
}

main "$@"
