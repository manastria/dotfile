# git-depannage.sh — Alias Git temporaires et diagnostic de dépôt

> Script : [`.shellrc/depannage/git-depannage.sh`](../.shellrc/depannage/git-depannage.sh) (fichier **sourcé**, hors de `.local/bin/`)
> Page Notion associée : *Git : Diagnostiquer et corriger un dépôt Git* (recettes de correction)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`git-depannage.sh` se **source** dans le terminal d'un étudiant pour dépanner sans ses propres alias : `. <(curl -fsSL URL)`. Il définit des alias courts (`gs`, `gl`, `gd`…), la commande `gdiag` qui affiche tout l'état du dépôt d'un coup, et `gaide` qui rappelle la liste. Il n'écrit **rien** sur le disque (ni `~/.gitconfig`, ni `.git/config`) et ne modifie jamais le dépôt : les corrections (`reset`, `merge --abort`…) restent à taper à la main. Tout disparaît à la fermeture du terminal. Au quotidien : `gdiag` pour comprendre la situation, puis `gl` pour le graphe des branches avec les auteurs.

---

## Section utilisateur

### Description

Sur le poste d'un étudiant, les alias Git habituels n'existent pas, et `git config --global alias.xxx` modifierait sa configuration. Ce fichier fournit donc des **alias shell** (propres au terminal courant) et deux fonctions, sans aucune trace durable.

Il diffère de ses voisins :

| Élément | Portée | Persistance |
| ------- | ------ | ----------- |
| `git-depannage.sh` | terminal courant, chargé à la main | aucune (fermeture du terminal) |
| `.shellrc/rc.d/alias.sh` | tous mes shells, chargé par `.bashrc`/`.zshrc` | permanente, sur ma machine |
| `.gitconfig_alias` | tous mes dépôts, via `git xxx` | permanente, sur ma machine |

Le fichier n'est **pas** chargé automatiquement : il vit dans `.shellrc/depannage/`, un dossier que ni `.bashrc` ni `.zshrc` ne parcourent. Les alias n'interfèrent donc jamais avec ceux de ma machine.

Alias définis (liste également affichée par `gaide`) :

| Alias | Commande | Usage |
| ----- | -------- | ----- |
| `gs` | `git status -sb` | état court : branche et une ligne par fichier |
| `gl` | `git log --graph --all --format="%C(auto)%h%d %s (%an)"` | graphe de toutes les branches, avec auteur |
| `gll` | `gl` + `--name-status` | fichiers touchés (A/M/D/R) |
| `gls` | `gl` + `--stat` | volume des changements |
| `gd` | `git diff` | modifications non indexées |
| `gdc` | `git diff --cached` | modifications indexées |
| `gdh` | `git diff HEAD` | tout, par rapport au dernier commit |
| `ga` | `git add` | indexer |
| `gc` | `git commit` | commiter |
| `gsw` | `git switch` | changer de branche |
| `grv` | `git remote -v` | dépôts distants |
| `gsl` | `git stash list` | travail mis de côté |

`gdiag` affiche, en lecture seule : l'état de `HEAD` et des fichiers (`git status -sb`), l'**opération en cours** (merge, rebase, cherry-pick, revert, bisect, `am`, tête détachée) avec la commande pour l'annuler, les fichiers en conflit, les N derniers commits en graphe, le stash et les dépôts distants. Les « pistes » affichées (`->`) sont du texte : rien n'est exécuté.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4 ou `zsh` | shell qui source le fichier | `echo $BASH_VERSION` / `echo $ZSH_VERSION` |
| `git` ≥ 2.23 | `git switch` (alias `gsw` et pistes affichées) | `git --version` |
| `curl` | chargement distant uniquement | `curl --version` |

### Syntaxe

```bash
# Chargement distant (dépôt public) :
. <(curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/main/.shellrc/depannage/git-depannage.sh)

# Chargement local (sur ma machine) :
. ~/.shellrc/depannage/git-depannage.sh

gdiag [N]
gdiag -h
gaide
```

| Argument | Défaut | Description |
| -------- | ------ | ----------- |
| `N` | 10 | nombre de commits affichés dans l'historique de `gdiag` |
| `-h`, `--help` | — | résumé de l'usage de `gdiag` |

### Exemples d'utilisation

```bash
# Sur le poste de l'étudiant : charger les alias
. <(curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/main/.shellrc/depannage/git-depannage.sh)

# L'étudiant est « bloqué » : comprendre la situation en une commande
gdiag

# Voir qui a fait quoi, avec les fichiers touchés
gll

# Rappel des alias
gaide
```

Exemple de sortie de `gdiag`, pendant un rebasage en conflit :

```text
== État de HEAD et des fichiers ==
## HEAD (no branch)
UU f

== Opération en cours ==
Rebasage (rebase) en cours.
  -> Annuler : git rebase --abort   |   Poursuivre après résolution : git rebase --continue
HEAD détachée sur 52d2500 (normal pendant cette opération).
Fichiers en conflit :
  f
  -> Après résolution : git add <fichier>, puis poursuivre l'opération

== Historique (10 derniers commits, toutes branches) ==
* 04ebdfa (dev) trois-dev (Test)
| * 52d2500 (HEAD, main) quatre-main (Test)
|/  
* 8828c75 deux (Test)
* 0f4f3c3 un (Test)

== Travail mis de côté (stash) ==
(aucun)

== Dépôts distants ==
(aucun)
```

### Codes de retour

Le fichier est sourcé : seuls `gdiag` et le chargement renvoient un code.

| Code | Signification |
| ---- | ------------- |
| 0 | `gdiag` : diagnostic affiché (aussi pour `-h`) |
| 1 | `gdiag` : pas dans un dépôt Git ; ou fichier exécuté au lieu d'être sourcé |
| 2 | `gdiag` : argument invalide (nombre de commits attendu) |

---

## Section développeur

### Architecture interne

Au chargement : garde « fichier sourcé » → définition des alias via `_gdep_alias` (qui alimente aussi `_GDEP_LISTE`) → définition des fonctions → message de confirmation.

`gdiag` enchaîne cinq sections : `git status -sb` → détection des opérations en cours (`_gdep_existe` sur les marqueurs internes de Git) → tête détachée → fichiers en conflit (`--diff-filter=U`) → `git log --graph --all -n N` → `git stash list` → `git remote -v`.

### Détail des choix techniques

**Alias shell plutôt que `alias.*` de Git.** Les alias shell fonctionnent avec n'importe quelle version de Git. La solution `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_n` (vrais alias `git lg`) exigerait Git ≥ 2.31 : Debian 11 n'a que la 2.30.

**Aucun `set -e` / `set -u`**, contrairement aux scripts de `rc.d/`. Un fichier sourcé s'exécute *dans* le shell de l'étudiant : une option `-e` y persisterait et fermerait son terminal à la première commande qui échoue. Le fichier n'utilise jamais `exit` (sauf dans la garde, où le fichier est justement exécuté), toujours `return`.

**Pas de fonctions `info`/`warn`/`error`.** Les conventions de couleurs de `.local/bin/` ne s'appliquent pas ici : `info` est une vraie commande Unix, et ces noms génériques masqueraient des commandes de l'étudiant. Tout est préfixé `_gdep_`/`_GDEP_`, et les messages d'erreur suivent seulement le format `[ERREUR]`.

**Garde `(return 0 2>/dev/null)`.** `return` n'est valide que dans un fichier sourcé. Exécuté directement, le fichier définirait ses alias dans un sous-shell aussitôt perdu : mieux vaut refuser avec un message.

**`git rev-parse --git-path`** pour les marqueurs (`MERGE_HEAD`, `rebase-merge`…). Dans un worktree ou un submodule, `.git` est un fichier : un test direct sur `.git/MERGE_HEAD` échouerait.

**Tête détachée et opération en cours.** `HEAD` est détachée par construction pendant un rebase ou un bisect. Dans ce cas la piste « `git switch -` » serait fausse : elle n'est donnée que si aucune opération n'est en cours.

**`git --no-pager`** pour l'historique de `gdiag` : le diagnostic doit s'afficher d'un bloc, sans que `less` n'interrompe la lecture. Les alias `gl`, `gll`, `gls` gardent le pager par défaut (historique potentiellement long).

**`local` sur les variables de `gaide`.** zsh exécute le dernier maillon d'un pipeline dans le shell courant : sans `local`, les variables de la boucle `read` fuiraient chez l'étudiant.

**`gs` masque Ghostscript** (`/usr/bin/gs`, installé avec `cups-filters` sur de nombreux postes). Sans conséquence — l'alias ne vit que dans ce terminal — mais à garder en tête si l'étudiant tape `gs` pour autre chose.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `git` | 2.23 | `git switch` (alias `gsw`, pistes) |
| `git` | 2.5 | `rev-parse --git-path` |
| `sed` | — | indentation de la liste des conflits |

### Points d'extension

Ajouter un alias : une ligne `_gdep_alias`, il apparaît automatiquement dans `gaide`.

```bash
_gdep_alias gsh 'git show --stat' 'dernier commit et fichiers touchés'
```

Détecter une autre opération en cours dans `gdiag` : même schéma que les blocs existants, avec le marqueur interne de Git correspondant.

```bash
if _gdep_existe SEQUENCER; then
    libre="non"
    echo "Séquence de cherry-pick en cours."
fi
```

### Notes de maintenance

- **Ne jamais y mettre de commande qui modifie le dépôt** : le fichier est destiné à des postes qui ne sont pas les miens, et chaque correction doit rester visible et tapée à la main (voir la page Notion).
- **Le caractère `|` est réservé** : `_GDEP_LISTE` utilise `|` comme séparateur. Une commande d'alias contenant un `|` casserait `gaide` (pas les alias eux-mêmes).
- **Testé** sous bash 5.2 et zsh 5.9, sur dépôt propre, vide, tête détachée, merge, rebase et cherry-pick en conflit, stash, et hors dépôt. Pas de test sous `dash`/`sh` : le fichier n'est pas POSIX (`local`).
- **Le fichier doit rester sourçable depuis un flux** (`. <(curl …)`) : ne pas utiliser `$0`, `BASH_SOURCE` ou `dirname` pour retrouver son emplacement.
- **Dépôt public requis** pour le chargement par `curl`. Hors ligne ou dépôt privé : copier le fichier et le sourcer en local.
