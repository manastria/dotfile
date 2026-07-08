# `pack-dir.sh` — Archivage configurable d'un dossier

---

## Section utilisateur

### Description

`pack-dir.sh` crée une archive compressée d'un dossier quelconque. C'est la version « couteau suisse » de [`pack_project`](pack_project.md) : mêmes réglages par défaut (codec `zst`, date+heure dans le nom, dépôt dans le dossier parent de la source), mais avec des options en ligne de commande pour tout personnaliser — codec, nom de sortie, dossier de destination, génération d'un `.zip` en plus, fichier d'exclusions personnalisé, ou désactivation totale des exclusions.

En usage courant sans option, `pack-dir.sh <dossier>` se comporte comme `pack_project <dossier>`. Utiliser `pack-dir.sh` plutôt que `pack_project` quand on a besoin d'une de ces options spécifiques (typiquement `-z` pour un `.zip`, ou `-E` pour tout inclure sans exclusion).

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
pack-dir.sh <dossier> [options]
```

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
.git .git/** .svn .hg
.DS_Store Thumbs.db
node_modules node_modules/**
__pycache__ **/__pycache__ *.pyc *.pyo
.pytest_cache .mypy_cache .ruff_cache
.venv venv env
.idea .vscode
dist build *.egg-info
```

> Contrairement à `pack_project`, `.git` est **exclu** par défaut ici. Utiliser `-E` pour le conserver (avec tout le reste), ou un fichier `-I` pour affiner.

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
1. Parsing des options   →  getopts ":b:c:Tzo:I:Eh"
2. Résolution des chemins →  outdir par défaut = dirname(realpath(source))
3. Construction des exclusions →  tableau EXCLUDES + fichier -I → tar_exclude_args / zip_exclude_args
4. Appel tar (et zip si -z) →  écrit dans $outdir
```

### Détail des choix techniques

**`outdir` résolu après le parsing**
`outdir=""` est la valeur initiale ; ce n'est qu'après validation de l'existence du dossier source que `outdir="${outdir:-$(dirname "$(realpath "$src")")}"` calcule le défaut, pour rester alignable avec `pack_project` (dossier parent de la source) sans forcer `realpath` sur une source potentiellement invalide.

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

- **Cohérence avec `pack_project`** : les défauts (codec `zst`, timestamp `_YYYYMMDD_HHMM`, dossier de sortie parent) sont volontairement identiques à [`pack_project`](pack_project.md) pour que `pack-dir.sh <dossier>` sans option produise le même résultat. Toute évolution des défauts de l'un devrait être répercutée sur l'autre.
- **`.git` exclu par défaut** ici, contrairement à `pack_project` qui le conserve intentionnellement — c'est la différence de comportement à garder en tête au moment de choisir entre les deux scripts.
