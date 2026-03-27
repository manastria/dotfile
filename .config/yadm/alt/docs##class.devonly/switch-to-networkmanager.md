# `switch-to-networkmanager` — Basculer vers NetworkManager sur Ubuntu/XUbuntu

---

## Section utilisateur

### Description

`switch-to-networkmanager.sh` configure NetworkManager comme unique gestionnaire réseau sur un système Ubuntu/XUbuntu utilisant netplan. Il remplace la configuration netplan existante par un fichier minimal pointant vers NetworkManager, désactive `systemd-networkd`, et applique la configuration.

Le script commence par réinstaller netplan pour corriger l'erreur `ModuleNotFoundError: No module named 'netplan_cli.cli.core'` qui apparaît sur certaines machines après une mise à jour partielle. Il sauvegarde ensuite l'état initial avant toute modification, ce qui permet une restauration complète si nécessaire.

---

### Prérequis

| Élément | Détail |
| ------- | ------ |
| Distribution | Ubuntu ou XUbuntu (netplan requis) |
| NetworkManager | Doit être installé (`apt install network-manager`) |
| Droits | Root — le script se relance automatiquement via `sudo` si nécessaire |
| Shell | `bash` obligatoire |

---

### Syntaxe

```bash
sudo bash switch-to-networkmanager.sh
# ou simplement (le script se relance seul avec sudo) :
bash switch-to-networkmanager.sh
```

---

### Exemples d'utilisation

```bash
# Lancer depuis le répertoire courant
bash ~/.local/bin/switch-to-networkmanager.sh

# Vérifier le résultat
networkctl status          # doit indiquer "unmanaged" ou absent
nmcli general status       # doit afficher "connected"
```

---

### Risques

| Risque | Contexte |
| ------ | -------- |
| Coupure réseau temporaire | Inévitable pendant `netplan apply` — particulièrement critique en SSH |
| Perte de configuration réseau | Si les anciens fichiers YAML contenaient des adresses statiques non reproduites dans NetworkManager |

Si le script est lancé en SSH, `netplan try` est préféré à `netplan apply` : il effectue un rollback automatique après 120 secondes si la connexion n'est pas confirmée.

---

### Restauration d'urgence

**Restaurer la configuration netplan complète :**

```bash
tar -xzf /root/netplan-backup-YYYYmmdd-HHMMSS.tar.gz -C /
netplan apply
```

**Réactiver un seul fichier YAML désactivé :**

```bash
mv /etc/netplan/fichier.yaml.disabled-YYYYmmdd-HHMMSS /etc/netplan/fichier.yaml
netplan apply
```

Les archives sont dans `/root/` avec un nom horodaté (`netplan-backup-YYYYmmdd-HHMMSS.tar.gz`).

---

### Variables d'environnement

Aucune.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Configuration appliquée avec succès |
| 1 | Shell non-bash, ou erreur lors de l'exécution (`set -euo pipefail`) |

---

## Section développeur

### Architecture interne

Le script s'exécute en 5 étapes séquentielles avec `set -euo pipefail` (arrêt immédiat sur erreur) :

| Étape | Action |
| ----- | ------ |
| 1 | Réinstallation de `netplan.io` et `python3-netplan` — corrige `ModuleNotFoundError: No module named 'netplan_cli.cli.core'` |
| 2 | Sauvegarde de `/etc/netplan/` dans une archive `.tar.gz` horodatée dans `/root/` |
| 3 | Écriture de `/etc/netplan/01-network-manager-all.yaml` (fichier minimal `renderer: NetworkManager`) |
| 4 | Renommage des anciens fichiers `.yaml` en `.yaml.disabled-<timestamp>` (pas de suppression) |
| 5 | Désactivation de `systemd-networkd.service` et `systemd-networkd.socket` (échec ignoré si absent) |
| 6 | Application via `netplan try` (si disponible) ou `netplan apply`, puis `systemctl restart NetworkManager` |

### Élévation de privilèges

Le script détecte l'absence de droits root et se relance lui-même :

```bash
if [ "$EUID" -ne 0 ]; then
    exec sudo -E bash "$(readlink -f "$0")" "$@"
fi
```

`-E` préserve l'environnement de l'utilisateur courant. `readlink -f` résout les liens symboliques.

Le check bash (`$BASH_VERSION`) est placé **avant** le `set -euo pipefail` et avant la relance sudo, pour garantir un message d'erreur lisible si le script est appelé avec `sh`.

### Stratégie de sauvegarde

- **Archive complète** : `tar -czf /root/netplan-backup-$ts.tar.gz -C /etc netplan` — chemin relatif à `/etc`, ce qui permet un `tar -xzf … -C /` direct pour restaurer.
- **Renommage horodaté** : les anciens YAML sont conservés sur place avec le suffixe `.disabled-$ts`, évitant l'écrasement de sauvegardes précédentes.

### Choix `netplan try` vs `netplan apply`

```bash
if netplan help 2>/dev/null | grep -q '\btry\b'; then
    netplan try
else
    netplan apply
fi
```

`netplan try` met en place la configuration et attend une confirmation (`Enter`) dans un délai de 120 secondes. Sans confirmation, il effectue un rollback automatique — comportement de sécurité important lors d'une exécution en SSH.

### Dépendances

| Commande | Paquet | Rôle |
| -------- | ------ | ---- |
| `netplan` | `netplan.io` | Application de la configuration réseau |
| `systemctl` | `systemd` | Désactivation de `systemd-networkd` |
| `NetworkManager` | `network-manager` | Gestionnaire réseau cible |
| `tar` | `tar` | Sauvegarde et restauration |

### Points d'extension

- Pour automatiser la confirmation de `netplan try` (cas CI/CD) : remplacer par `netplan apply` en passant une variable d'environnement.
- Pour gérer des interfaces spécifiques (adresses statiques, VLAN), compléter `/etc/netplan/01-network-manager-all.yaml` avant le `netplan apply`.
