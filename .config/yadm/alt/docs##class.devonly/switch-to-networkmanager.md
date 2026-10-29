# `switch-to-networkmanager.sh` — Laisser NetworkManager gérer le réseau (Ubuntu/Xubuntu)

> Script : [`.local/bin/switch-to-networkmanager.sh`](../.local/bin/switch-to-networkmanager.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`switch-to-networkmanager.sh` réduit la configuration netplan d'un Ubuntu/Xubuntu à `renderer: NetworkManager`, afin que les réglages faits dans `nmtui`, `nmcli` ou l'applet réseau **survivent** au redémarrage. Il sert quand une IPv4 passée en manuel « repasse toute seule en DHCP » : la cause est un `dhcp4: true` laissé par l'installeur dans `/etc/netplan/00-installer-config.yaml`, que netplan fusionne avec le réglage de NetworkManager. Le script ne configure **aucune** adresse : il remet NetworkManager aux commandes, et l'IP statique se ressaisit ensuite dans `nmtui`. Il sauvegarde `/etc/netplan` dans `/root/netplan-backup-<date>.tar.gz`, met les autres `*.yaml` de côté en `*.yaml.disabled-<date>` (rien n'est supprimé), puis lance `netplan apply`. Il s'utilise sans argument (il se relance seul avec `sudo`) et peut être relancé sans risque : s'il n'y a rien à faire, il le dit et s'arrête.

---

## Section utilisateur

### Description

Sur Ubuntu, netplan lit **tous** les `/etc/netplan/*.yaml` dans l'ordre alphabétique et les **fusionne par identifiant d'interface**. Un poste installé avec subiquity contient typiquement :

| Fichier | Origine | Contenu |
| ------- | ------- | ------- |
| `00-installer-config.yaml` | installeur | `enp0s3` avec `dhcp4: true` |
| `01-network-manager-all.yaml` | paquet bureau | `renderer: NetworkManager` seul |
| `90-NM-<uuid>.yaml` | NetworkManager | écrit quand on modifie dans `nmtui` un profil `netplan-*` |

Quand on passe l'IPv4 en manuel dans `nmtui`, NetworkManager écrit la nouvelle adresse dans `90-NM-<uuid>.yaml` mais **n'y ajoute pas `dhcp4: false`**, car c'est la valeur par défaut. La fusion conserve donc le `dhcp4: true` de `00-installer-config.yaml` : on obtient DHCP **plus** l'adresse saisie, et la connexion semble être revenue en automatique.

Le script supprime la cause : il ne laisse que `01-network-manager-all.yaml`. Plus aucun profil `netplan-<interface>` n'est généré dans `/run/NetworkManager/`, et les profils créés ensuite dans `nmtui` sont de vrais profils NetworkManager, stockés dans `/etc/NetworkManager/system-connections/`.

Il diffère d'une édition manuelle du YAML : ici on abandonne netplan comme source de la configuration des interfaces, on ne la corrige pas.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `netplan` (paquet `netplan.io`) | Application de la configuration | `command -v netplan` |
| `nmcli` (paquet `network-manager`) | Présence de NetworkManager | `command -v nmcli` |
| `sudo` | Élévation de privilèges (le script se relance seul) | `sudo -v` |

---

### Syntaxe

```
switch-to-networkmanager.sh [-h]
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage du script |

Aucun autre paramètre : le script fait toujours la même chose.

---

### Exemples d'utilisation

```bash
# Basculer, puis ressaisir l'IP statique
switch-to-networkmanager.sh
nmtui

# Vérifier le résultat : le profil doit venir de /etc/NetworkManager, pas de /run
nmcli -f NAME,FILENAME connection show
ls /etc/netplan/

# Restaurer l'état d'avant
sudo tar -xzf /root/netplan-backup-20261029-101500.tar.gz -C /etc
sudo netplan apply

# Réactiver un seul fichier mis de côté
sudo mv /etc/netplan/00-installer-config.yaml.disabled-20261029-101500 \
        /etc/netplan/00-installer-config.yaml
sudo netplan apply
```

**Exemple de sortie** (premier passage, trois YAML présents) :

```
=== Bascule vers NetworkManager ===

[INFO]      Sauvegarde de /etc/netplan -> /root/netplan-backup-20261029-101500.tar.gz
[INFO]      Écriture de /etc/netplan/01-network-manager-all.yaml
[INFO]      Mis de côté : 00-installer-config.yaml -> 00-installer-config.yaml.disabled-20261029-101500
[INFO]      Mis de côté : 90-NM-1eef7e45-3b9d-3043-bee3-fc5925c90273.yaml -> 90-NM-1eef7e45-3b9d-3043-bee3-fc5925c90273.yaml.disabled-20261029-101500
[INFO]      Application de la configuration netplan
[INFO]      Redémarrage de NetworkManager
[OK]        NetworkManager gère maintenant le réseau.
[INFO]      Sauvegarde : /root/netplan-backup-20261029-101500.tar.gz
[ATTENTION] Les réglages des anciens YAML (IP statique, etc.) ne sont pas repris.
[INFO]      Configurez la connexion avec : nmtui
```

Second passage :

```
[OK]        Déjà conforme : seul /etc/netplan/01-network-manager-all.yaml est présent.
```

> Ces sorties reprennent les messages du script (testé dans un répertoire factice, avec de faux `netplan`/`nmcli`) ; elles n'ont pas été relevées sur une VM Xubuntu réelle.

---

### Risques

| Risque | Contexte |
| ------ | -------- |
| Perte de la configuration réseau | L'IP statique des anciens YAML n'est pas reprise : elle est à ressaisir dans `nmtui`. Le profil de remplacement est un « Wired connection » en DHCP. |
| Coupure réseau brève | Pendant `netplan apply`. En SSH, la session peut tomber : à lancer sur la console de préférence. |

Le script n'utilise **pas** `netplan try` : son rollback ne rétablit pas les fichiers déjà renommés, et il exige une confirmation interactive. La restauration se fait avec la sauvegarde (voir exemples).

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Configuration appliquée, ou déjà conforme |
| `1` | `netplan` ou `nmcli` absent, échec de `netplan apply`, NetworkManager inactif après son redémarrage |
| `2` | Option inconnue |

---

## Section développeur

### Architecture interne

```
main
├─ parse_args           →  -h / option inconnue (avant l'élévation : l'aide ne demande pas sudo)
├─ ensure_root          →  Tier 1 : exec sudo "$(readlink -f "$0")" "$@"
├─ check_prerequisites  →  netplan, nmcli, /etc/netplan
├─ find_old_yaml        →  remplit OLD_YAML (tous les *.yaml sauf 01-network-manager-all.yaml)
├─ already_configured   →  OLD_YAML vide et 01-… identique au contenu attendu → exit 0
├─ backup_netplan       →  tar.gz de /etc/netplan dans /root
├─ write_nm_yaml        →  01-network-manager-all.yaml, mode 600
├─ disable_old_yaml     →  mv f f.disabled-<date>
└─ apply_netplan        →  netplan apply, restart NetworkManager, puis contrôle qu'il est actif
```

---

### Détail des choix techniques

**Mettre de côté tous les autres YAML, `90-NM-*` compris**
Retirer seulement `00-installer-config.yaml` suffirait à corriger le symptôme, mais le profil resterait géré par netplan (`netplan-enp0s3` dans `/run`) et NetworkManager continuerait d'écrire des `90-NM-*.yaml`. Le but du script est une configuration où `nmtui` fait foi ; il ne laisse donc que le fichier `renderer`.

**Renommer plutôt que supprimer**
Netplan ignore tout fichier qui ne finit pas par `.yaml` : le suffixe `.disabled-<date>` désactive sans perdre, et l'horodatage évite d'écraser une mise de côté précédente. Doublé d'une archive complète, ce qui permet de revenir en arrière sans rien deviner.

**`netplan apply` et non `netplan try`**
`netplan try` annule la configuration appliquée au bout de 120 s sans confirmation, mais **pas** les renommages de fichiers : on se retrouverait avec un état incohérent. Il est aussi interactif. Le script a été simplifié en conséquence.

**`systemctl restart NetworkManager` après `netplan apply`**
Constaté sur Xubuntu 26.04 : une fois les YAML réduits au seul `renderer`, aucune interface n'est déclarée et `netplan apply` laisse NetworkManager arrêté (le contrôle final échouait avec « NetworkManager n'est pas actif »). Le redémarrage explicite est donc nécessaire ; c'est aussi lui qui fait disparaître le profil `netplan-*` de `/run`.

**Messages sur `systemd-networkd` pendant `netplan apply`**
`systemd-networkd is not running` et `Unit dbus-org.freedesktop.network1.service not found` sont sans conséquence : netplan tente de recharger networkd, absent ou arrêté sur un poste Xubuntu. Ils n'interrompent pas le script.

**Pas de réinstallation de `netplan.io`, pas de désactivation de `systemd-networkd`**
Les versions précédentes les faisaient. La réinstallation corrigeait une erreur `ModuleNotFoundError: netplan_cli.cli.core` propre à une mise à jour partielle (et échoue hors ligne sous `set -e`). Avec `renderer: NetworkManager`, netplan ne génère rien pour `systemd-networkd`, donc le désactiver ne change rien. Si l'erreur `netplan_cli` réapparaît : `sudo apt-get install --reinstall netplan.io python3-netplan`.

**`already_configured` compare le contenu, pas seulement l'existence**
Un `01-network-manager-all.yaml` modifié à la main (par exemple un `ethernets:` ajouté) n'est pas considéré comme conforme et sera réécrit après sauvegarde.

**`chmod 600` sur le YAML**
Les versions récentes de netplan avertissent quand un fichier de `/etc/netplan/` est lisible par tous.

**Pas de `nullglob` dans `find_old_yaml`**
Le motif `*.yaml` reste littéral quand rien ne correspond ; le test `-e` l'écarte. Cela évite de modifier une option globale du shell.

---

### Dépendances externes

```
netplan.io       →  netplan apply
network-manager  →  nmcli (présence), service NetworkManager
systemd          →  systemctl is-active
coreutils / tar  →  sauvegarde, mv, cmp, chmod
```

---

### Points d'extension

**Reprendre une IP statique dans un vrai profil NetworkManager** — à ajouter après `apply_netplan`, par exemple :

```bash
nmcli connection add type ethernet ifname enp0s3 con-name lan-static \
    ipv4.method manual ipv4.addresses 192.168.1.50/24 \
    ipv4.gateway 192.168.1.1 ipv4.dns 1.1.1.1
```

**Ne basculer que certains fichiers** — filtrer dans `find_old_yaml` (par exemple ne conserver que `00-installer-config.yaml` et `90-NM-*`) si d'autres YAML doivent subsister.

---

### Notes de maintenance

- Le script ne reprend **aucun** réglage des anciens YAML ; il ne les analyse pas. C'est un choix (cas visé : postes étudiants où `nmtui` fait foi), pas un oubli.
- Après la bascule, NetworkManager crée un profil en mémoire (« Wired connection 1 ») pour l'interface câblée ; il n'est enregistré dans `/etc/NetworkManager/system-connections/` qu'une fois modifié et validé dans `nmtui`.
- Si cloud-init régénère `50-cloud-init.yaml` au démarrage (images cloud), le fichier reviendra : désactiver cloud-init côté réseau (`/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` avec `network: {config: disabled}`).
- Les exemples de sortie de cette page n'ont pas été relevés sur une machine réelle (voir la note sous l'exemple).
