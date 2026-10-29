#!/usr/bin/env bash
# NAME
#     switch-to-networkmanager.sh — laisse NetworkManager gérer le réseau
#     (Ubuntu / Xubuntu)
#
# SYNOPSIS
#     switch-to-networkmanager.sh [-h]
#
# DESCRIPTION
#     Réduit la configuration netplan à « renderer: NetworkManager » pour que
#     les réglages faits dans nmtui / nmcli / l'applet réseau soient
#     conservés au redémarrage.
#
#     Sur Ubuntu, netplan fusionne tous les fichiers /etc/netplan/*.yaml par
#     identifiant d'interface. Un « dhcp4: true » écrit par l'installeur
#     (00-installer-config.yaml) survit donc à un réglage manuel, car
#     NetworkManager n'écrit pas « dhcp4: false » (valeur par défaut) dans
#     son fichier 90-NM-<uuid>.yaml : la connexion repasse en DHCP.
#
#     Le script :
#       1. sauvegarde /etc/netplan dans /root/netplan-backup-<date>.tar.gz ;
#       2. écrit /etc/netplan/01-network-manager-all.yaml (renderer seul) ;
#       3. renomme les autres *.yaml en *.yaml.disabled-<date> (rien n'est
#          supprimé) ;
#       4. applique la configuration avec « netplan apply ».
#
#     Relancé alors que la configuration est déjà réduite, il ne fait rien.
#     Les réglages statiques des anciens YAML ne sont PAS reportés dans
#     NetworkManager : à ressaisir ensuite dans nmtui.
#
# OPTIONS
#     -h, --help   Affiche cette aide.
#
# EXAMPLES
#     # Basculer, puis ressaisir l'IP statique dans nmtui
#     switch-to-networkmanager.sh
#     nmtui
#
#     # Revenir en arrière
#     sudo tar -xzf /root/netplan-backup-20261029-101500.tar.gz -C /etc
#     sudo netplan apply
#
# EXIT CODES
#     0   Configuration appliquée, ou déjà conforme.
#     1   Erreur d'exécution (netplan ou nmcli absent, échec de netplan).
#     2   Erreur d'usage : option inconnue.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly NETPLAN_DIR="/etc/netplan"
readonly NM_YAML="${NETPLAN_DIR}/01-network-manager-all.yaml"
TS="$(date +%Y%m%d-%H%M%S)"
readonly TS
readonly BACKUP_TAR="/root/netplan-backup-${TS}.tar.gz"

# Anciens fichiers YAML à mettre de côté (rempli par find_old_yaml)
OLD_YAML=()

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
usage() {
    # Réimprime l'en-tête manpage : lignes « # » jusqu'au premier code
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            *) error "Option inconnue : $1"; exit 2 ;;
        esac
    done
}

# Tier 1 : tout le script travaille sur /etc. Pas de -E : sudo repart d'un
# environnement sain, et readlink -f évite le secure_path (~/.local/bin).
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$(readlink -f "$0")" "$@"
    fi
}

check_prerequisites() {
    command -v netplan >/dev/null || die "netplan introuvable (paquet netplan.io)."
    command -v nmcli   >/dev/null || die "NetworkManager introuvable (apt install network-manager)."
    [[ -d "$NETPLAN_DIR" ]]       || die "${NETPLAN_DIR} introuvable."
}

# -----------------------------------------------------------------------------
# Configuration netplan
# -----------------------------------------------------------------------------
nm_yaml_content() {
    printf '%s\n' \
        'network:' \
        '  version: 2' \
        '  renderer: NetworkManager'
}

find_old_yaml() {
    local f
    OLD_YAML=()
    # Pas de nullglob : sans correspondance, le motif reste littéral, d'où -e
    for f in "$NETPLAN_DIR"/*.yaml; do
        if [[ -e "$f" && "$f" != "$NM_YAML" ]]; then
            OLD_YAML+=("$f")
        fi
    done
}

already_configured() {
    [[ ${#OLD_YAML[@]} -eq 0 && -f "$NM_YAML" ]] \
        && nm_yaml_content | cmp -s - "$NM_YAML"
}

backup_netplan() {
    info "Sauvegarde de ${NETPLAN_DIR} -> ${BACKUP_TAR}"
    tar -czf "$BACKUP_TAR" -C "$(dirname "$NETPLAN_DIR")" "$(basename "$NETPLAN_DIR")"
}

write_nm_yaml() {
    info "Écriture de ${NM_YAML}"
    nm_yaml_content > "$NM_YAML"
    # netplan avertit si le fichier est lisible par tous (il peut contenir
    # des mots de passe Wi-Fi dans d'autres YAML)
    chmod 600 "$NM_YAML"
}

disable_old_yaml() {
    local f
    for f in "${OLD_YAML[@]}"; do
        mv "$f" "${f}.disabled-${TS}"
        info "Mis de côté : $(basename "$f") -> $(basename "$f").disabled-${TS}"
    done
}

apply_netplan() {
    info "Application de la configuration netplan"
    netplan apply
    systemctl is-active --quiet NetworkManager \
        || die "NetworkManager n'est pas actif après netplan apply."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    ensure_root "$@"
    echo -e "\n${BOLD}=== Bascule vers NetworkManager ===${RESET}\n"
    check_prerequisites

    find_old_yaml
    if already_configured; then
        success "Déjà conforme : seul ${NM_YAML} est présent."
        exit 0
    fi

    backup_netplan
    write_nm_yaml
    disable_old_yaml
    apply_netplan

    success "NetworkManager gère maintenant le réseau."
    info "Sauvegarde : ${BACKUP_TAR}"
    if [[ ${#OLD_YAML[@]} -gt 0 ]]; then
        warn "Les réglages des anciens YAML (IP statique, etc.) ne sont pas repris."
    fi
    info "Configurez la connexion avec : nmtui"
}

main "$@"
