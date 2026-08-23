#!/bin/bash
#
# Fichier : set-default-shell.sh
# Description : Gestionnaire de shell par défaut (bash ↔ zsh)
#               Fonctionne avec les comptes locaux (chsh) et les comptes
#               centralisés SSSD/LDAP (fichier sentinel ~/.zsh-force).
#
# Usage : ./set-default-shell.sh
#

set -e

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

if [ "$(id -u)" -eq 0 ]; then
    die "Ce script ne doit pas être lancé en root. Relancez sans sudo."
fi

ZSH_FORCE="${HOME}/.zsh-force"
ZSH_PROFILE_FILE="${HOME}/.zsh-profile"
ZSH_LIGHT_LEGACY="${HOME}/.zsh-light"

# Chemin canonique d'un shell. Sur une distribution à /usr fusionné, /bin/zsh
# et /usr/bin/zsh désignent le même binaire, mais getent renvoie l'un ou
# l'autre selon la façon dont le compte a été créé : comparer les chaînes
# brutes ferait croire qu'un changement de shell est nécessaire alors qu'il
# est déjà en place.
_canonical() {
    local path="$1"
    if [ -n "${path}" ] && command -v realpath >/dev/null 2>&1; then
        realpath -m -- "${path}" 2>/dev/null || echo "${path}"
    else
        echo "${path}"
    fi
}

# Vrai si les deux chemins désignent le même shell
_same_shell() {
    [ "$(_canonical "$1")" = "$(_canonical "$2")" ]
}

# Emplacement réel d'un shell, au lieu d'un chemin codé en dur
_shell_bin() {
    command -v "$1" 2>/dev/null
}

# chsh refuse tout shell absent de /etc/shells : autant le signaler avant
# d'essayer plutôt que de laisser l'utilisateur devant un échec obscur.
_is_login_shell() {
    local candidate="$1" line
    [ -r /etc/shells ] || return 0
    while IFS= read -r line; do
        case "${line}" in
            ''|\#*) continue ;;
        esac
        if _same_shell "${line}" "${candidate}"; then
            return 0
        fi
    done < /etc/shells
    return 1
}

# Récupère le shell par défaut de l'utilisateur courant.
# Le résultat est testé à chaque étape : dans un pipeline, le code de retour
# est celui de « cut », qui vaut 0 même quand getent n'a rien trouvé — un
# enchaînement « getent | cut || grep | cut || echo » ne se replierait donc
# jamais et renverrait une chaîne vide.
_current_shell() {
    local shell
    shell="$(getent passwd "${USER}" 2>/dev/null | cut -d: -f7)"
    if [ -z "${shell}" ]; then
        shell="$(grep "^${USER}:" /etc/passwd 2>/dev/null | cut -d: -f7)"
    fi
    [ -n "${shell}" ] || shell="(inconnu)"
    echo "${shell}"
}

# Vrai si le compte est géré par SSSD/LDAP (absent de /etc/passwd)
_is_sssd_user() {
    ! grep -q "^${USER}:" /etc/passwd 2>/dev/null
}

# Profil zsh actif : contenu de ~/.zsh-profile, sinon rétrocompatibilité
# avec l'ancien sentinel ~/.zsh-light, sinon "base" par défaut.
_current_zsh_profile() {
    if [ -f "${ZSH_PROFILE_FILE}" ]; then
        cat "${ZSH_PROFILE_FILE}"
    elif [ -f "${ZSH_LIGHT_LEGACY}" ]; then
        echo "light"
    else
        echo "base"
    fi
}

# Tente de changer le shell via chsh ; retourne 0 si réussi
_try_chsh() {
    local target="$1"
    if ! command -v chsh >/dev/null 2>&1; then
        return 1
    fi
    info "Changement via chsh — votre mot de passe vous sera demandé."
    if chsh -s "${target}"; then
        return 0
    else
        return 1
    fi
}

# ─── Actions ─────────────────────────────────────────────────────────────────

_switch_to_zsh() {
    local zsh_bin
    zsh_bin="$(_shell_bin zsh)" \
        || die "zsh n'est pas installé (introuvable dans le PATH). Installez-le d'abord."

    if ! _is_login_shell "${zsh_bin}"; then
        warn "${BOLD}${zsh_bin}${RESET}${YELLOW} n'est pas listé dans /etc/shells :"
        warn "chsh le refusera. Le fichier sentinel prendra le relais."
    fi

    if _is_sssd_user; then
        warn "Compte centralisé (SSSD/LDAP) détecté : chsh ne peut pas modifier ce compte."
        warn "Le fichier sentinel ${BOLD}~/.zsh-force${RESET}${YELLOW} sera utilisé à la place."
        touch "${ZSH_FORCE}"
        success "Fichier ~/.zsh-force créé : bash lancera zsh automatiquement."
    else
        if _try_chsh "${zsh_bin}"; then
            success "Shell par défaut changé en zsh (via ${zsh_bin})."
        else
            warn "chsh a échoué (compte SSSD ou droits insuffisants)."
            info "Utilisation du fichier sentinel ~/.zsh-force à la place."
            touch "${ZSH_FORCE}"
            success "Fichier ~/.zsh-force créé : bash lancera zsh automatiquement."
        fi
    fi
}

_switch_to_bash() {
    local changed=false

    if [ -f "${ZSH_FORCE}" ]; then
        rm -f "${ZSH_FORCE}"
        success "Fichier ~/.zsh-force supprimé."
        changed=true
    fi

    local cur bash_bin
    cur="$(_current_shell)"
    bash_bin="$(_shell_bin bash)" || bash_bin="/bin/bash"

    # Comparaison canonique : /bin/bash et /usr/bin/bash sont le même shell,
    # inutile de demander un mot de passe pour un chsh sans effet.
    if ! _same_shell "${cur}" "${bash_bin}" && ! _is_sssd_user; then
        if _try_chsh "${bash_bin}"; then
            success "Shell par défaut changé en bash (via ${bash_bin})."
            changed=true
        else
            warn "chsh a échoué. Le fichier sentinel a été supprimé : bash sera actif au prochain démarrage."
        fi
    fi

    if [ "${changed}" = false ]; then
        info "bash est déjà votre shell par défaut, rien à faire."
    fi
}

_configure_zsh_profile() {
    echo ""
    echo -e "  ${BOLD}Profil zsh${RESET}"
    echo "  ─────────────────────────────────────────────"
    echo "  • light     : prompt Pure + plugins essentiels"
    echo "                (recommandé sans oh-my-zsh)"
    echo "  • base      : zsh minimal sans plugins"
    echo "  • omz-ascii : oh-my-zsh (plugins complets) avec un"
    echo "                prompt ASCII/ANSI sans icônes Unicode"
    echo "                (recommandé en console Linux, Ctrl+Alt+F1)"
    echo "  ─────────────────────────────────────────────"
    echo -e "  Profil actif : ${BOLD}$(_current_zsh_profile)${RESET}"
    echo ""
    echo "  1) Activer le profil light"
    echo "  2) Activer le profil base"
    echo "  3) Activer le profil omz-ascii"
    echo "  r) Retour"
    echo ""
    read -rp "  Votre choix : " profile_choice
    local profile_name=""
    case "${profile_choice}" in
        1) profile_name="light" ;;
        2) profile_name="base" ;;
        3) profile_name="omz-ascii" ;;
        r|R) return ;;
        *) warn "Choix invalide, aucune modification." ; return ;;
    esac
    rm -f "${ZSH_LIGHT_LEGACY}"
    echo -n "${profile_name}" > "${ZSH_PROFILE_FILE}"
    success "Profil ${BOLD}${profile_name}${RESET}${GREEN} activé (fichier ~/.zsh-profile mis à jour)."
}

# ─── Menu principal ───────────────────────────────────────────────────────────

_print_status() {
    local cur sentinel_state profile_state
    cur="$(_current_shell)"

    if [ -f "${ZSH_FORCE}" ]; then
        sentinel_state="${CYAN}actif${RESET} (bash → zsh au démarrage)"
    else
        sentinel_state="inactif"
    fi

    profile_state="${CYAN}$(_current_zsh_profile)${RESET}"

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}    Gestionnaire de shell par défaut        ${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    echo ""
    echo -e "  Utilisateur       : ${BOLD}${USER}${RESET}"
    echo -e "  Shell par défaut  : ${BOLD}${cur}${RESET}"
    echo -e "  Sentinel ~/.zsh-force : ${sentinel_state}"
    echo -e "  Profil zsh        : ${profile_state}"
    echo ""
    echo "  1) Passer à zsh comme shell par défaut"
    echo "  2) Passer à bash comme shell par défaut"
    echo "  3) Configurer le profil zsh (light / base / omz-ascii)"
    echo "  q) Quitter"
    echo ""
}

_print_status
read -rp "  Votre choix : " main_choice

case "${main_choice}" in
    1)
        _switch_to_zsh
        echo ""
        read -rp "  Configurer aussi le profil zsh ? [o/N] " want_profile
        if [[ "${want_profile}" =~ ^[oO]$ ]]; then
            _configure_zsh_profile
        fi
        ;;
    2)
        _switch_to_bash
        ;;
    3)
        _configure_zsh_profile
        ;;
    q|Q)
        info "Aucune modification effectuée."
        exit 0
        ;;
    *)
        warn "Choix invalide."
        exit 1
        ;;
esac

echo ""
info "Fermez et rouvrez votre terminal pour appliquer les changements."
echo ""
