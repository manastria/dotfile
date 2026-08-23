# `pack-dir.sh` — Archivage configurable d'un dossier

> Script : [`.local/bin/pack-dir.sh`](../.local/bin/pack-dir.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`pack-dir.sh` archive n'importe quel dossier avec les mêmes réglages par défaut que `pack-project.sh` (dossier courant, codec `zst`, horodatage dans le nom, dépôt dans le dossier parent), mais avec des options pour tout changer : `-c` choisit le codec (`xz`, `gz`, `bz2`, `zst`), `-z` produit en plus un `.zip` commode pour un partage vers Windows, `-o` fixe le dossier de sortie (créé au besoin), `-b` le nom de base, `-T` retire l'horodatage. Côté exclusions, `-I` ajoute un fichier de patterns façon `.gitignore` et `-E` les désactive toutes pour archiver le dossier à l'identique. La liste par défaut est volontairement légère — artefacts Python et Node, dossiers d'IDE, `dist`/`build` — et **ne retire pas `.git`**. C'est le couteau suisse de l'archivage : pour un projet de développement sans réglage particulier, `pack-project.sh` suffit, et pour ne sauvegarder que l'historique Git, c'est `pack-bundle.sh`.

---

## Section utilisateur

### Description

`pack-dir.sh` crée une archive compressée d'un dossier quelconque. C'est la version « couteau suisse » de [`pack-project.sh`](pack_project.md) : mêmes réglages par défaut (dossier courant si non précisé, codec `zst`, date+heure dans le nom, dépôt dans le dossier parent de la source), mais avec des options en ligne de commande pour tout personnaliser — codec, nom de sortie, dossier de destination, génération d'un `.zip` en plus, fichier d'exclusions personnalisé, ou désactivation totale des exclusions.

En usage courant sans option, `pack-dir.sh [dossier]` se comporte comme `pack-project.sh [dossier]` : le dossier est optionnel et vaut le dossier courant par défaut. Utiliser `pack-dir.sh` plutôt que `pack-project.sh` quand on a besoin d'une de ces options spécifiques (typiquement `-z` pour un `.zip`, ou `-E` pour tout inclure sans exclusion).

---

### Prérequis

| Outil      | Rôle                              | Vérification      |
| ---------- | --------------------------------- | ------------------ |
| `bash`     | Interpréteur du script            | `bash --version`   |
| `tar`      | Création de l'archive             | `tar --version`    |
| `zstd`     | Compression (codec par défaut)    | `zstd --version`   |
| `realpath` | Résolution du dossier de sortie   | `realpath --version` |
| `pv`       | Optionnel, barre de progression pendant la compression | `pv --version` (`apt install pv`) |
| `xz` / `gzip` / `bzip2` | Optionnel, requis uniquement si `-c` sélectionne ce codec | `xz --version`, etc. |
| `zip`      | Optionnel, requis seulement avec `-z` | `zip --version` |

---

### Syntaxe

```
pack-dir.sh [dossier] [options]
```

`dossier` est optionnel : s'il est omis (ou si le premier argument est une option), la source est le dossier courant (`.`), comme pour `pack-project.sh`.

| Option              | Argument         | Défaut                              | Description                                                    |
| ------------------- | ---------------- | ------------------------------------ | ---------------------------------------------------------------- |
| `-b <nom_base>`      | texte             | nom du dossier source                | Nom de base du fichier produit                                 |
| `-c <xz\|gz\|bz2\|zst>` | codec           | `zst`                                | Codec de compression tar                                       |
| `-T`                 | —                 | (date+heure ajoutée par défaut)      | N'ajoute **pas** la date+heure au nom du fichier                |
| `-z`                 | —                 | désactivé                            | Génère en plus une archive `.zip`                               |
| `-o <dir_sortie>`    | chemin            | dossier parent de la source          | Répertoire de dépôt de l'archive, **créé s'il n'existe pas** (`mkdir -p`) |
| `-I <fichier>`       | chemin            | aucun                                | Fichier d'exclusions supplémentaire (une règle par ligne)       |
| `-E`                 | —                 | désactivé                            | Désactive **toutes** les exclusions (ignore aussi `-I`)         |
| `-h`                 | —                 | —                                     | Affiche l'aide                                                  |

---

### Exemples d'utilisation

```bash
# Archive le dossier courant (equivalent de `pack-project.sh` sans argument)
./pack-dir.sh

# Équivalent de pack-project.sh : zst, timestamp, sortie dans le dossier parent
./pack-dir.sh ./TP

# Sans date+heure dans le nom
./pack-dir.sh ./TP -T

# Génère aussi un .zip (utile pour un partage vers Windows)
./pack-dir.sh ./TP -z

# Codec gzip, sortie dans un dossier explicite
./pack-dir.sh ./TP -c gz -o ./out

# Nom de fichier personnalisé
./pack-dir.sh ./TP -b elec-ccf -z

# Exclusions personnalisées en plus des exclusions par défaut
./pack-dir.sh ./TP -I .packignore

# Tout inclure, y compris .git, node_modules, etc.
./pack-dir.sh ./TP -E
```

**Exemple de sortie** (avec `pv` installé, comme `pack-project.sh`) :

```
[INFO]      Source      : /home/user/projets/TP
[INFO]      Archive     : /home/user/projets/TP_20260708_2302.tar.zst
[INFO]      Codec       : zst

[INFO]      Compression en cours...
Pack: 4.21MiB 0:00:00 [ 187MiB/s] [                              <=>            ]
[OK]        Archive : /home/user/projets/TP_20260708_2302.tar.zst (4,2M)
```

Sans `pv` installé, un message `[ATTENTION]` invite à l'installer et une progression par points de contrôle (`→ bloc N`) s'affiche à la place de la barre `pv`.

---

### Répertoires et fichiers exclus par défaut

```
.svn .hg
.DS_Store Thumbs.db
node_modules node_modules/**
__pycache__ **/__pycache__ *.pyc *.pyo
.pytest_cache .mypy_cache .ruff_cache
.venv venv env
.idea .vscode
dist build *.egg-info
```

> `.git` n'est **pas** exclu par défaut (liste volontairement allégée par rapport aux versions précédentes du script) : il est inclus dans l'archive, comme avec `pack-project.sh`. Utiliser un fichier `-I` pour l'exclure au besoin, ou `-E` pour désactiver toutes les exclusions.

Le fichier passé via `-I` accepte un pattern par ligne (glob tar/zip), lignes vides et commentaires (`#`) ignorés :

```
# commentaires OK
.git
node_modules
**/__pycache__
.vscode
.idea
dist
build
```

---

### Nommage de l'archive

```
<nom_base><_AAAAMMJJ_HHMM si pas de -T>.<extension du codec>
```

Exemple : `TP_20260708_2302.tar.zst` (ou `TP.tar.zst` avec `-T`).

---

### Codes de retour

| Code | Signification                                    |
| ---- | ------------------------------------------------- |
| `0`  | Archive créée avec succès                         |
| `1`  | Dossier source introuvable, option invalide ou sans argument, ou interruption/erreur pendant l'écriture (l'archive partielle est supprimée) |
| `2`  | Codec invalide                                    |
| `3`  | `zip` demandé (`-z`) mais non installé            |
| `4`  | Fichier d'exclusions (`-I`) introuvable           |

---

## Section développeur

### Architecture interne

```
1. Dossier source optionnel →  si absent (ou 1er argument = une option), src="."
2. Parsing des options      →  getopts ":b:c:Tzo:I:Eh"
3. Résolution des chemins   →  src_real=realpath(src) ; outdir par défaut = dirname(src_real)
4. Construction des exclusions →  tableau EXCLUDES + fichier -I → tar_exclude_args / zip_exclude_args
5. Choix du codec           →  compress_cmd (xz -T0 -c / gzip -c / bzip2 -c / zstd -T0 -c --long)
6. Creation de l'archive    →  tar --create | pv -N "Pack" | "${compress_cmd[@]}" > $tar_out
                                (ou, sans pv, tar --use-compress-program="${compress_cmd[*]}" avec checkpoints)
7. Zip optionnel (-z)       →  zip -rq9 vers $outdir, avec son propre trap de nettoyage
```

### Détail des choix techniques

**Dossier source optionnel**
`src="."` est la valeur par défaut. Le premier argument positionnel n'est consommé comme dossier source que s'il ne commence pas par `-` (`"$1" != -*`) : ainsi `pack-dir.sh -z` archive le dossier courant avec `-z`, sans avoir à écrire `pack-dir.sh . -z`. `--help` est intercepté avant ce test car `getopts` ne gère pas les options longues ; `-h` seul est géré normalement par `getopts`.

**`src_real` et `outdir` résolus après le parsing**
`outdir=""` est la valeur initiale ; ce n'est qu'après validation de l'existence du dossier source que `src_real="$(realpath "$src")"` puis `outdir="${outdir:-$(dirname "$src_real")}"` calculent le défaut. Résoudre `src` via `realpath` avant de calculer `default_base`, `parent` et `name` évite un nommage incorrect (`.` au lieu du vrai nom du dossier) quand la source est `.` ou un chemin relatif comme `../foo/`, exactement comme le fait `pack-project.sh` avec `SRC_REAL`/`PROJECT_NAME`.

**`-T` plutôt qu'un flag d'activation**
La version précédente du script avait un flag `-t` pour *ajouter* le timestamp (désactivé par défaut). Depuis l'alignement des défauts sur `pack-project.sh`, le timestamp est actif par défaut : `-T` (majuscule) fait l'inverse et le désactive.

**Double jeu d'exclusions (tar + zip)**
`tar` sait lire un fichier d'exclusions nativement (`--exclude-from`), mais `zip` non : le fichier `-I` est donc aussi relu ligne par ligne en bash pour construire les arguments `-x` du zip.

**Pipeline `pv`, aligné sur `pack-project.sh`**
Comme `pack-project.sh`, la création de l'archive tar passe par un pipeline `tar --create | pv -N "Pack" | <compresseur> > $tar_out` quand `pv` est disponible, plutôt que de laisser `tar` invoquer directement le compresseur (`-J`/`-z`/`-j`/`--zstd`). Cela permet à `pv` de mesurer le flux brut produit par `tar` et d'afficher une barre de progression, quel que soit le codec choisi via `-c`. `compress_cmd` est un tableau (`xz -T0 -c`, `gzip -c`, `bzip2 -c`, ou `zstd -T0 -c --long`) construit dans le `case "$codec"`, réutilisé tel quel dans le pipeline et, joint en une chaîne (`"${compress_cmd[*]}"`), passé à `tar --use-compress-program` dans le repli sans `pv` (avec `--checkpoint`/`--checkpoint-action` pour simuler une progression par points).

**Fonctions de log et traps de nettoyage**
Le script utilise désormais les fonctions `info`/`success`/`warn`/`error`/`die` standard du dépôt (voir `CLAUDE.md`, section « Shell Script Color and Logging Conventions »), identiques à celles de `pack-project.sh`. Chaque étape de création de fichier (`cleanup_tar` pour le tar, `cleanup_zip` pour le zip) pose un `trap ... ERR INT TERM` qui supprime le fichier de sortie s'il est interrompu ou échoue en cours d'écriture, puis retire le trap (`trap - ERR INT TERM`) une fois l'étape terminée — même logique que le `cleanup`/`trap cleanup ERR INT TERM` de `pack-project.sh`.

---

### Dépendances externes

```
bash              →  tableaux indexés (EXCLUDES, tar_exclude_args, zip_exclude_args, compress_cmd)
tar               →  --exclude, --exclude-from, --use-compress-program, --checkpoint
pv                →  optionnel, barre de progression sur le flux tar avant compression
xz/gzip/bzip2/zstd →  invoqués en pipeline (compress_cmd), un seul requis selon -c
realpath          →  résolution du dossier de sortie et de la source par défaut
zip               →  optionnel, uniquement si -z est utilisé
```

---

### Points d'extension

**Ajouter une exclusion par défaut**
Étendre le tableau `EXCLUDES` dans le script (`.local/bin/pack-dir.sh`).

**Désactiver les exclusions au cas par cas**
`-E` court-circuite entièrement le bloc `if ! $disable_excludes; then ... fi`, y compris un `-I` passé en même temps.

---

### Notes de maintenance

- **Cohérence avec `pack-project.sh`** : les défauts (dossier courant si non précisé, codec `zst`, timestamp `_YYYYMMDD_HHMM`, dossier de sortie parent, barre de progression `pv`, style de sortie écran, traps de nettoyage) sont volontairement identiques à [`pack-project.sh`](pack_project.md) pour que `pack-dir.sh [dossier]` sans option produise le même résultat et le même affichage. Toute évolution des défauts ou du style de sortie de l'un devrait être répercutée sur l'autre.
- **Liste `EXCLUDES` volontairement allégée** : elle ne couvre plus que les cas génériques (VCS autres que git, artefacts Python/Node, IDE, build). `.git` n'y figure plus, contrairement à d'anciennes versions du script — se référer directement au tableau `EXCLUDES` dans le script pour la liste exacte et à jour.
- **Pas de niveau de compression réglable** : contrairement à `pack-project.sh` (`PACK_ZSTD_LEVEL`), `pack-dir.sh` n'expose pas de niveau de compression par variable d'environnement ; chaque codec utilise le niveau par défaut de son compresseur.
