# `pack-dir.sh` — Archivage configurable d'un dossier

---

## Section utilisateur

### Description

`pack-dir.sh` crée une archive compressée d'un dossier quelconque. C'est la version « couteau suisse » de [`pack_project`](pack_project.md) : mêmes réglages par défaut (dossier courant si non précisé, codec `zst`, date+heure dans le nom, dépôt dans le dossier parent de la source), mais avec des options en ligne de commande pour tout personnaliser — codec, nom de sortie, dossier de destination, génération d'un `.zip` en plus, fichier d'exclusions personnalisé, ou désactivation totale des exclusions.

En usage courant sans option, `pack-dir.sh [dossier]` se comporte comme `pack_project [dossier]` : le dossier est optionnel et vaut le dossier courant par défaut. Utiliser `pack-dir.sh` plutôt que `pack_project` quand on a besoin d'une de ces options spécifiques (typiquement `-z` pour un `.zip`, ou `-E` pour tout inclure sans exclusion).

---

### Prérequis

| Outil      | Rôle                              | Vérification      |
| ---------- | --------------------------------- | ------------------ |
| `bash`     | Interpréteur du script            | `bash --version`   |
| `tar`      | Création de l'archive             | `tar --version`    |
| `zstd`     | Compression (codec par défaut)    | `zstd --version`   |
| `realpath` | Résolution du dossier de sortie   | `realpath --version` |
| `zip`      | Optionnel, requis seulement avec `-z` | `zip --version` |

---

### Syntaxe

```
pack-dir.sh [dossier] [options]
```

`dossier` est optionnel : s'il est omis (ou si le premier argument est une option), la source est le dossier courant (`.`), comme pour `pack_project`.

| Option              | Argument         | Défaut                              | Description                                                    |
| ------------------- | ---------------- | ------------------------------------ | ---------------------------------------------------------------- |
| `-b <nom_base>`      | texte             | nom du dossier source                | Nom de base du fichier produit                                 |
| `-c <xz\|gz\|bz2\|zst>` | codec           | `zst`                                | Codec de compression tar                                       |
| `-T`                 | —                 | (date+heure ajoutée par défaut)      | N'ajoute **pas** la date+heure au nom du fichier                |
| `-z`                 | —                 | désactivé                            | Génère en plus une archive `.zip`                               |
| `-o <dir_sortie>`    | chemin            | dossier parent de la source          | Répertoire de dépôt de l'archive                                |
| `-I <fichier>`       | chemin            | aucun                                | Fichier d'exclusions supplémentaire (une règle par ligne)       |
| `-E`                 | —                 | désactivé                            | Désactive **toutes** les exclusions (ignore aussi `-I`)         |
| `-h`                 | —                 | —                                     | Affiche l'aide                                                  |

---

### Exemples d'utilisation

```bash
# Archive le dossier courant (equivalent de `pack_project` sans argument)
./pack-dir.sh

# Équivalent de pack_project : zst, timestamp, sortie dans le dossier parent
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

**Exemple de sortie :**

```
OK -> /home/user/projets/TP_20260708_2302.tar.zst
```

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

> `.git` n'est **pas** exclu par défaut (liste volontairement allégée par rapport aux versions précédentes du script) : il est inclus dans l'archive, comme avec `pack_project`. Utiliser un fichier `-I` pour l'exclure au besoin, ou `-E` pour désactiver toutes les exclusions.

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
| `1`  | Dossier source introuvable, ou option invalide/manquante |
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
5. Appel tar (et zip si -z) →  écrit dans $outdir
```

### Détail des choix techniques

**Dossier source optionnel**
`src="."` est la valeur par défaut. Le premier argument positionnel n'est consommé comme dossier source que s'il ne commence pas par `-` (`"$1" != -*`) : ainsi `pack-dir.sh -z` archive le dossier courant avec `-z`, sans avoir à écrire `pack-dir.sh . -z`. `--help` est intercepté avant ce test car `getopts` ne gère pas les options longues ; `-h` seul est géré normalement par `getopts`.

**`src_real` et `outdir` résolus après le parsing**
`outdir=""` est la valeur initiale ; ce n'est qu'après validation de l'existence du dossier source que `src_real="$(realpath "$src")"` puis `outdir="${outdir:-$(dirname "$src_real")}"` calculent le défaut. Résoudre `src` via `realpath` avant de calculer `default_base`, `parent` et `name` évite un nommage incorrect (`.` au lieu du vrai nom du dossier) quand la source est `.` ou un chemin relatif comme `../foo/`, exactement comme le fait `pack_project` avec `SRC_REAL`/`PROJECT_NAME`.

**`-T` plutôt qu'un flag d'activation**
La version précédente du script avait un flag `-t` pour *ajouter* le timestamp (désactivé par défaut). Depuis l'alignement des défauts sur `pack_project`, le timestamp est actif par défaut : `-T` (majuscule) fait l'inverse et le désactive.

**Double jeu d'exclusions (tar + zip)**
`tar` sait lire un fichier d'exclusions nativement (`--exclude-from`), mais `zip` non : le fichier `-I` est donc aussi relu ligne par ligne en bash pour construire les arguments `-x` du zip.

---

### Dépendances externes

```
bash        →  tableaux indexés (EXCLUDES, tar_exclude_args, zip_exclude_args)
tar         →  --exclude, --exclude-from, codecs -J/-z/-j/--zstd
zstd        →  utilisé via `tar --zstd` (codec par défaut)
realpath    →  résolution du dossier de sortie par défaut
zip         →  optionnel, uniquement si -z est utilisé
```

---

### Points d'extension

**Ajouter une exclusion par défaut**
Étendre le tableau `EXCLUDES` dans le script (`.local/bin/pack-dir.sh`).

**Désactiver les exclusions au cas par cas**
`-E` court-circuite entièrement le bloc `if ! $disable_excludes; then ... fi`, y compris un `-I` passé en même temps.

---

### Notes de maintenance

- **Cohérence avec `pack_project`** : les défauts (dossier courant si non précisé, codec `zst`, timestamp `_YYYYMMDD_HHMM`, dossier de sortie parent) sont volontairement identiques à [`pack_project`](pack_project.md) pour que `pack-dir.sh [dossier]` sans option produise le même résultat. Toute évolution des défauts de l'un devrait être répercutée sur l'autre.
- **Liste `EXCLUDES` volontairement allégée** : elle ne couvre plus que les cas génériques (VCS autres que git, artefacts Python/Node, IDE, build). `.git` n'y figure plus, contrairement à d'anciennes versions du script — se référer directement au tableau `EXCLUDES` dans le script pour la liste exacte et à jour.
