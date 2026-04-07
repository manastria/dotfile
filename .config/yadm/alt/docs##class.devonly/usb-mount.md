# `usb-mount` / `usb-umount` — Gestion de clés USB chiffrées LUKS/f2fs

---

## Section utilisateur

### Description

`usb-mount.sh` et `usb-umount.sh` permettent de monter et démonter des clés USB chiffrées (LUKS) formatées en f2fs à partir d'un fichier de configuration centralisé.

Les deux scripts lisent la liste des périphériques dans `~/.config/usb-mount/devices.conf` et opèrent sur tout ce qui est branché (ou sur un seul UUID passé en argument).

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4 | Interpréteur | `bash --version` |
| `sudo` | Montage, démontage, cryptsetup | `sudo -v` |
| `cryptsetup` | Ouverture/fermeture LUKS | `cryptsetup --version` |
| `mount` / `umount` | Montage f2fs | `mount --version` |

---

### Fichier de configuration

Emplacement par défaut : `~/.config/usb-mount/devices.conf`

Remplaçable via la variable d'environnement `USB_MOUNT_CONF`.

**Format** : un périphérique par ligne, trois champs séparés par des espaces.

```
# UUID                                  MAPPER_NAME   MOUNT_POINT
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx    cle-backup    /mnt/backup
yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy    cle-data      /mnt/data
```

- Les lignes commençant par `#` et les lignes vides sont ignorées.
- `UUID` : identifiant du périphérique chiffré (`blkid` pour le trouver).
- `MAPPER_NAME` : nom libre utilisé par `cryptsetup open` (apparaîtra sous `/dev/mapper/`).
- `MOUNT_POINT` : répertoire de montage (créé automatiquement si absent).

---

### Syntaxe

```bash
# Monter toutes les clés branchées
usb-mount.sh

# Monter une seule clé par UUID
usb-mount.sh <UUID>

# Démonter toutes les clés montées
usb-umount.sh

# Démonter une seule clé par UUID
usb-umount.sh <UUID>
```

---

### Exemples d'utilisation

```bash
# Monter toutes les clés définies dans la config
~/.local/bin/usb-mount.sh

# Monter uniquement la clé d'UUID donné
~/.local/bin/usb-mount.sh xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Démonter proprement toutes les clés avant d'éjecter
~/.local/bin/usb-umount.sh
```

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Opération réussie (y compris si tout était déjà monté/démonté) |
| 1 | Fichier de configuration introuvable |

---

### Options de montage f2fs

Le montage utilise les options suivantes (définies dans `MOUNT_OPTS`) :

| Option | Effet |
| ------ | ----- |
| `compress_algorithm=zstd` | Compression transparente zstd |
| `compress_log_size=3` | Unité de compression de 8 blocs (4 Ko × 8) |
| `compress_extension=*` | Compression active sur tous les fichiers |
| `nocompress_extension=jpg,png,mp4,zip,gz,zst` | Exclusions : formats déjà compressés |
| `nodiscard` | Désactive le TRIM (préserve la durée de vie NAND) |
| `lazytime` | Mise à jour des horodatages différée (réduit les écritures) |

---

## Section développeur

### Architecture interne

**`usb-mount.sh`**

1. Valide la présence du fichier de configuration (`die` si absent).
2. Lance `sudo -v` pour mettre en cache les credentials (Tier 2).
3. Parse `devices.conf` ligne par ligne.
4. Pour chaque entrée, appelle `mount_entry()` qui :
   - Ignore la clé si `/dev/disk/by-uuid/<UUID>` est absent (clé non branchée).
   - Ignore l'entrée si le point de montage est déjà actif (`mountpoint -q`).
   - Ouvre le volume LUKS via `sudo cryptsetup open` si `/dev/mapper/<mapper>` absent.
   - Crée le répertoire de montage via `sudo mkdir -p` si nécessaire.
   - Monte le volume f2fs avec `sudo mount -t f2fs -o "$MOUNT_OPTS"`.
   - Corrige la propriété avec `sudo chown "${USER}:${USER}"`.

**`usb-umount.sh`**

1. Valide la présence du fichier de configuration (`die` si absent).
2. Lance `sudo -v` (Tier 2).
3. Parse `devices.conf` ligne par ligne.
4. Pour chaque entrée, appelle `umount_entry()` qui :
   - Démonte le point de montage via `sudo umount` s'il est actif.
   - Ferme le volume LUKS via `sudo cryptsetup close` si `/dev/mapper/<mapper>` existe.
   - Incrémente `count_umounted` si au moins une des deux opérations a eu lieu, sinon `count_skipped`.

### Tier sudo appliqué

**Tier 2** (mix opérations utilisateur + système) pour les deux scripts :

- La lecture de la config et la vérification de présence des périphériques sont des opérations utilisateur.
- `cryptsetup`, `mount`/`umount`, `mkdir -p` sur `/mnt/` et `chown` nécessitent root.
- `sudo -v` en début de script évite les demandes de mot de passe répétées en cours d'exécution.

### Points d'extension

- **Systèmes de fichiers alternatifs** : remplacer `-t f2fs` et adapter `MOUNT_OPTS` pour ext4 ou btrfs.
- **Script de statut** : `grep -q "^$mapper " /proc/mounts` suffit pour tester l'état sans sudo.
- **Intégration udev** : appeler `usb-mount.sh <UUID>` depuis une règle udev `ACTION=="add"` pour un montage automatique à la connexion.
