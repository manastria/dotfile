# `pack-bundle.sh` — Sauvegarde d'un dépôt Git en fichier `.bundle`

---

## Section utilisateur

### Description

`pack-bundle.sh` crée un **git bundle** du dépôt indiqué (répertoire courant par défaut) et l'écrit dans le répertoire parent du dépôt, comme le font [`pack-dir.sh`](pack_dir.md) et [`pack_project`](pack_project.md) pour les archives `tar`.

Un bundle est un fichier unique contenant l'historique Git : commits, arborescences, branches et tags. Il se comporte comme un dépôt distant en lecture seule, ce qui permet de le cloner directement :

```bash
git clone mon-projet_20260820_1030.bundle mon-projet
```

C'est donc l'outil adapté pour **sauvegarder ou transporter un dépôt hors-ligne** (clé USB, pièce jointe, machine sans réseau), là où `pack_project` sauvegarde l'arborescence de travail à un instant donné.

| Critère                                  | `pack_project` / `pack-dir.sh` (tar) | `pack-bundle.sh` (bundle)  |
| ---------------------------------------- | ------------------------------------ | -------------------------- |
| Historique Git complet                   | oui, via le dossier `.git` copié tel quel | oui, format natif Git, vérifié |
| Fichiers non commités / non suivis       | **oui**                              | **non**                    |
| Fichiers ignorés (`.env`, `build/`…)     | selon les exclusions                 | **non**                    |
| Dépôt sans arbre de travail (dépôt nu)   | non pertinent                        | supporté                   |
| Restauration                             | `tar -x`                             | `git clone` / `git fetch`  |
| Sauvegarde incrémentale                  | non                                  | oui (`-r base..HEAD`)      |
| Intégrité vérifiable                     | non                                  | oui (`git bundle verify`)  |

> Les deux approches sont complémentaires : le bundle garantit un historique exploitable, l'archive `tar` capture aussi le travail en cours.

---

### Prérequis

| Outil       | Rôle                                        | Vérification         |
| ----------- | ------------------------------------------- | -------------------- |
| `bash` ≥ 4  | Interpréteur (tableaux indexés)             | `bash --version`     |
| `git` ≥ 2.13 | Création et vérification du bundle, `rev-parse --absolute-git-dir` | `git --version` |
| `realpath`  | Normalisation du répertoire de sortie       | `realpath --version` |
| `du`        | Taille du fichier produit                   | `du --version`       |

Aucun droit administrateur n'est requis : le script travaille uniquement en espace utilisateur.

---

### Syntaxe

```
pack-bundle.sh [DEPOT] [-b NOM] [-o DIR] [-r REF]... [-T] [-f] [-h]
```

`DEPOT` est optionnel : par défaut le répertoire courant. Un sous-répertoire du dépôt est accepté, la racine est retrouvée automatiquement.

| Option               | Argument   | Défaut                    | Description                                                                 |
| -------------------- | ---------- | ------------------------- | --------------------------------------------------------------------------- |
| `-b`, `--base`       | texte      | nom du dépôt              | Nom de base du fichier produit                                              |
| `-o`, `--output`     | chemin     | répertoire parent du dépôt | Répertoire de dépôt du bundle (créé s'il n'existe pas)                      |
| `-r`, `--ref`        | référence  | `--all HEAD`              | Référence à inclure. **Répétable.** Remplace le contenu par défaut          |
| `-T`, `--no-timestamp` | —        | horodatage ajouté         | N'ajoute **pas** `_AAAAMMJJ_HHMM` au nom du fichier                          |
| `-f`, `--force`      | —          | désactivé                 | Écrase un bundle existant du même nom                                        |
| `-h`, `--help`       | —          | —                         | Affiche l'en-tête manpage du script                                          |

`-r` accepte tout ce que comprend `git rev-list` : un nom de branche (`main`), un tag (`v1.0`), un sélecteur (`--branches`, `--tags`), ou une plage de révisions pour un bundle incrémental (`origin/main..main`).

---

### Exemples d'utilisation

```bash
# Sauvegarde complète du dépôt courant, déposée dans le répertoire parent
cd ~/projets/dotfile
pack-bundle.sh

# Sauvegarde d'un dépôt précis vers une clé USB
pack-bundle.sh ~/projets/dotfile -o /media/usb/backup

# Nom fixe, sans horodatage : pratique pour un rsync/rclone incrémental
pack-bundle.sh -T -b dotfile-backup

# Bundle d'une seule branche, pour transmettre un travail en cours
pack-bundle.sh -r dev1

# Bundle incrémental : uniquement les commits absents du dépôt du destinataire
pack-bundle.sh -r origin/main..main -b delta -T

# Plusieurs références explicites
pack-bundle.sh -r main -r v2.0 -b release
```

**Exemple de sortie :**

```
[ATTENTION] Arbre de travail non propre : 3 entrée(s) modifiée(s) ou non suivie(s).
[ATTENTION] Un bundle ne contient que les commits — ces changements ne seront PAS sauvegardés.
[INFO]      Dépôt      : /home/user/projets/dotfile
[INFO]      Bundle     : /home/user/projets/dotfile_20260820_1030.bundle
[INFO]      Références : --all HEAD

[INFO]      Création du bundle...
[INFO]      Vérification...
[OK]        Bundle : /home/user/projets/dotfile_20260820_1030.bundle (11M, 10 référence(s))
[INFO]      Restauration : git clone "dotfile_20260820_1030.bundle" dotfile
```

---

### Ce que le bundle contient — et ne contient pas

**Inclus** : tous les commits atteignables depuis les références demandées, les branches, les tags, et `HEAD` (qui détermine la branche extraite au clonage).

**Non inclus** :

- les modifications non commitées et les fichiers non suivis (le script prévient si l'arbre de travail n'est pas propre) ;
- les fichiers ignorés par `.gitignore` — typiquement `.env`, `node_modules/`, les artefacts de build ;
- le remisage (`git stash`), les reflogs, la configuration locale `.git/config` ;
- **l'historique des sous-modules** : seul le commit pointé est enregistré. Le dépôt en compte sept (voir `.gitmodules`), aussi le script émet un avertissement dès qu'un `.gitmodules` est présent. Pour une sauvegarde exhaustive, produire un bundle par sous-module.

---

### Restauration

```bash
# Cloner un bundle complet vers un nouveau dépôt
git clone dotfile_20260820_1030.bundle dotfile

# Inspecter le contenu sans cloner
git bundle list-heads dotfile_20260820_1030.bundle
git bundle verify dotfile_20260820_1030.bundle

# Appliquer un bundle incrémental à un dépôt existant
cd ~/projets/dotfile
git fetch ../delta.bundle 'refs/heads/*:refs/remotes/backup/*'
```

> Un bundle incrémental (`-r origin/main..main`) exige que le dépôt destinataire possède déjà les commits de base. `git bundle verify` le signale en listant les références prérequises.

---

### Nommage du fichier

```
<nom_du_depot>_<AAAAMMJJ>_<HHMM>.bundle
```

Exemple : `dotfile_20260820_1030.bundle`. Avec `-T`, l'horodatage est omis (`dotfile.bundle`). Pour un dépôt nu (`projet.git`), le suffixe `.git` est retiré du nom de base.

---

### Codes de retour

| Code | Signification                                                                            |
| ---- | ---------------------------------------------------------------------------------------- |
| `0`  | Bundle créé et vérifié                                                                    |
| `1`  | Erreur d'exécution : `git` absent, chemin qui n'est pas un dépôt, dépôt sans commit, échec de `git bundle` ou vérification négative |
| `2`  | Erreur d'usage : option inconnue, option à valeur sans argument, répertoire introuvable, bundle déjà existant sans `--force` |

---

## Section développeur

### Architecture interne

Le script suit le squelette canonique du dépôt (constantes, log, options, fonctions par responsabilité, `main "$@"` en dernière ligne) :

```
parse_args      →  analyse des options (boucle while, options longues et courtes)
resolve_repo    →  racine du dépôt, détection dépôt nu, refus d'un dépôt sans référence
resolve_output  →  répertoire de sortie, nom de base, horodatage, garde anti-écrasement
check_worktree  →  avertissements (arbre sale, sous-modules) — jamais bloquants
create_bundle   →  git bundle create, sous trap de nettoyage
verify_bundle   →  git bundle verify + taille + nombre de références
```

---

### Détail des choix techniques

**`--all HEAD` par défaut**
`--all` embarque toutes les références sous `refs/`, mais `git clone` a besoin de `HEAD` pour savoir quelle branche extraire. Sans `HEAD`, le clonage réussit (code 0) mais laisse un arbre de travail **vide**, avec un simple avertissement « remote HEAD refers to nonexistent ref » — un piège classique pour une sauvegarde que l'on croit valide.

**`rev-parse --absolute-git-dir` pour les dépôts nus**
`--git-dir` renvoie `.` lorsqu'on est déjà dans un dépôt nu ; un `realpath` sur cette valeur résoudrait le chemin depuis le répertoire **courant** et non depuis le dépôt visé, produisant un bundle du mauvais dépôt. `--absolute-git-dir` (Git ≥ 2.13) supprime le problème.

**Refus d'un dépôt sans référence**
`git bundle create` échoue de son côté, mais tardivement et avec un message peu explicite. Le test `for-each-ref --count=1 refs/` produit un diagnostic immédiat et lisible.

**`trap cleanup ERR INT TERM` autour de la création**
Un bundle interrompu est un fichier tronqué : `git` le refusera, mais il pourrait passer pour une sauvegarde valide dans un listing. Le trap le supprime, puis est retiré (`trap - ERR INT TERM`) dès la création terminée pour ne pas capturer les erreurs de la phase de vérification.

**`git bundle verify` systématique**
Seule garantie que le fichier produit est exploitable. La sortie est masquée (`>/dev/null`) : elle est verbeuse et le message de succès du script suffit. En cas d'échec, `die` interrompt avec le chemin fautif.

**`value_of` avant chaque `shift 2`**
Une option à valeur laissée sans argument (`pack-bundle.sh -r`) ferait échouer `shift 2`, et `set -e` sortirait **silencieusement** avec le code 1. Le garde-fou transforme ce cas en erreur d'usage explicite (code 2).

**Avertissements plutôt que blocages**
Arbre de travail sale et présence de sous-modules sont des limites intrinsèques au format bundle, pas des erreurs. Le script informe et poursuit : refuser aurait rendu l'outil inutilisable dans son cas d'usage principal — sauvegarder rapidement avant de quitter la machine.

---

### Dépendances externes

```
bash ≥ 4     →  tableaux indexés (REFS, refs)
git ≥ 2.13   →  bundle create/verify/list-heads, rev-parse --absolute-git-dir
coreutils    →  realpath, du, basename, dirname, date, wc
awk          →  réimpression de l'en-tête manpage par --help
```

---

### Points d'extension

**Rotation des sauvegardes**
Le script ne purge rien. Pour ne conserver que les N derniers bundles :

```bash
ls -1t ~/backup/dotfile_*.bundle | tail -n +8 | xargs -r rm --
```

**Sauvegarde périodique de tous les dépôts d'un répertoire**
Se combine avec [`check-git-sync.sh`](../.local/bin/check-git-sync.sh) pour ne sauvegarder que ce qui n'est pas déjà poussé :

```bash
for repo in ~/projets/*/; do
    [ -d "$repo/.git" ] && pack-bundle.sh "$repo" -o ~/backup -T -f
done
```

**Sauvegarde des sous-modules**
Boucler sur `git submodule foreach` et produire un bundle par sous-module dans un sous-répertoire dédié.

---

### Notes de maintenance

- **Nom du fichier et horodatage à la minute** : deux exécutions dans la même minute déclenchent la garde anti-écrasement (code 2). C'est voulu — passer `-f` ou `-b` pour trancher explicitement.
- **Bundle écrit dans le dépôt** : détecté et signalé (`-o .`). Sans horodatage ni `.gitignore`, le bundle suivant embarquerait le précédent, avec un effet boule de neige sur la taille.
- **Taille** : un bundle `--all` est de l'ordre de grandeur du dossier `.git` compacté (≈ 11 Mo pour ce dépôt). Aucun niveau de compression n'est exposé : `git bundle` réutilise le packfile existant, déjà compressé en zlib.
- **Bundles incrémentaux et rebase** : après réécriture d'historique, une plage `origin/main..main` peut devenir inapplicable chez le destinataire. En cas de doute, produire un bundle complet.
