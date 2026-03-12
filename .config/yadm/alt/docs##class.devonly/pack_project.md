# `pack_project` — Archivage portable de projets de développement

---

## Section utilisateur

### Description

`pack_project` est un script bash qui crée une archive compressée (`.tar.zst`) d'un projet de développement en excluant automatiquement les répertoires d'artefacts générés (dépendances, caches, binaires compilés), tout en conservant le dépôt Git (`.git`).

L'archive produite est un fichier `.tar.zst` standard, nativement compatible Linux et extractible sans outil tiers sur tout système disposant de `tar` et `zstd`.

---

### Prérequis

| Outil      | Rôle                   | Vérification         |
| ---------- | ---------------------- | -------------------- |
| `bash` ≥ 4 | Interpréteur du script | `bash --version`     |
| `tar`      | Création de l'archive  | `tar --version`      |
| `zstd`     | Compression            | `zstd --version`     |
| `realpath` | Résolution des chemins | `realpath --version` |

> Sous Windows, l'environnement recommandé est **Git Bash** ou **MobaXTerm**.  
> `zstd` doit être installé séparément et accessible dans le `PATH` (ex. via `winget install zstd`).

---

### Syntaxe

```
pack_project [SOURCE] [DESTINATION]
```

| Argument      | Type   | Défaut                        | Description                               |
| ------------- | ------ | ----------------------------- | ----------------------------------------- |
| `SOURCE`      | chemin | répertoire courant (`.`)      | Répertoire racine du projet à archiver    |
| `DESTINATION` | chemin | répertoire parent de `SOURCE` | Répertoire de dépôt de l'archive produite |

---

### Exemples d'utilisation

```bash
# Archiver le projet courant → déposé dans le répertoire parent
cd ~/projets/mon-app
pack_project

# Archiver un projet distant → déposé dans son répertoire parent
pack_project ~/projets/mon-app

# Archiver vers une destination explicite (ex. clé USB)
pack_project ~/projets/mon-app /e/backup
```

**Exemple de sortie :**

```
📦 Archivage de : /home/user/projets/mon-app
   → /home/user/projets/mon-app_20260312_1430.tar.zst
   Exclusions : .venv venv env .env __pycache__ ...

✅ Archive créée : /home/user/projets/mon-app_20260312_1430.tar.zst (4,2M)
```

---

### Répertoires et fichiers exclus

| Écosystème                | Exclusions                                                                                                                             |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Python**                | `.venv`, `venv`, `env`, `.env`, `__pycache__`, `.mypy_cache`, `.pytest_cache`, `*.pyc`, `*.pyo`, `.tox`, `dist`, `build`, `*.egg-info` |
| **Node.js**               | `node_modules`, `.npm`, `.yarn`, `.pnp`                                                                                                |
| **Java / Kotlin / Scala** | `target`, `.gradle`, `*.class`, `*.jar`, `*.war`                                                                                       |
| **Rust**                  | `target`                                                                                                                               |
| **Go / PHP / Composer**   | `vendor`                                                                                                                               |
| **Système / IDE**         | `.DS_Store`, `Thumbs.db`                                                                                                               |

> Le répertoire `.git` est **conservé** intentionnellement.

---

### Nommage de l'archive

```
<nom_du_projet>_<AAAAMMJJ>_<HHMM>.tar.zst
```

Exemple : `mon-app_20260312_1430.tar.zst`

---

### Extraction de l'archive

```bash
# Extraire dans le répertoire courant
tar -I zstd -xf mon-app_20260312_1430.tar.zst

# Lister le contenu sans extraire
tar -I zstd -tf mon-app_20260312_1430.tar.zst | head -30
```

---

### Codes de retour

| Code | Signification                           |
| ---- | --------------------------------------- |
| `0`  | Archive créée avec succès               |
| `1`  | Erreur lors de la création de l'archive |

---

## Section développeur

### Architecture interne

Le script s'articule en quatre phases séquentielles :

```
1. Résolution des chemins   →  realpath sur SOURCE et DEST
2. Construction des exclusions  →  tableau EXCLUDES → EXCLUDE_ARGS (--exclude=./pattern)
3. Appel tar + zstd         →  tar --create | zstd -T0 -19 --long
4. Rapport                  →  \du -s -h pour la taille finale
```

Les variables sont toutes déclarées en portée locale (dans la version fonction `.bashrc`) ou en portée globale de script (version `~/bin`). Aucune variable d'environnement globale n'est modifiée.

---

### Détail des choix techniques

**`realpath`**  
Normalise les chemins relatifs (`./`, `../`, `~`) avant tout traitement, ce qui évite les erreurs de construction du chemin de l'archive.

**`--exclude="./${pattern}"`**  
Le préfixe `./` est indispensable : `tar` ancre les patterns sur le chemin relatif depuis `-C`. Sans lui, un pattern comme `target` exclurait faussement des fichiers dont le nom contient cette chaîne en position quelconque.

**`zstd -T0 -19 --long`**

| Option   | Effet                                                              |
| -------- | ------------------------------------------------------------------ |
| `-T0`    | Utilise tous les cœurs CPU disponibles                             |
| `-19`    | Niveau de compression maximal (1–19)                               |
| `--long` | Active le mode fenêtre longue (meilleur ratio sur grands fichiers) |

**`\du` (backslash)**  
Contourne les alias shell éventuels (ex. `alias du='du -kh'`) pour appeler le binaire natif directement.

---

### Dépendances externes

```
bash ≥ 4    →  tableaux indexés (EXCLUDES, EXCLUDE_ARGS)
tar         →  option --use-compress-program (GNU tar ou libarchive)
zstd        →  binaire externe appelé via --use-compress-program
realpath    →  coreutils (GNU) ou équivalent
```

> Git Bash embarque `tar` (via MSYS2) et `realpath` (coreutils GNU).  
> `zstd` n'est pas inclu dans Git Bash et doit être installé séparément.

---

### Variables d'environnement

| Variable         | Défaut | Description                                       |
| ---------------- | ------ | ------------------------------------------------- |
| `PACK_ZSTD_LEVEL` | `19`  | Niveau de compression zstd (1 = rapide, 19 = max) |

Exemple :

```bash
PACK_ZSTD_LEVEL=3 pack_project ~/projets/mon-app
```

---

### Points d'extension

**Ajouter une exclusion**
Étendre le tableau `EXCLUDES` dans le script :

```bash
EXCLUDES=(
    ...
    # Ruby
    ".bundle" "vendor/bundle"
)
```

**Exclusions personnalisées par projet**  
Lire un fichier `.packignore` à la racine du projet si présent :

```bash
if [[ -f "${SRC}/.packignore" ]]; then
    while IFS= read -r line; do
        EXCLUDE_ARGS+=(--exclude="./${line}")
    done < "${SRC}/.packignore"
fi
```

---

### Notes de maintenance

- **Doublons dans `EXCLUDES`** (`target`, `vendor`) : sans effet fonctionnel, `tar` ignore les `--exclude` redondants. Ils sont conservés pour la lisibilité par écosystème.
- **Compatibilité Windows/Linux** : le script fonctionne sans modification dans les deux environnements, à condition que `zstd` soit dans le `PATH`.
- **Taille de la fenêtre `--long`** : sur des machines avec peu de RAM (< 2 Go), remplacer `--long` par `--long=27` pour limiter l'usage mémoire de zstd.
