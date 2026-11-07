# `git-main-to-master.sh` — Convertir un dépôt de `main` vers `master`

> Script : [`.local/bin/git-main-to-master.sh`](../.local/bin/git-main-to-master.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`git-main-to-master.sh` renomme la branche `main` d'un dépôt en `master`, **en local et sur le remote** : il publie `master`, renomme la branche locale, règle le suivi (`upstream`) puis supprime `main` sur le serveur. Il sert à remettre d'équerre les dépôts créés avec `main` ; pour un nouveau dépôt, l'alias `git start` crée déjà directement `master`. Il ne fait rien si le dépôt n'est pas **propre** (changements, fichiers non suivis, rebase en cours) et ne réécrit jamais l'historique ni les tags. Les options utilisées au quotidien sont `-n` (simulation), `-y` (sans confirmation, pour boucler sur plusieurs dépôts) et `-L` (local seulement). Les autres clones du dépôt ne sont pas mis à jour : le script affiche en fin de course les quatre commandes à y passer.

---

## Section utilisateur

### Description

Les dépôts de ce projet utilisent `master` comme branche principale (voir l'alias `start` de `.gitconfig_alias`). `git-main-to-master.sh` convertit un dépôt existant dont la branche s'appelle `main`.

La conversion se fait dans cet ordre, le remote d'abord : s'il refuse, le dépôt local n'a pas bougé.

1. `main` est publiée sous le nom `master` sur le remote ;
2. la branche locale est renommée ;
3. `master` et les autres branches locales qui suivaient `origin/main` suivent désormais `origin/master` ;
4. `origin/HEAD` pointe sur `master` ;
5. si le remote est GitHub et que `gh` est connecté, la branche par défaut du dépôt GitHub passe à `master` ; puis `main` est supprimée sur le remote.

Différence avec le script voisin : [`check-git-sync.sh`](../.local/bin/check-git-sync.sh) compare des dépôts à leurs remotes mais ne renomme aucune branche.

Le script **refuse** de démarrer si :

- le dépôt n'est pas propre (`git status --porcelain` non vide : modifications, fichiers non suivis) ou si un merge, rebase, cherry-pick ou revert est en cours ;
- `master` existe déjà, en local ou sur le remote ;
- `origin/main` contient des commits absents de la `main` locale (faire un `git pull` avant) ;
- le remote est injoignable (rien n'est alors modifié).

Un dépôt déjà sur `master` n'est pas une erreur : le script le constate et sort avec le code 0. Un dépôt sans remote `origin` est converti en local seulement (avertissement).

---

### Prérequis

| Outil      | Rôle                                                       | Vérification         |
| ---------- | ---------------------------------------------------------- | -------------------- |
| `bash` ≥ 4 | Interpréteur                                               | `bash --version`     |
| `git` ≥ 2.20 | `branch -m`, `branch -u`, `merge-base --is-ancestor`, `remote set-head` | `git --version` |
| `gh` (facultatif) | Bascule de la branche par défaut GitHub, nécessaire pour supprimer `main` sur GitHub | `gh auth status` |

Le script doit être lancé en **utilisateur normal** (il refuse root, qui créerait des objets root dans `.git`). Un accès en écriture au remote est nécessaire pour la partie distante.

---

### Syntaxe

```
git-main-to-master.sh [DEPOT] [-r REMOTE] [-L] [-k] [-n] [-y] [-h]
```

| Option / argument        | Argument | Défaut             | Description                                                              |
| ------------------------ | -------- | ------------------ | ------------------------------------------------------------------------ |
| `DEPOT`                  | chemin   | répertoire courant | Dépôt à convertir (un sous-dossier est accepté)                           |
| `-r`, `--remote`         | nom      | `origin`           | Remote à convertir                                                        |
| `-L`, `--local-only`     | —        | désactivé          | Ne pas toucher au remote                                                  |
| `-k`, `--keep-remote-main` | —      | désactivé          | Publier `master` mais garder `main` sur le remote (pas de suppression)    |
| `-n`, `--dry-run`        | —        | désactivé          | Affiche les commandes sans rien exécuter                                  |
| `-y`, `--yes`            | —        | désactivé          | Ne pas demander de confirmation                                           |
| `-h`, `--help`           | —        | —                  | Affiche l'en-tête manpage du script                                       |

Sans `--yes` et hors simulation, le script demande confirmation (`[o/N]`) ; sans terminal pour répondre, il refuse plutôt que de supprimer une branche distante sans accord.

---

### Exemples d'utilisation

```bash
# Dépôt courant : plan affiché, puis confirmation
cd ~/projets/mon-site
git-main-to-master.sh

# Simulation : liste les commandes sans rien modifier
git-main-to-master.sh ~/projets/mon-site -n

# Tous les dépôts d'un répertoire, sans question ; un échec n'arrête pas la boucle
for d in ~/projets/*/; do git-main-to-master.sh "$d" -y || true; done

# Prudence : publier master mais laisser main en place sur le serveur
git-main-to-master.sh -k

# Dépôt dont le remote est hors de portée
git-main-to-master.sh -L
```

**Exemple de sortie** (dépôt local avec `origin`, branche par défaut déjà basculée) :

```
=== Conversion main → master ===

[INFO]      Dépôt : /home/user/projets/mon-site
[INFO]      Local : renommer main en master
[INFO]      Remote 'origin' : publier master, régler le suivi et origin/HEAD
[ATTENTION] Remote 'origin' : supprimer main (irréversible côté serveur)

Continuer ? [o/N] o
[INFO]      Publication de main sous le nom master sur 'origin'
[INFO]      Renommage local main → master
[INFO]      Suppression de origin/main

[OK]        Dépôt converti : master
[INFO]      Dans chaque autre clone de ce dépôt :
    git fetch --prune origin
    git branch -m main master
    git branch -u origin/master master
    git remote set-head origin master
```

Cas fréquent sur GitHub **sans `gh`** : `main` est encore la branche par défaut, le serveur refuse de la supprimer, le script termine avec le code 3 en indiquant la marche à suivre. Il suffit de changer la branche par défaut dans *Settings → Branches*, puis :

```bash
git push origin --delete main
```

---

### Codes de retour

| Code | Signification                                                                                                   |
| ---- | --------------------------------------------------------------------------------------------------------------- |
| `0`  | Conversion terminée, ou dépôt déjà sur `master` (rien à faire), ou simulation réussie                            |
| `1`  | Précondition non remplie ou erreur : dépôt sale, pas un dépôt Git, `master` déjà présente, remote injoignable ou en avance, confirmation refusée sans terminal, lancé en root |
| `2`  | Erreur d'usage : option inconnue, valeur manquante, dépôt introuvable                                            |
| `3`  | Conversion faite et `master` publiée, mais `main` n'a pas pu être supprimée sur le remote                        |

Répondre `N` à la confirmation n'est pas une erreur : le script affiche « Annulé. » et sort avec 0.

---

## Section développeur

### Architecture interne

```
main
├─ check_not_root   →  refuse root (Tier 3)
├─ parse_args       →  options, dépôt cible
├─ resolve_repo     →  racine du dépôt, refus d'un dépôt nu
├─ check_clean      →  opération en cours + git status --porcelain
├─ check_branches   →  main présente, master absente (ou « déjà converti » → exit 0)
├─ check_remote     →  ls-remote, absence de master distante, main distante ⊆ main locale
├─ show_plan / confirm
├─ convert          →  push main:master → branch -m → retarget_upstreams → set-head → delete_remote_main
└─ report           →  récapitulatif, commandes pour les autres clones ; exit 3 si PARTIAL
```

`g()` encapsule `git -C "$REPO_ROOT"` et `run()` exécute ou, en `--dry-run`, affiche la commande : toute commande modifiante passe par `run`.

---

### Détail des choix techniques

**Remote d'abord, renommage local ensuite**
Le push `refs/heads/main:refs/heads/master` se fait avant `git branch -m`. Si le serveur refuse (droits, branche protégée), rien n'a changé en local : pas de retour arrière à écrire.

**Publier `main:master` plutôt que renommer puis pousser**
Le refspec explicite ne dépend pas de l'état local et ne crée pas d'état intermédiaire où la branche locale s'appelle `master` sans équivalent distant.

**`ls-remote` puis `fetch` + `merge-base --is-ancestor`**
`ls-remote` (lecture seule) détecte l'existence de `master`/`main` et échoue net si le remote est injoignable. Le `fetch` n'est fait que si `origin/main` existe, pour vérifier qu'elle ne contient aucun commit absent du local : sinon `master` serait publiée sans eux, puis `main` supprimée — perte de travail. Un local en avance est accepté, le push de `master` les emporte.

**Comparaison exacte des noms dans `ls-remote`**
`git ls-remote --heads origin main` filtre par suffixe : `feature/main` serait trouvée. Le script teste donc `refs/heads/main` en entier.

**Fixer l'upstream explicitement**
`git branch -m` renomme la section de config, mais `master` suit toujours `origin/main`. `branch -u origin/master` est appliqué à `master`, puis à chaque branche locale dont l'upstream était `origin/main`.

**Bascule GitHub avant la suppression**
GitHub refuse de supprimer la branche par défaut. `gh repo edit OWNER/REPO --default-branch master` est tenté si l'URL contient `github.com` et si `gh auth status` réussit. Le `OWNER/REPO` est extrait de l'URL du remote (formats SSH et HTTPS) pour ne pas dépendre de la résolution de dépôt de `gh`. Un échec n'est pas fatal : il se traduit par un avertissement, puis par le code 3 si la suppression échoue.

**Code de retour 3 distinct de 1**
Quand la suppression de `main` échoue, le dépôt est déjà converti et `master` est publiée : ce n'est pas une panne, mais une étape manuelle restante. Le code 3 permet à un appelant (boucle sur plusieurs dépôts) de les distinguer.

**Confirmation exigée sans terminal : refus**
Supprimer une branche distante est irréversible côté serveur. Sans TTY et sans `--yes`, le script s'arrête au lieu de supposer l'accord.

---

### Dépendances externes

```
bash ≥ 4          →  [[ ]], substitution de processus, ${var/#motif/}
git ≥ 2.20        →  rev-parse --git-path, merge-base --is-ancestor, branch -u, remote set-head
gh (facultatif)   →  repo edit --default-branch, auth status
coreutils, sed, awk, grep
```

---

### Points d'extension

**Autre couple de branches**
Les noms sont des constantes en tête de script ; pour convertir dans l'autre sens, il suffit de les permuter :

```bash
readonly OLD_BRANCH="master"
readonly NEW_BRANCH="main"
```

**Autre forge (GitLab, Gitea…)**
Ajouter une fonction à côté de `set_github_default`, appelée depuis `delete_remote_main`, par exemple avec `glab repo edit --default-branch master`.

---

### Notes de maintenance

- **Ne gère pas** les pull requests ouvertes, les règles de protection de branche, les workflows CI ni les liens (README, badges) qui citent `main` : à revoir sur le serveur. Sur GitHub, supprimer une branche ferme les PR qui la ciblent.
- **Sous-modules** : un dépôt qui en contient est vérifié propre via `git status` (un sous-module modifié le rend « sale »). Un dépôt utilisé comme sous-module ailleurs doit voir sa référence de branche mise à jour dans le `.gitmodules` du parent.
- **Dépôts nus** : refusés, la procédure suppose un clone avec arbre de travail.
- **Simulation** : la liste des branches à re-suivre est lue dans l'état actuel du dépôt, donc `--dry-run` cite aussi la branche `main` (qui sera `master` en réel).
- **Autres clones** : non traités, voir les quatre commandes affichées en fin d'exécution.
