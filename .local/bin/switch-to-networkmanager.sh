#!/usr/bin/env bash
# switch-to-networkmanager.sh
# Objectif : forcer NetworkManager comme gestionnaire réseau (XUbuntu)
# Auteur : J.-Ph. Demory
# Usage : sudo ./switch-to-networkmanager.sh
# Prérequis :
# - Distribution basée sur netplan (Ubuntu/XUbuntu) avec NetworkManager installé.
# - Exécution en root (le script relance via sudo).
# Risques :
# - Coupure réseau temporaire (surtout en SSH) pendant l'application netplan.
# - Conflits si des services réseau concurrents restent actifs.

[[ -n "${BASH_VERSION:-}" ]] || { echo "Ce script doit être exécuté avec bash." >&2; exit 1; }

# Relancer le script avec sudo si besoin
if [ "$EUID" -ne 0 ]; then
    exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

set -euo pipefail

ts="$(date +%Y%m%d-%H%M%S)"
backup_tar="/root/netplan-backup-$ts.tar.gz"

# 1) Sauvegarde complète du répertoire netplan avant toute modification.
echo "[1/5] Sauvegarde de /etc/netplan -> $backup_tar"
tar -czf "$backup_tar" -C /etc netplan

# 2) Crée un fichier minimal qui force NetworkManager
#    Ce fichier devient la source de vérité pour netplan.
echo "[2/5] Écriture /etc/netplan/01-network-manager-all.yaml"
cat > /etc/netplan/01-network-manager-all.yaml <<'YAML'
network:
  version: 2
  renderer: NetworkManager
YAML

# 3) Optionnel : on ne supprime pas tout à l'aveugle.
#    On renomme les anciens fichiers pour pouvoir revenir en arrière.
#    Le suffixe horodaté évite d'écraser des sauvegardes précédentes.
echo "[3/5] Mise de côté des anciens YAML (sans suppression définitive)"
shopt -s nullglob
for f in /etc/netplan/*.yaml; do
  [[ "$f" == "/etc/netplan/01-network-manager-all.yaml" ]] && continue
  mv -v "$f" "${f}.disabled-$ts"
done
shopt -u nullglob

# 4) Évite la double gestion : désactive networkd si présent
#    L'échec est ignoré si le service n'existe pas.
echo "[4/5] Désactivation de systemd-networkd (si présent)"
systemctl disable --now systemd-networkd.service systemd-networkd.socket 2>/dev/null || true

# 5) Applique prudemment
#    netplan try permet un rollback automatique en cas de perte réseau.
echo "[5/5] Application netplan"
if netplan help 2>/dev/null | grep -q '\btry\b'; then
  # rollback automatique si perte réseau (utile si tu es en SSH)
  netplan try
else
  netplan apply
fi

systemctl restart NetworkManager || true

echo "OK."
echo "Backup: $backup_tar"
echo "Anciens fichiers: /etc/netplan/*.yaml.disabled-$ts"

# Restauration rapide (manuel) :
# - Restaurer une sauvegarde complète :
#   tar -xzf /root/netplan-backup-YYYYmmdd-HHMMSS.tar.gz -C /
# - Réactiver un ancien fichier :
#   mv /etc/netplan/*.yaml.disabled-YYYYmmdd-HHMMSS /etc/netplan/
# - Réappliquer :
#   netplan apply
