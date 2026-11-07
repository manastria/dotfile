# `git-check-sync.sh` — État de synchronisation des dépôts Git d'un répertoire

> Script : [`.local/bin/git-check-sync.sh`](../.local/bin/git-check-sync.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`git-check-sync.sh` fait l'état des lieux de tous les dépôts Git d'un répertoire de projets (`~/projets` par exemple) avant de quitter la machine : modifications non commitées, commits non poussés, retard sur le serveur, divergence ou historique réécrit côté distant. Après le tableau, il propose de lancer `git pull --rebase` sur les dépôts **uniquement** en retard et `git push` sur ceux qui ont **uniquement** des commits à pousser, après confirmation. Il ne commite rien, ne résout aucune divergence et ne sauvegarde rien : pour une copie sur clé USB, c'est `backup-projets.sh`. Au quotidien : `--hide ok,non-git` pour ne voir que ce qui demande attention, `-y` pour appliquer les mises à jour sans question, `-r` pour un rapport seul, et `-n` pour un scan rapide sans réseau.

---

## Section utilisateur

### Description

Le script parcourt chaque sous-dossier du répertoire indiqué (premier niveau seulement, dossiers cachés ignorés), fait un `git fetch origin` sur chaque dépôt, puis classe chaque dépôt par **constats** :

| Catégorie | Sévérité | Constat |
| --------- | -------- | ------- |
| `OK` | — | Arbre propre, à jour avec l'upstream |
| `NON-GIT` | attention | Dossier sans `.git` |
| `VIDE` | attention | Dépôt sans aucun commit |
| `MODIFS` | attention | Fichiers modifiés, indexés ou non suivis |
| `SANS-REMOTE` | attention | Pas de remote `origin` |
| `FETCH-KO` | attention | `git fetch` en échec (réseau, authentification, timeout) |
| `SANS-BRANCHE` | attention | HEAD détaché |
| `SANS-UPSTREAM` | attention | Branche courante sans branche suivie |
| `A-POUSSER` | attention | Commits locaux absents de l'upstream |
| `A-RECUPERER` | attention | Commits distants absents du local |
| `DIVERGENCE` | critique | Commits des deux côtés |
| `FORCE-PUSH` | critique | Historique distant réécrit depuis le dernier fetch |

Un dépôt peut cumuler plusieurs constats (`MODIFS` + `A-POUSSER`) ; la colonne STATUT n'affiche que le plus grave, le détail les énumère tous.

**Filtres.** `--hide` et `--only` prennent des listes de catégories :

- `--hide` masque un dépôt quand **tous** ses constats sont dans la liste. `--hide modifs` masque les dépôts simplement modifiés, mais garde un dépôt modifié *et* en avance : on ne veut pas perdre de vue des commits non poussés parce qu'on a choisi d'ignorer les brouillons.
- `--only` n'affiche que les dépôts ayant **au moins un** constat de la liste.

Les dépôts masqués ne comptent ni dans le code de retour, ni dans les mises à jour proposées.

**Mises à jour proposées.** Deux cas sont sans ambiguïté et proposés après le tableau :

- constat unique `A-RECUPERER` → `git pull --rebase` (aucun commit local, arbre propre : c'est une avance rapide) ;
- constat unique `A-POUSSER` → `git push` vers la branche suivie.

« Unique » est strict : un dépôt `MODIFS` + `A-POUSSER`, ou en `FETCH-KO`, n'est pas proposé. Dans un terminal, le script demande `[o]ui / [N]on / [i] un par un` pour chaque groupe ; sans terminal en entrée (cron, pipe), il n'applique rien et indique de relancer avec `--yes`.

Différences avec les scripts voisins :

- [`backup-projets.sh`](../.local/bin/backup-projets.sh) copie les projets sur une clé USB, sans réseau ; il ne fait ni fetch, ni pull, ni push. Les deux s'enchaînent bien.
- [`git-main-to-master.sh`](../.local/bin/git-main-to-master.sh) renomme une branche ; `git-check-sync.sh` ne touche à aucune branche en dehors du pull/push accepté.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4 | `${var^^}`, `printf -v`, tableaux | `bash --version` |
| `git` ≥ 2.20 | `rev-list --left-right --count`, `merge-base --is-ancestor`, `symbolic-ref --short` | `git --version` |
| `timeout` (coreutils, facultatif) | Borne chaque opération réseau | `command -v timeout` |
| `tput` (facultatif) | Largeur du terminal pour le filet du tableau | `tput cols` |

Accès réseau aux remotes, sauf en `--no-fetch`. Les authentifications doivent être déjà disponibles (agent SSH, credential helper) : le script n'en demande aucune.

---

### Syntaxe

```
git-check-sync.sh [-d DIR] [-n] [-t SEC] [-q] [-x CAT,...] [-o CAT,...]
                  [--hide-ok] [--hide-non-git] [-y | -r] [-h]
git-check-sync.sh [DIR]
```

| Option / argument | Argument | Défaut | Description |
| ----------------- | -------- | ------ | ----------- |
| `DIR`, `-d`, `--dir` | chemin | répertoire courant | Répertoire dont les sous-dossiers sont analysés |
| `-n`, `--no-fetch` | — | désactivé | Aucun fetch : état basé sur les branches de suivi connues |
| `-t`, `--timeout` | secondes | `20` | Délai maximal par opération réseau (fetch, pull, push) |
| `-q`, `--quiet` | — | désactivé | Pas de détail au fil de l'eau, seulement le tableau |
| `-x`, `--hide` | `CAT,...` | — | Masque les dépôts dont tous les constats sont listés |
| `-o`, `--only` | `CAT,...` | — | N'affiche que les dépôts ayant au moins un constat listé |
| `--hide-ok` | — | — | Raccourci de `--hide ok` |
| `--hide-non-git` | — | — | Raccourci de `--hide non-git` |
| `-y`, `--yes` | — | désactivé | Applique les mises à jour proposées sans demander |
| `-r`, `--report-only` | — | désactivé | Ne propose aucune mise à jour |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage |

Catégories : `ok`, `non-git`, `vide`, `modifs`, `sans-remote`, `fetch-ko`, `sans-branche`, `sans-upstream`, `force-push`, `divergence`, `a-pousser`, `a-recuperer`. Casse indifférente ; `--hide` et `--only` sont répétables et cumulatifs. Une catégorie inconnue est une erreur d'usage (code 2) plutôt qu'un filtre silencieusement inopérant. `--yes` et `--report-only` sont incompatibles.

---

### Exemples d'utilisation

```bash
# État des lieux complet du répertoire courant
cd ~/projets && git-check-sync.sh

# Seulement ce qui demande attention
git-check-sync.sh --hide ok,non-git ~/projets

# Ignorer aussi les simples brouillons (un dépôt modifié ET en avance reste affiché)
git-check-sync.sh -x ok,non-git,modifs ~/projets

# Avant de partir : tout pousser/récupérer ce qui peut l'être, sans question
git-check-sync.sh -y --hide-ok ~/projets

# Uniquement les dépôts à pousser
git-check-sync.sh -o a-pousser ~/projets

# Hors-ligne, rapport seul
git-check-sync.sh -n -r ~/projets

# Hook de fin de session
git-check-sync.sh -q -r ~/projets || echo "Des projets demandent attention"
```

**Exemple de sortie** (`git-check-sync.sh --hide-non-git -y ~/projets`) :

```
=== État de synchronisation Git ===
[INFO]      Répertoire : /home/user/projets
[INFO]      Masqués : NON-GIT

[ATTENTION] cours-bts   1 commit(s) distant(s) non récupéré(s)
[OK]        dotfile     à jour avec origin/master
[ATTENTION] notes       1 fichier(s) modifié(s)/non suivi(s), 1 commit(s) non poussé(s) sur origin/master
[CRITIQUE]  outils      divergence : 1 commit(s) local(aux), 1 distant(s)
[ATTENTION] site-perso  1 commit(s) non poussé(s) sur origin/master

=== RÉCAPITULATIF ===
PROJET      STATUT         DÉTAIL
--------------------------------------------------------------------------------
cours-bts   A-RECUPERER    1 commit(s) distant(s) non récupéré(s)
dotfile     OK             à jour avec origin/master
notes       MODIFS         1 fichier(s) modifié(s)/non suivi(s), 1 commit(s) non poussé(s) sur origin/master
outils      DIVERGENCE     divergence : 1 commit(s) local(aux), 1 distant(s)
site-perso  A-POUSSER      1 commit(s) non poussé(s) sur origin/master

=== MISES À JOUR POSSIBLES ===

[INFO]      Uniquement en retard — « git pull --rebase » possible sur 1 dépôt(s) :
                  - cours-bts : 1 commit(s) distant(s) non récupéré(s)
[OK]        cours-bts   mis à jour (git pull --rebase)

[INFO]      Uniquement des commits à pousser — « git push » possible sur 1 dépôt(s) :
                  - site-perso : 1 commit(s) non poussé(s) sur origin/master
[OK]        site-perso  poussé vers origin/master

[INFO]      1 dépôt(s) masqué(s) par les filtres.
[ATTENTION] 2 point(s) d'attention sur 5 dépôt(s) affiché(s).
```

`notes` (modifié et en avance) et `outils` (divergence) ne sont pas proposés : ils demandent une intervention manuelle. Sans `-y`, dans un terminal, chaque groupe est précédé de la question :

```
Lancer « git push » ? [o]ui / [N]on / [i] un par un :
```

Une mise à jour refusée par le serveur affiche la sortie de git sous la ligne du dépôt et laisse le dépôt en point d'attention.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Tous les dépôts **affichés** sont propres et synchronisés, après les mises à jour acceptées |
| `1` | Au moins un point d'attention parmi les dépôts affichés (y compris une mise à jour en échec) |
| `2` | Erreur d'usage : option ou catégorie inconnue, répertoire introuvable, `--yes` avec `--report-only` |

Le code se calcule **après** les mises à jour : un dépôt poussé avec succès compte comme `OK`. Les dépôts masqués par `--hide`/`--only` n'y entrent pas — avec `--only ok`, le code est donc 0 quoi qu'il arrive aux autres.

---

## Section développeur

### Architecture interne

```
main
├─ parse_args        →  options ; add_categories valide et normalise --hide/--only
├─ setup_git_env     →  GIT_TERMINAL_PROMPT=0, ssh BatchMode, détection de timeout(1)
├─ 1er passage       →  liste des sous-dossiers, largeur de la colonne PROJET
├─ boucle            →  check_repo → join_notes → R_* ; is_visible → print_live
│   └─ check_repo    →  .git ? → HEAD ? → status → origin ? → run_fetch → branche/upstream
│                       → détection force-push → ahead/behind
├─ print_table       →  lignes visibles uniquement
├─ propose_updates   →  éligibles (constat unique) → propose_group pull / push
│   └─ apply_action  →  run_git_net pull|push ; succès : R_* passés à OK
└─ bilan             →  code de retour sur les dépôts visibles
```

Les résultats sont accumulés dans des tableaux parallèles indexés par dépôt : `R_PATH`, `R_NAME`, `R_LABEL` (constat le plus grave), `R_COLOR`, `R_DETAIL`, `R_FLAGS` (tous les constats, séparés par des espaces) et `R_SHOWN` (`yes`/`no` selon les filtres).

---

### Détail des choix techniques

**Deux niveaux : libellé et constats**
`set_status` met à jour le libellé si la sévérité est strictement supérieure (le premier constat d'une sévérité l'emporte, donc l'ordre des tests fixe la priorité) **et** ajoute toujours le constat à `CUR_FLAGS`. Les filtres et l'éligibilité aux mises à jour travaillent sur `R_FLAGS` : filtrer sur le seul libellé masquerait un dépôt `MODIFS` + `A-POUSSER` avec `--hide modifs`, puisque son libellé est `MODIFS`.

**Sémantique « tous » pour `--hide`, « au moins un » pour `--only`**
C'est la combinaison qui ne fait jamais disparaître un problème qu'on n'a pas explicitement nommé.

**Ensembles en chaîne « ␣A␣B␣ »**
`HIDE_SET`, `ONLY_SET` et `CATEGORIES` sont des chaînes encadrées d'espaces : l'appartenance se teste par `[[ "$SET" == *" $f "* ]]`, sans tableau associatif ni boucle.

**Éligibilité stricte aux mises à jour**
Seuls les dépôts dont `R_FLAGS` vaut exactement `A-RECUPERER` ou `A-POUSSER` sont proposés. Un `git push` réussirait techniquement sur un dépôt modifié, mais le cas « commits + brouillons » mérite un regard avant de partir ; un `FETCH-KO` rend l'état distant douteux ; un `FORCE-PUSH` sans commit local est rattrapable par un pull mais signale un événement à comprendre d'abord.

**`git pull --rebase` sur un dépôt en retard seulement**
Sans commit local, le rebase se réduit à une avance rapide : aucune réécriture, aucun conflit. `--rebase` sur la ligne de commande prime sur `pull.ff = only` de la config du dépôt.

**`git push <remote> HEAD:<merge>` explicite**
Le push vise `branch.<b>.remote` / `branch.<b>.merge`, c'est-à-dire exactement l'upstream comparé pendant le scan. Un `git push` nu dépend de `push.default` et échoue (`simple`) si la branche locale ne porte pas le même nom que la distante.

**Code de retour après les actions**
Un dépôt mis à jour avec succès est repassé à `OK` dans `R_*` sans nouveau scan : son constat était unique, il n'y a plus rien à signaler, et un second fetch coûterait un aller-retour réseau par dépôt.

**`LC_ALL=C` limité au fetch**
La sortie du fetch est parsée (`forced update`), donc forcée en anglais ; l'`export` se fait dans la sous-shell de `$(…)` pour ne pas fuir. Les sorties de pull/push, seulement affichées en cas d'échec, gardent la locale de l'utilisateur.

**Confirmation sur l'entrée standard**
La question n'est posée que si `stdin` est un terminal (`-t 0`) ; `read -p` écrit l'invite sur `stderr`, donc une redirection `> rapport.txt` reste lisible. Sans terminal, rien n'est appliqué sans `--yes`.

**Non-interactif côté git**
`GIT_TERMINAL_PROMPT=0` et `ssh -o BatchMode=yes` (ajouté à un éventuel `GIT_SSH_COMMAND` existant) : un credential expiré fait échouer l'opération au lieu de bloquer le scan sur une invite.

**Détection du force-push**
`merge-base --is-ancestor HEAD @{u}` ne distingue pas un force-push d'une divergence ordinaire. Le script combine la mention `(forced update)` dans la sortie du fetch et le reflog de la branche de suivi : si `origin/x@{1}` n'est plus ancêtre de `origin/x`, le distant a été réécrit.

**`pad()` au lieu de `printf %-Ns`**
`printf` compte les octets ; un nom de projet accentué décalerait les colonnes. `${#s}` compte les caractères.

---

### Dépendances externes

```
bash ≥ 4        →  ${var^^}, printf -v, read -a, tableaux indexés
git ≥ 2.20      →  rev-list --left-right --count, merge-base --is-ancestor,
                   symbolic-ref --short, reflog des branches de suivi
timeout         →  coreutils, facultatif (sans lui, pas de borne réseau)
tput            →  ncurses, facultatif (repli à 100 colonnes)
awk, sed, wc, tr
```

---

### Points d'extension

**Nouvelle catégorie**
L'ajouter à `CATEGORIES` (sinon `--hide`/`--only` la refuseront), puis la lever dans `check_repo` :

```bash
readonly CATEGORIES=" OK NON-GIT … A-RECUPERER STASH "

# dans check_repo, après le test du working tree
if [[ -n "$(git -C "$dir" stash list 2>/dev/null)" ]]; then
    set_status 1 "$YELLOW" "STASH"
    CUR_NOTES+=("stash non vide")
fi
```

**Nouvelle action proposée**
Ajouter un cas dans `propose_updates` et une branche dans `apply_action`, par exemple pousser malgré des modifications locales :

```bash
case "${R_FLAGS[$i]}" in
    A-RECUPERER)        pulls+=("$i") ;;
    A-POUSSER|"MODIFS A-POUSSER") pushes+=("$i") ;;
esac
```

L'ordre des constats dans `R_FLAGS` suit l'ordre des tests de `check_repo` (`MODIFS` avant `A-POUSSER`).

**Autre remote que `origin`**
Constante `REMOTE_NAME` en tête de script ; elle ne sert qu'à la présence du remote et au fetch, la comparaison se faisant toujours contre `@{u}`.

---

### Notes de maintenance

- **Ancien nom** : le script s'appelait `check-git-sync.sh`. Le renommage aligne le nom sur le préfixe `git-` des scripts Git ; une copie déployée par yadm peut encore exister sous l'ancien nom jusqu'au prochain `yadm pull`.
- **Branche courante seulement** : seule la branche sur laquelle est HEAD est comparée ; une autre branche locale non poussée passe inaperçue.
- **Pas de récursion** : seuls les sous-dossiers directs sont analysés, les dossiers cachés sont ignorés (glob `*/`).
- **`--timeout` s'applique aussi au push** : un gros push sur une liaison lente peut être coupé à 20 s. Un push interrompu n'abîme rien (la ref distante n'est mise à jour qu'en fin de transfert), mais il faut relancer avec un `-t` plus grand.
- **`--no-fetch` et actions** : le pull et le push acceptés contactent le remote malgré `-n` ; l'état sur lequel la proposition est fondée peut alors être périmé (un push refusé en non fast-forward en est le symptôme, sans dommage).
- **Largeur de colonne** : calculée sur tous les sous-dossiers, masqués compris, car l'affichage au fil de l'eau commence avant que les constats soient connus.
- **Délai entre scan et action** : l'état n'est pas revérifié juste avant le pull/push ; si un dépôt a été modifié pendant la question, git lui-même refusera (`pull --rebase` sur arbre sale, push non fast-forward).
