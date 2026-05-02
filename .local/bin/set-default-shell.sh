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
ZSH_LIGHT="${HOME}/.zsh-light"

# Récupère le shell par défaut de l'utilisateur courant
_current_shell() {
    getent passwd "${USER}" 2>/dev/null | cut -d: -f7 \
        || grep "^${USER}:" /etc/passwd 2>/dev/null | cut -d: -f7 \
        || echo "(inconnu)"
}

# Vrai si le compte est géré par SSSD/LDAP (absent de /etc/passwd)
_is_sssd_user() {
    ! grep -q "^${USER}:" /etc/passwd 2>/dev/null
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
    if [ ! -x /bin/zsh ]; then
        die "zsh n'est pas installé (/bin/zsh introuvable). Installez-le d'abord."
    fi

    local used_chsh=false

    if _is_sssd_user; then
        warn "Compte centralisé (SSSD/LDAP) détecté : chsh ne peut pas modifier ce compte."
        warn "Le fichier sentinel ${BOLD}~/.zsh-force${RESET}${YELLOW} sera utilisé à la place."
        touch "${ZSH_FORCE}"
        success "Fichier ~/.zsh-force créé : bash lancera zsh automatiquement."
    else
        if _try_chsh /bin/zsh; then
            success "Shell par défaut changé en zsh (via chsh)."
            used_chsh=true
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

    local cur
    cur="$(_current_shell)"
    if [ "${cur}" != "/bin/bash" ] && ! _is_sssd_user; then
        if _try_chsh /bin/bash; then
            success "Shell par défaut changé en bash (via chsh)."
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
    echo "  • light  : prompt Pure + plugins essentiels"
    echo "             (recommandé sans oh-my-zsh)"
    echo "  • base   : zsh minimal sans plugins"
    echo "  ─────────────────────────────────────────────"
    local current_profile
    if [ -f "${ZSH_LIGHT}" ]; then
        current_profile="${BOLD}light${RESET}"
    else
        current_profile="${BOLD}base${RESET}"
    fi
    echo -e "  Profil actif : ${current_profile}"
    echo ""
    echo "  1) Activer le profil light  (crée ~/.zsh-light)"
    echo "  2) Activer le profil base   (supprime ~/.zsh-light)"
    echo "  r) Retour"
    echo ""
    read -rp "  Votre choix : " profile_choice
    case "${profile_choice}" in
        1)
            touch "${ZSH_LIGHT}"
            success "Profil light activé (fichier ~/.zsh-light créé)."
            ;;
        2)
            rm -f "${ZSH_LIGHT}"
            success "Profil base activé (fichier ~/.zsh-light supprimé)."
            ;;
        r|R) return ;;
        *) warn "Choix invalide, aucune modification." ;;
    esac
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

    if [ -f "${ZSH_LIGHT}" ]; then
        profile_state="${CYAN}light${RESET}"
    else
        profile_state="base"
    fi

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
    echo "  3) Configurer le profil zsh (light / base)"
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
