# pack-split.sh

> Script : [`.local/bin/pack-split.sh`](../.local/bin/pack-split.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`pack-split.sh` prépare **un gros fichier** (image de VM, disque, archive) pour un Drive ou une clé USB : `pack-split.sh pack disque.qcow2` le compresse en zstd, le découpe en volumes de 1 Go dans un répertoire `disque.qcow2.split/`, y ajoute des empreintes BLAKE3 et des données de réparation par2, puis relit le tout pour prouver que la restauration sera identique à l'original. Il ne synchronise rien et ne téléverse rien : c'est à vous de copier le répertoire, et `pack-split.sh verify` dit ensuite si la copie est intacte. `pack-split.sh unpack disque.qcow2.split` refait le fichier dans le répertoire parent, en réparant au passage les volumes abîmés. L'original n'est supprimé qu'avec `-d`, ou après un « oui » explicite à la question posée dans un terminal. Les options utiles au quotidien sont `-s` (taille des volumes, `500M`, `2G`…), `-o` (écrire directement sur la clé) et `-r` (part de redondance par2).

---

## Section utilisateur

### Description

Les Drives (kDrive, Google Drive) et les clés USB supportent mal les fichiers de plusieurs dizaines de Go : un envoi interrompu repart de zéro, une corruption silencieuse n'est vue qu'à la restauration. `pack-split.sh` contourne les deux :

- **volumes de taille fixe** (1 Go par défaut) : un échec ne coûte qu'un volume ;
- **empreintes BLAKE3** (`b3sum`) : détectent n'importe quelle altération, avant et après transfert ;
- **données par2** : reconstruisent un volume abîmé sans le retransférer.

Trois commandes :

| Commande | Rôle |
| -------- | ---- |
| `pack` | Fichier → répertoire `FICHIER.split/`. Propose ensuite de supprimer l'original. |
| `verify` | Contrôle les volumes d'un répertoire `.split` (après transfert, avant restauration). Ne modifie rien. |
| `unpack` | Répertoire `.split` → fichier d'origine, dans le répertoire parent. Répare si besoin. |

Différence avec les scripts voisins : [`pack-dir.sh`](pack_dir.md) et [`pack-project.sh`](pack_project.md) archivent un **répertoire** en un seul `.tar.zst` ; `pack-split.sh` traite **un fichier** et vise le transfert fiable, pas l'archivage de projets.

**Contenu du répertoire produit** :

```
disque.qcow2.split/
├── disque.qcow2.zst.001 … .NNN     volumes zstd
├── disque.qcow2.b3                 empreintes BLAKE3 des volumes
├── disque.qcow2.orig.b3            empreinte BLAKE3 du fichier d'origine
├── disque.qcow2.par2               index par2
├── disque.qcow2.vol000+01.par2 …   volumes de réparation par2
└── RESTAURER.txt                   restauration manuelle, sans le script
```

> Le répertoire ne peut pas porter exactement le nom du fichier (les deux cohabitent dans le même dossier) ; il prend le suffixe `.split`.

**Ce que la redondance protège.** Avec 10 % (défaut), par2 répare jusqu'à ~10 % de blocs perdus ou corrompus *sur l'ensemble des volumes*. C'est taillé pour des corruptions localisées ou un ou deux volumes tronqués sur un lot d'une vingtaine ; perdre plus que la part prévue (par exemple un volume sur trois) est irréparable. Augmentez `-r` si le support est peu fiable.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `zstd` | Compression / décompression | `zstd --version` |
| `par2` | Création et réparation des données de redondance | `par2 --version` |
| `b3sum` | Empreintes BLAKE3 | `b3sum --version` |
| `pv` | Barres de progression | `pv --version` |
| `split`, `stat`, `df`, `numfmt` | Coreutils | `split --version` |

Le script contrôle leur présence avant de commencer et affiche la commande d'installation :

```bash
sudo apt install zstd par2 b3sum pv
```

Aucun droit administrateur n'est requis pour le script lui-même.

---

### Syntaxe

```
pack-split.sh pack   FICHIER [-o DIR] [-s TAILLE] [-l NIVEAU] [-r POURCENT] [-d]
pack-split.sh unpack REPERTOIRE [-o DIR] [-f]
pack-split.sh verify REPERTOIRE
pack-split.sh -h
```

| Option | Argument | Défaut | Commande | Description |
| ------ | -------- | ------ | -------- | ----------- |
| `-o`, `--output` | chemin | pack : dossier du fichier ; unpack : parent du `.split` | pack, unpack | Répertoire de sortie (créé au besoin) |
| `-s`, `--size` | taille | `1G` | pack | Taille d'un volume, format de `split(1)` : `500M`, `1G`, `2G`… |
| `-l`, `--level` | 1 à 19 | `3` | pack | Niveau zstd. Plus haut : plus petit, bien plus lent |
| `-r`, `--redundancy` | 1 à 100 | `10` | pack | Redondance par2, en pourcents |
| `-d`, `--delete-source` | — | désactivé | pack | Supprime l'original après vérification, sans question |
| `-f`, `--force` | — | désactivé | unpack | Écrase un fichier existant du même nom |
| `-h`, `--help` | — | — | toutes | Affiche l'en-tête manpage |

Les options sans objet pour la commande choisie sont acceptées et ignorées.

---

### Exemples d'utilisation

```bash
# Prépare disque.qcow2 → ./disque.qcow2.split/
pack-split.sh pack disque.qcow2

# Volumes de 500 Mo directement sur la clé USB, puis suppression de l'original
pack-split.sh pack disque.qcow2 -s 500M -o /media/usb -d

# Après le transfert vers le Drive (répertoire resynchronisé en local) : intact ?
pack-split.sh verify ~/kDrive/disque.qcow2.split

# Restauration dans le répertoire parent de disque.qcow2.split
pack-split.sh unpack ~/kDrive/disque.qcow2.split

# Restauration ailleurs, en écrasant une ancienne version
pack-split.sh unpack disque.qcow2.split -o /srv/vm -f
```

**Exemple de sortie de `pack` :**

```
[INFO]      Fichier    : /home/user/vm/disque.qcow2 (42GB)
[INFO]      Sortie     : /home/user/vm/disque.qcow2.split
[INFO]      Paramètres : volumes 1G, zstd niveau 3, par2 10%

[INFO]      [1/5] Empreinte BLAKE3 du fichier d'origine...
empreinte: 42,0GiB 0:01:48 [ 397MiB/s] [=================>] 100%
[INFO]      [2/5] Compression zstd et découpage en volumes de 1G...
compression: 42,0GiB 0:03:12 [ 224MiB/s] [=================>] 100%
[INFO]      19 volume(s) créé(s), 18GB au total.
[INFO]      [3/5] Empreintes BLAKE3 des volumes...
[INFO]      [4/5] Données de réparation par2 (10%)...
Processing: 63.2%
[INFO]      [5/5] Contrôle de bout en bout : relecture, décompression, comparaison...
contrôle: 18,0GiB 0:01:20 [ 230MiB/s] [=================>] 100%

[OK]        Prêt à transférer : /home/user/vm/disque.qcow2.split
[INFO]      Taille : 20GB pour 42GB d'origine.
[INFO]      Après transfert, contrôle : pack-split.sh verify "/home/user/vm/disque.qcow2.split"
Supprimer le fichier d'origine ? [o/N]
```

**Exemple de sortie de `unpack` avec un volume corrompu :**

```
[INFO]      [1/3] Contrôle des volumes (b3sum)...
disque.qcow2.zst.001: OK
disque.qcow2.zst.002: FAILED
[ATTENTION] Volume(s) corrompu(s) ou manquant(s) : tentative de réparation par2...
Repair complete.
[INFO]      Nouveau contrôle après réparation...
[OK]        Volumes réparés.
[INFO]      [2/3] Concaténation et décompression...
[INFO]      [3/3] Vérification du fichier restauré...
[OK]        Fichier restauré : /home/user/vm/disque.qcow2 (42GB, empreinte conforme)
```

**Restauration sans le script** : `RESTAURER.txt` (dans le répertoire) donne les trois commandes : `b3sum --check`, `par2 repair`, puis `cat disque.qcow2.zst.* | zstd -d > disque.qcow2`.

---

### Suppression de l'original

`pack` ne supprime jamais l'original avant d'avoir **relu les volumes, les avoir décompressés et comparé l'empreinte obtenue à celle de l'original**. Si elles diffèrent, le répertoire produit est effacé et l'original reste intact.

Ensuite :

- avec `-d`, l'original est supprimé sans question ;
- sans `-d` dans un terminal, la question est posée (défaut : non) ;
- sans `-d` hors terminal (cron, redirection), il est conservé et la commande `rm` est affichée.

Ce contrôle prouve que les volumes **sur ce disque** sont bons. Il ne prouve rien sur la copie distante : lancer `verify` sur le Drive resynchronisé *avant* de supprimer l'original est la bonne pratique, donc plutôt `pack` sans `-d`, puis `rm` à la main.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Opération réussie et vérifiée |
| `1` | Erreur d'exécution : outil manquant, volume irréparable, empreinte finale différente, disque plein |
| `2` | Erreur d'usage : option inconnue, argument manquant ou invalide, chemin introuvable, destination déjà existante |

---

## Section développeur

### Architecture interne

```
main
├── parse_args        commande, options, validation des valeurs (avant tout travail long)
├── check_tools       zstd, par2, b3sum, pv
└── cmd_pack | cmd_unpack | cmd_verify

cmd_pack
├── prepare_pack         chemins, refus d'une sortie existante, espace libre, mkdir
├── hash_source          b3sum de l'original  → NOM.orig.b3
├── compress_and_split   pv | zstd | split    → NOM.zst.001…
├── hash_volumes         b3sum par volume     → NOM.b3
├── create_par2          par2 create sur volumes + manifestes
├── verify_roundtrip     cat volumes | zstd -d | b3sum  == empreinte de l'original
├── write_readme         RESTAURER.txt
└── offer_source_deletion

cmd_unpack
├── load_pack_dir        NOM et empreinte (NOM.orig.b3), liste des volumes (NOM.b3)
├── check_volumes → repair_volumes (par2) → check_volumes
├── cat volumes | pv | zstd -d > NOM.partial
└── b3sum de NOM.partial == empreinte, puis mv vers NOM

cmd_verify
└── load_pack_dir, check_volumes, diagnostic par2 verify en cas d'échec
```

---

### Détail des choix techniques

**Pipeline unique `pv | zstd | split`.**
Aucun fichier intermédiaire de la taille de l'original : l'espace disque nécessaire est celui des volumes. `set -o pipefail` fait échouer l'ensemble si `zstd` plante (disque plein sur `split`, par exemple) — sans lui, seul `split` serait pris en compte.

**Empreinte de l'original calculée dans une passe séparée.**
Une lecture de plus, mais la logique reste simple et robuste : l'alternative (`tee >(b3sum)`) exige d'attendre une substitution de processus dont `pipefail` ne remonte pas les erreurs. Le contrôle de bout en bout compare ensuite deux empreintes calculées indépendamment.

**Contrôle de bout en bout plutôt que simple `b3sum -c`.**
Relire les volumes juste après les avoir hachés ne prouve que leur lecture. Décompresser et comparer à l'empreinte de l'original prouve que `zstd -d` redonnera le fichier exact : c'est la condition réelle pour supprimer la source.

**Liste des volumes lue dans le manifeste, jamais par glob.**
Un volume absent ne doit pas être ignoré : `b3sum --check` le signale et par2 peut le reconstituer. Un glob aurait produit un fichier restauré silencieusement tronqué (détecté seulement par l'empreinte finale).

**Les manifestes `.b3` sont protégés par par2.**
Un manifeste corrompu rendrait la vérification sans remède. En revanche `RESTAURER.txt` ne l'est pas : il est informatif.

**`cd` dans le répertoire avant `par2`.**
par2 mémorise les noms de fichiers tels qu'il les reçoit. Avec des chemins absolus, le répertoire ne serait plus relocalisable (Drive, clé USB, autre machine).

**Écriture dans `NOM.partial` à la restauration.**
Un fichier portant le nom définitif est toujours complet et vérifié. L'écrasement par `--force` n'a lieu qu'au `mv` final.

**`trap cleanup EXIT` avec `CLEANUP_PATHS`.**
Toute erreur ou interruption supprime les sorties incomplètes (répertoire `.split` en cours de création, `.partial`). `INT` et `TERM` passent par `exit` pour déclencher le trap. La liste est vidée à la réussite.

**`--numeric-suffixes=1`.**
`split -d` seul numérote à partir de `000` ; `.001` est plus naturel et correspond à la convention des archives multivolumes.

**`par2 -q` hors terminal.**
Le pourcentage de par2 se réécrit sur place (`\r`) dans un terminal et prouve que le calcul avance. Redirigé vers un fichier, il produit des milliers de lignes.

**Pas d'option `--force` pour `pack`.**
Écraser un répertoire `.split` existant reviendrait à supprimer récursivement un dossier à partir d'un nom déduit : le script refuse (code 2) et laisse l'utilisateur trancher.

---

### Dépendances externes

```
bash ≥ 4.4   →  tableaux vides sous set -u ("${quiet[@]}"), mapfile
zstd         →  compression / décompression (-T0 : multithread)
par2         →  par2cmdline ≥ 0.8 : create, verify, repair, -q, -r
b3sum ≥ 1.0  →  --no-names, --check
pv           →  progression sur stdin (-N, -s)
coreutils    →  split (--numeric-suffixes=FROM), stat, df, numfmt, realpath
```

---

### Points d'extension

**Autre taille de volume par défaut** (ex. limite d'un service de transfert) :

```bash
readonly DEFAULT_SIZE="500M"
```

**Plus de 999 volumes** (au-delà de 999 Go compressés avec 1G) :

```bash
readonly SPLIT_SUFFIX_LEN=4
```

Le motif `*.zst.[0-9]*` de `compress_and_split` reste valable.

**Compression de gros fichiers très redondants** : ajouter `--long=27` côté `zstd` impose le même paramètre à la décompression (`zstd -d --long=27`), dans `unpack`, `verify_roundtrip` et `RESTAURER.txt`.

---

### Notes de maintenance

- **Pas de reprise** : un `pack` interrompu repart de zéro (le répertoire partiel est supprimé). Pour un fichier de plusieurs centaines de Go, prévoir plusieurs heures.
- **Volume entièrement perdu** : réparable seulement si la redondance couvre sa part du total. Avec 3 volumes et 10 %, ce n'est pas le cas ; avec 20 volumes, oui.
- **Réparation par par2** : les fichiers endommagés sont renommés en `.1` dans le répertoire, ils ne sont pas supprimés. Le répertoire grossit tant qu'on ne les retire pas.
- **`NOM.orig.b3` perdu** : le script ne peut plus déterminer le nom d'origine. Il suggère `par2 repair` à la main (il est protégé par par2).
- **Une seule source par répertoire** : `load_pack_dir` exige exactement un `*.orig.b3`.
- **Noms de fichiers** : testé avec des noms simples. Les noms contenant `\` ou un saut de ligne ne sont pas pris en charge (format des manifestes `b3sum`).
- **Espace disque** : l'avertissement de `pack` suppose le pire cas (fichier incompressible) ; `unpack` ne vérifie pas l'espace, l'échec d'écriture est détecté par `pipefail` et le `.partial` supprimé.
