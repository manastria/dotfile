# `pack-project.sh` — Archive `.tar.zst` d'un projet de développement

> Script : [`.local/bin/pack-project.sh`](../.local/bin/pack-project.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`pack-project.sh` crée l'archive `.tar.zst` d'un projet de développement en écartant automatiquement les artefacts régénérables — `node_modules`, `.venv`, `target`, `vendor`, `__pycache__`, `dist`, `build` — mais en **conservant `.git`** : l'archive reste un dépôt complet. Sans argument il archive le répertoire courant et dépose `nom-du-projet_AAAAMMJJ_HHMM.tar.zst` dans le répertoire parent ; un premier argument désigne le projet, un second le répertoire de destination (qui doit déjà exister). La compression est en zstd niveau **3** par défaut, ajustable par la variable `PACK_ZSTD_LEVEL`. C'est le raccourci sans réglage : pour choisir le codec, produire aussi un `.zip` ou passer ses propres exclusions, utiliser `pack-dir.sh` ; pour ne sauvegarder que l'historique Git sans les fichiers de travail, `pack-bundle.sh`. Extraction : `tar -I zstd -xf mon-app_20260823_0649.tar.zst`.

---

## Section utilisateur

### Description

`pack-project.sh` crée une archive compressée `.tar.zst` d'un projet de développement, en excluant les répertoires d'artefacts générés (dépendances, caches, binaires compilés) et en conservant le dépôt Git.

L'archive est un `.tar.zst` standard, extractible partout où `tar` et `zstd` sont disponibles.

Trois scripts d'archivage cohabitent dans le dépôt, à ne pas confondre :

| Script | Ce qu'il capture | Quand l'utiliser |
| ------ | ---------------- | ---------------- |
| `pack-project.sh` | arborescence de travail moins les artefacts, `.git` compris | sauvegarde rapide d'un projet, sans réglage |
| [`pack-dir.sh`](pack_dir.md) | idem, mais tout est configurable (codec, `.zip`, exclusions) | besoin d'une option précise |
| [`pack-bundle.sh`](pack-bundle.md) | uniquement l'historique Git (commits, branches, tags) | transfert hors ligne d'un dépôt, sans les fichiers non commités |

> Le nom historique `pack_project` (l'outil était une fonction shell) subsiste dans les anciennes notes ; le script s'appelle aujourd'hui `pack-project.sh`.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4 | tableaux indexés (`EXCLUDES`) | `bash --version` |
| `tar` (GNU) | création de l'archive, `--exclude` | `tar --version` |
| `zstd` | compression | `zstd --version` |
| `realpath` (coreutils) | résolution des chemins | `realpath --version` |
| `pv` | **optionnel** : barre de progression | `pv --version` (`apt install pv`) |

Sans `pv`, le script le signale par un `[ATTENTION]` et affiche une progression par points de contrôle (`→ bloc N`).

---

### Syntaxe

```
pack-project.sh [SOURCE] [DESTINATION]
```

| Argument | Type | Défaut | Description |
| -------- | ---- | ------ | ----------- |
| `SOURCE` | chemin | répertoire courant (`.`) | Racine du projet à archiver |
| `DESTINATION` | chemin | répertoire parent de `SOURCE` | Répertoire de dépôt de l'archive — **doit exister** |

Le script n'accepte aucune option ; `-h` n'est pas géré.

| Variable d'environnement | Défaut | Description |
| ------------------------ | ------ | ----------- |
| `PACK_ZSTD_LEVEL` | `3` | Niveau de compression zstd (1 = rapide, 19 = maximal). Au-delà de 15, le script avertit que la compression sera très lente. |

---

### Exemples d'utilisation

```bash
# Archiver le projet courant → déposé dans le répertoire parent
cd ~/projets/mon-app
pack-project.sh

# Archiver un projet désigné → déposé dans son répertoire parent
pack-project.sh ~/projets/mon-app

# Destination explicite (le répertoire doit exister)
pack-project.sh ~/projets/mon-app /media/usb/backup

# Compression plus poussée, pour un archivage longue durée
PACK_ZSTD_LEVEL=12 pack-project.sh ~/projets/mon-app
```

Sortie réelle :

```
[INFO]      Source      : /home/user/demo/mon-app
[INFO]      Archive     : /home/user/demo/mon-app_20260823_0649.tar.zst
[INFO]      Compression : zstd niveau 3  (PACK_ZSTD_LEVEL pour modifier)

[INFO]      Compression en cours...
Pack: 1,15MiB 0:00:00 [ 220MiB/s] [           <=>                    ]
[OK]        Archive : /home/user/demo/mon-app_20260823_0649.tar.zst (296K)
```

Interruption (`Ctrl+C`) ou erreur en cours d'écriture :

```
[ERREUR]    Interruption ou erreur — archive incomplète supprimée.
```

---

### Répertoires et fichiers exclus

| Écosystème | Exclusions |
| ---------- | ---------- |
| **Python** | `.venv`, `venv`, `env`, `.env`, `__pycache__`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`, `*.pyc`, `*.pyo`, `.tox`, `dist`, `build`, `*.egg-info` |
| **Node.js** | `node_modules`, `.npm`, `.yarn`, `.pnp` |
| **Java / Kotlin / Scala** | `target`, `.gradle`, `*.class`, `*.jar`, `*.war` |
| **Rust** | `target` |
| **Go / PHP / Composer** | `vendor` |
| **Système / IDE** | `.DS_Store`, `Thumbs.db` |

> `.git` est **conservé** intentionnellement : l'archive reste un dépôt clonable.

Deux conséquences à connaître :

- `.env` est exclu — les secrets d'un projet ne partent pas dans l'archive, mais un `.env` d'exemple utile non plus.
- `dist` et `build` sont exclus quel que soit l'écosystème. Un projet où `build/` contient des sources (et non des artefacts) doit passer par [`pack-dir.sh -E`](pack_dir.md) ou une liste d'exclusions personnalisée.

La liste n'est pas paramétrable en ligne de commande : c'est le rôle de `pack-dir.sh`.

---

### Nommage de l'archive

```
<nom_du_projet>_<AAAAMMJJ>_<HHMM>.tar.zst
```

Exemple : `mon-app_20260823_0649.tar.zst`. Le nom du projet est celui du répertoire source **résolu** : archiver `.` ou `../mon-app` produit le même nom.

---

### Extraction de l'archive

```bash
# Extraire dans le répertoire courant (recrée le dossier mon-app/)
tar -I zstd -xf mon-app_20260823_0649.tar.zst

# Lister le contenu sans extraire
tar -I zstd -tf mon-app_20260823_0649.tar.zst | head -30
```

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Archive créée |
| `1` | Erreur ou interruption — l'archive partielle est supprimée (source introuvable, destination inexistante, échec de `tar`/`zstd`, `Ctrl+C`) |

---

## Section développeur

### Architecture interne

Script linéaire, sans fonction `main()` : il tient en une centaine de lignes et s'exécute de haut en bas.

```
1. Résolution des chemins   →  realpath sur SOURCE ; DEST = dirname(SOURCE) par défaut
2. Nommage                  →  PROJECT_NAME = basename(SRC_REAL) + date +%Y%m%d_%H%M
3. Exclusions               →  tableau EXCLUDES → EXCLUDE_ARGS (--exclude=pattern)
4. Filet de sécurité        →  trap cleanup ERR INT TERM (supprime l'archive partielle)
5. Compression              →  tar --create | pv | zstd  (ou tar --use-compress-program sans pv)
6. Rapport                  →  du -sh sur l'archive
```

---

### Détail des choix techniques

**Exclusions sans préfixe `./`.** Les patterns sont passés tels quels : `--exclude="node_modules"`. Dans GNU tar, un pattern **sans `/`** est comparé au nom de base de chaque entrée, à toutes les profondeurs — c'est exactement ce qu'on veut pour `node_modules` ou `__pycache__` enfouis dans l'arborescence. Ajouter un `./` ancrerait le pattern à la racine de l'archive et n'exclurait plus que le premier niveau. Un commentaire du script le rappelle ; ne pas « corriger » cette absence de préfixe.

**`-C "$(dirname "$SRC_REAL")"` puis `"./${PROJECT_NAME}"`.** L'archive contient `./mon-app/…` et non un chemin absolu : l'extraction recrée un dossier propre, sans risque d'écraser une arborescence système.

**Pipeline `pv` plutôt que `tar --zstd`.** Quand `pv` est disponible, `tar --create | pv -N "Pack" | zstd … > archive` permet à `pv` de mesurer le flux **avant** compression et d'afficher une progression fiable. Sans `pv`, repli sur `tar --use-compress-program` avec `--checkpoint=500` et une action `ttyout` qui imite une progression. `set -o pipefail` est indispensable ici : sans lui, l'échec de `tar` en tête de pipeline serait masqué par le succès de `zstd`.

**`PACK_ZSTD_LEVEL` à 3 par défaut.** Le niveau 19 (ancien défaut) multipliait la durée par un facteur important pour un gain marginal sur des sources texte. Le niveau 3 est le compromis quotidien ; le script avertit à partir de 15 plutôt que d'interdire.

**`--long`.** Active la fenêtre longue de zstd : meilleur ratio sur les gros fichiers et les doublons distants dans l'archive, au prix de plus de RAM.

**`--ignore-failed-read`.** Un fichier illisible (permissions, socket, fichier supprimé pendant l'archivage) produit un avertissement au lieu d'un échec — l'archivage d'un projet en cours d'utilisation reste possible.

**`trap cleanup ERR INT TERM`.** Une archive `.tar.zst` tronquée est un piège : elle existe, elle a l'air valide, et elle est inexploitable. Le trap la supprime, puis le trap est retiré (`trap - ERR INT TERM`) avant le `du` final, pour qu'une erreur de mesure de taille ne détruise pas une archive correcte.

**`du -sh | cut -f1`.** Taille occupée sur disque, pas taille logique. Aucun échappement n'est nécessaire (le dépôt ne définit pas d'alias `du`).

---

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 4.0 | tableaux `EXCLUDES` / `EXCLUDE_ARGS` |
| `tar` | GNU 1.28 | `--exclude`, `--ignore-failed-read`, `--use-compress-program`, `--checkpoint-action=ttyout` |
| `zstd` | 1.3.2 | `-T0` (multithread), `--long` |
| `coreutils` | — | `realpath`, `basename`, `dirname`, `du` |
| `pv` | — | optionnel, barre de progression |

---

### Points d'extension

**Ajouter une exclusion** — étendre le tableau `EXCLUDES`, en respectant le regroupement par écosystème :

```bash
EXCLUDES=(
    ...
    # Ruby
    ".bundle" "vendor/bundle"
)
```

Attention : `vendor/bundle` contient un `/`, il est donc ancré à la racine de l'archive, contrairement aux patterns simples.

**Créer la destination si elle manque** — une ligne suffirait, alignée sur `pack-dir.sh` :

```bash
mkdir -p "$DEST"
```

**Exclusions par projet** — plutôt que de porter un `.packignore` ici, utiliser `pack-dir.sh -I .packignore`, qui l'implémente déjà.

---

### Notes de maintenance

- **La destination doit exister.** Contrairement à `pack-dir.sh` (qui fait `mkdir -p`), une destination absente fait échouer la redirection, ce qui déclenche le trap : l'erreur affichée est un `No such file or directory` de bash suivi du message de nettoyage. Comportement vérifié, non corrigé pour rester sur un script minimal.
- **Doublons dans `EXCLUDES`** (`target`, `vendor`, `dist`, `build`) : sans effet, `tar` ignore les `--exclude` redondants. Conservés pour la lisibilité par écosystème.
- **Écart avec le squelette du dépôt.** Le script n'a ni bloc manpage complet, ni `main()`, ni `-h`, ni `set -u` (il utilise `set -eo pipefail`), contrairement à ce que prescrit [CLAUDE.md](../CLAUDE.md). C'est un script antérieur à ces conventions ; toute réécriture devrait les rattraper d'un bloc, en commençant par l'en-tête et `--help`.
- **Cohérence avec `pack-dir.sh`.** Défauts, style de sortie, traps de nettoyage et pipeline `pv` sont volontairement identiques. Toute évolution de l'un doit être répercutée sur l'autre — voir les notes de [pack_dir.md](pack_dir.md).
- **Mémoire de `--long`.** Sur une machine à moins de 2 Go de RAM, remplacer `--long` par `--long=27` pour borner la fenêtre.
