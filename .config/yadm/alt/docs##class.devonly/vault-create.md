# vault-create.sh

> Script : [`.local/bin/vault-create.sh`](../.local/bin/vault-create.sh)
> Scripts associés : [`vault-open.sh`](../.local/bin/vault-open.sh), [`vault-close.sh`](../.local/bin/vault-close.sh), [`vault-status.sh`](../.local/bin/vault-status.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`vault-create.sh` crée le conteneur chiffré LUKS utilisé pour stocker les profils de navigateurs (Vivaldi, Brave, Firefox) sur la machine prof : fichier conteneur, initialisation LUKS, formatage ext4, puis montage et mise en place des bind mounts. La passphrase du vault et le mot de passe sudo sont demandés une seule fois en tout début d'exécution, puis le script tourne sans interaction jusqu'à la fin. Il ne sert qu'à la création initiale : l'usage quotidien (ouvrir/fermer le vault déjà créé) relève de `vault-open.sh` et `vault-close.sh`. Il ne migre pas un profil navigateur existant — un profil déjà présent dans `~/.config/vivaldi` (ou équivalent) est seulement masqué tant que le vault est monté, pas déplacé dedans. Si un conteneur existe déjà à l'emplacement attendu, le script demande une confirmation explicite avant de l'écraser, cette opération étant irréversible.

---

## Section utilisateur

### Description

Crée le conteneur LUKS attendu par `vault-open.sh` / `vault-close.sh` — c'est l'étape unique de mise en place, à ne lancer qu'une fois par machine. Toutes les saisies (passphrase du vault, mot de passe sudo) sont demandées au tout début ; le script travaille ensuite sans aucune interaction jusqu'à obtenir un vault monté avec ses binds en place.

Ne pas confondre avec :

- [`vault-open.sh`](../.local/bin/vault-open.sh) / [`vault-close.sh`](../.local/bin/vault-close.sh) — ouverture/fermeture quotidienne d'un vault **déjà créé**.
- [`vault-status.sh`](../.local/bin/vault-status.sh) — état courant (LUKS ouvert ? monté ? binds actifs ?), sans rien modifier.

Le script ne migre aucun profil existant. Si un navigateur a déjà été utilisé sur la machine avant la création du vault, son profil reste sur place, à son emplacement d'origine (`~/.config/vivaldi`, etc.) — mais dès que le bind mount est actif, cet emplacement est masqué par le contenu (vide) du vault : le navigateur y voit un profil vierge et en recrée un, tant que le vault reste monté. Rien n'est supprimé, mais rien n'est fusionné non plus. Voir *Détail des choix techniques* pour le mécanisme, et *Notes de maintenance* pour la marche à suivre si une migration s'avère finalement nécessaire.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `sudo` | luksFormat, open, mkfs, mount | `sudo -v` |
| `cryptsetup` | Conteneur LUKS | `cryptsetup --version` (installé automatiquement si absent) |
| `fallocate` (util-linux) | Réservation du fichier conteneur | `fallocate --version` |
| `mkfs.ext4` (e2fsprogs) | Système de fichiers du volume | `mkfs.ext4 -V` |
| `vault-open.sh` | Montage + binds, appelé en fin de script | même répertoire que `vault-create.sh` |

### Syntaxe

```bash
vault-create.sh [--size TAILLE] [-h]
```

| Option | Défaut | Description |
| ------ | ------ | ----------- |
| `--size TAILLE` | `15G` | Taille du conteneur, syntaxe `fallocate` (ex : `15G`, `500M`) |
| `-h`, `--help` | — | Affiche l'en-tête du script |

### Exemples d'utilisation

```bash
# Création avec la taille par défaut (15G)
vault-create.sh

# Conteneur plus petit
vault-create.sh --size 5G
```

Déroulé typique :

```
=== Création du Vault ===

[INFO]      Passphrase du vault (différente du mot de passe de session).
Passphrase :
Confirmation :
[INFO]      Droits administrateur nécessaires pour la suite (cryptsetup, mkfs, mount).
[sudo] Mot de passe de jpd :
[INFO]      Création du conteneur (15G) : /home/jpd/vault.img
[INFO]      Initialisation LUKS...
[INFO]      Ouverture du volume...
[INFO]      Formatage en ext4...
[INFO]      Montage et mise en place des binds (délégué à vault-open.sh)...
Bind OK: /home/jpd/Vault/browser/vivaldi-prof -> /home/jpd/.config/vivaldi
Bind OK: /home/jpd/Vault/browser/brave-prof -> /home/jpd/.config/BraveSoftware/Brave-Browser
...
OK: Vault ouvert, monté sur /home/jpd/Vault, binds en place.

Terminé. Vault créé et monté sur /home/jpd/Vault, binds en place.

[INFO]      Vérification : vault-status.sh
```

À ce stade, les deux mots de passe (session et sudo) ont déjà été saisis : le reste — installation de `cryptsetup` si besoin, `fallocate`, `luksFormat`, `mkfs`, montage, binds — tourne sans intervention.

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Vault créé, monté, binds en place |
| 1 | Erreur d'exécution : conteneur déjà ouvert, confirmation d'écrasement refusée, échec cryptsetup/mkfs/mount |
| 2 | Erreur d'usage : option inconnue |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — `--size`, `--help`.
2. `check_not_open` — refuse de continuer si `/dev/mapper/vault_prof` existe déjà (vault actuellement ouvert).
3. `check_existing_container` — si `~/vault.img` existe, exige de taper `SUPPRIMER`, puis le supprime.
4. `read_passphrase` — double saisie masquée (`read -s`), comparée localement ; boucle tant que les deux ne correspondent pas ou que la saisie est vide.
5. `warmup_sudo` — `sudo -v` puis boucle de rafraîchissement en tâche de fond (Tier 2, cf. CLAUDE.md).
6. `ensure_cryptsetup` — installe `cryptsetup` via apt si absent.
7. `create_container` — `fallocate -l "$SIZE" "$IMG"`.
8. `init_luks` — `cryptsetup luksFormat --batch-mode --key-file=-`, passphrase envoyée sur stdin.
9. `open_luks` — `cryptsetup open --key-file=-`, même mécanisme.
10. `format_fs` — `mkfs.ext4 -q` sur `/dev/mapper/vault_prof`.
11. `mount_and_bind` — appelle `vault-open.sh` (résolu via `readlink -f "$0"`) pour le montage et les bind mounts.

Un `trap cleanup EXIT INT TERM`, posé avant toute autre étape, efface `VAULT_PASSPHRASE` et arrête la boucle de rafraîchissement sudo sur toute sortie du script, y compris une sortie précoce avant que ces deux éléments n'existent.

### Détail des choix techniques

**Passphrase par `--key-file=-`, pas par le prompt interactif de cryptsetup.** `cryptsetup luksFormat` sait demander et vérifier une passphrase lui-même, mais seulement de façon interactive — incompatible avec l'objectif « tout saisir au début, puis laisser tourner ». En passant la passphrase via `--key-file=-` (lecture sur stdin), le prompt natif est court-circuité ; c'est le script qui gère la double saisie et la comparaison, une seule fois, avant `warmup_sudo`. `--batch-mode` est nécessaire en plus : sans lui, `luksFormat` demande toujours confirmation en tapant `YES`, même avec un keyfile.

**`printf '%s' "$VAULT_PASSPHRASE"`, jamais en argument de commande.** `printf` est un builtin bash : utilisé sans chemin explicite, il s'exécute dans le processus shell (forké pour le pipe) sans `exec` d'un nouveau programme, donc la passphrase n'apparaît jamais dans `ps`/`/proc/<pid>/cmdline`. `echo` aurait le même avantage mais un comportement moins prévisible sur les caractères spéciaux ; `printf '%s'` ne rajoute pas non plus de retour à la ligne final, ce qui garantit que `luksFormat` et `open` reçoivent exactement les mêmes octets. `VAULT_PASSPHRASE` n'est jamais `export`é : elle n'apparaît donc pas dans `/proc/<pid>/environ`.

**Délégation à `vault-open.sh` plutôt que duplication.** `vault-create.sh` ne connaît pas la liste des bind mounts (profils Vivaldi/Brave/Firefox) : cette liste vit uniquement dans `vault-open.sh`. Après `open_luks` + `format_fs`, le script appelle directement `vault-open.sh`, qui constate que `/dev/mapper/vault_prof` existe déjà (donc ne redemande pas la passphrase) et que `$MNT` n'est pas encore monté, puis monte et pose les binds via ses propres vérifications d'idempotence. Le mot de passe sudo mis en cache par `warmup_sudo` couvre aussi les appels `sudo` internes de `vault-open.sh`, exécuté comme un sous-processus du même utilisateur pendant que la boucle de rafraîchissement tourne encore.

**`rm -f "$IMG"` avant de recréer.** `fallocate -l TAILLE` ne fait que réserver de l'espace jusqu'à `TAILLE` : sur un fichier existant plus grand que la nouvelle taille demandée, il ne le tronque pas. Après confirmation explicite de l'utilisateur (`SUPPRIMER`), le script supprime l'ancien fichier avant l'appel à `fallocate`, pour repartir d'un conteneur réellement vierge plutôt que d'un fichier partiellement recyclé.

**`check_not_open` avant toute autre chose.** Recréer le conteneur pendant que `/dev/mapper/vault_prof` est actif casserait le mapping en cours (le fichier backend changerait sous les pieds du device-mapper). Le script s'arrête immédiatement et renvoie vers `vault-close.sh`.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | ---------------------------- |
| `cryptsetup` | toute version récente (Debian/Ubuntu stable) | `luksFormat --batch-mode --key-file=-`, `open --key-file=-` |
| `bash` | 4.x | builtins `printf`/`read -s`, `[[ ]]` |
| `fallocate` (util-linux) | — | réservation du fichier conteneur |
| `mkfs.ext4` (e2fsprogs) | — | formatage du volume |
| `vault-open.sh` | même dépôt | montage + bind mounts, appelé en fin de script |

### Points d'extension

**Support d'un type LUKS explicite** — le script laisse `cryptsetup` choisir son défaut (LUKS2 sur les versions récentes). Pour figer le format :

```bash
printf '%s' "$VAULT_PASSPHRASE" \
  | sudo cryptsetup luksFormat --type luks2 --batch-mode --key-file=- "$IMG"
```

**Recréation non interactive complète** (ex : provisioning automatisé) — un flag `--passphrase-file FICHIER` pourrait remplacer `read_passphrase`, en gardant bien à l'esprit que stocker la passphrase en clair sur disque déplace le risque plutôt que de le supprimer ; à réserver à un usage où ce compromis est explicitement acceptable.

### Notes de maintenance

- **La liste des bind mounts n'existe pas ici.** Ajouter un nouveau navigateur au vault se fait dans `vault-open.sh` (tableau `BINDS`) et doit être répercuté dans `vault-close.sh` (`BIND_TARGETS`) et `vault-status.sh` — pas dans `vault-create.sh`, qui n'a aucune connaissance de cette liste.
- **Pas de migration automatique.** Un profil déjà présent hors du vault au moment de la création reste à son emplacement d'origine, masqué mais intact tant que le vault est monté. Pour l'y intégrer après coup : fermer le vault (`vault-close.sh`), ouvrir manuellement le point de montage concerné (`vault-open.sh`), puis déplacer l'ancien profil dans le sous-répertoire correspondant du vault avant de relancer les binds — voir la fiche `LUKS vault.md`, section 3.3, pour le détail.
- **Taille par défaut.** `15G` reprend la valeur de la fiche d'origine ; ajuster la constante `DEFAULT_SIZE` si l'espace disque de la machine prof change.
- **Modèle de menace.** La passphrase transite en clair par un pipe vers un processus `sudo` le temps de l'exécution : c'est cohérent avec le fait que l'utilisateur a de toute façon des droits root sur la machine via `sudo`. Le script ne cherche pas à se protéger d'un root malveillant sur la même machine.
