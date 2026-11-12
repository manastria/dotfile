# git-update-submodule

> Script : [`.local/bin/git-update-submodule`](../.local/bin/git-update-submodule)
> Guide associé : [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`git update-submodule` (le script `git-update-submodule`) gère les submodules d'un dépôt git, **y compris le dépôt yadm** via `--yadm`. `git update-submodule <chemin> <tag>` épingle un submodule sur un **tag** choisi et crée **un seul** commit `Mise à jour de <nom> vers <tag>` ; `sync` remet les submodules sur les commits **déjà épinglés** par le dépôt (le réflexe après un `pull` ou un changement de branche) ; `status` reprend `git submodule status` en y ajoutant l'URL de `origin`. Il ne suit **pas** la dernière version upstream : c'est `git submodule update --remote`. `--yadm` positionne `GIT_DIR` et `GIT_WORK_TREE` ; ensuite tout fonctionne comme sur n'importe quel dépôt, et `yadm update-submodule …` ou `yadm-update-submodule …` s'en chargent sans taper l'option. `-n` fait de `sync` un simple diagnostic.

---

## Section utilisateur

### Description

Fait passer un submodule d'une version à une autre **en choisissant le tag**, puis enregistre ce choix dans le dépôt parent par un commit. Trois opérations voisines à ne pas confondre :

| Besoin | Outil |
| ------ | ----- |
| Mettre un clone au commit **déjà épinglé** par le dépôt (après un `pull`) | `git update-submodule sync` (dépôt yadm : [`yadm-update-submodule sync`](yadm-update-submodule.md), ou l'alias [`yadm-check-submodules.sh`](yadm-check-submodules.md)) |
| Passer à la **dernière** version upstream d'une branche | `git submodule update --remote` (voir [le guide](mise-a-jour-submodules-zsh.md)) |
| Passer à **un tag précis** et le commiter | `git update-submodule <chemin> <tag>` |

Le fichier s'appelle `git-update-submodule` et se trouve dans `~/.local/bin`, présent dans le `PATH` : git le trouve donc comme sous-commande `git update-submodule`.

La sous-commande `status` complète `git submodule status` : mêmes lignes, plus l'URL du remote `origin` du submodule, celui qui sert à récupérer les tags. Utile pour savoir *d'où* viendra une mise à jour avant de la lancer.

La sous-commande `sync` remet les submodules au commit épinglé : elle ne fait rien quand tout est en place, liste les submodules fautifs sinon (`-` non initialisé, `+` commit différent), puis lance `git submodule update --init --recursive`. Un conflit de fusion (`U`) l'arrête. `-n` se contente du diagnostic. C'est la réponse à « pourquoi mon dépôt est sale après un changement de branche » : git ne répercute pas un `checkout` ou un `pull` sur les submodules.

**Dépôt yadm.** yadm est un dépôt git comme les autres, dont le répertoire git est simplement séparé de l'arbre de travail (`$HOME`). `--yadm` positionne `GIT_DIR=$YADM_REPO` et `GIT_WORK_TREE=$HOME` ; toutes les formes (`<chemin> <tag>`, `status`, `sync`) marchent ensuite à l'identique, depuis n'importe quel répertoire. Via `yadm update-submodule …`, yadm a déjà positionné ces variables : `--yadm` est inutile.

Garde-fous de la mise à jour — le script s'arrête, sans rien modifier, dans ces cas :

- le chemin n'est pas **exactement** un submodule déclaré dans `.gitmodules` (la liste des chemins valides est alors affichée) ;
- le dépôt parent a déjà des changements **indexés** : ils se retrouveraient dans le commit ;
- le HEAD du dépôt parent est détaché : le commit ne serait sur aucune branche ;
- le submodule a des fichiers suivis modifiés ;
- le nom de tag est invalide, ou le tag n'existe pas sur `origin`.

Quand le submodule est déjà enregistré sur ce tag, rien n'est committé et le code de retour reste 0.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `git` | toutes les opérations | `git --version` |
| `realpath` (coreutils) | normalise le chemin saisi | `realpath --version` |
| accès réseau | `fetch` des tags (inutile pour `status`) | `git ls-remote --tags https://github.com/sindresorhus/pure.git` |
| dépôt git | le script lit `.gitmodules` à la racine | `git rev-parse --show-toplevel` |
| dépôt yadm | uniquement avec `--yadm` | `ls -d ~/.local/share/yadm/repo.git` |

Le script refuse de tourner en **root** (voir *Détail des choix techniques*).

### Syntaxe

```bash
git update-submodule [--yadm] <chemin> <tag>
git update-submodule [--yadm] status [<chemin>...]
git update-submodule [--yadm] sync [-n]
git update-submodule -h | --help
```

| Argument / option | Défaut | Description |
| ----------------- | ------ | ----------- |
| `<chemin>` | — | Submodule, relatif au **répertoire courant** (l'autocomplétion convient, `/` final accepté). Doit correspondre exactement à un `path` de `.gitmodules` |
| `<tag>` | — | Nom du tag à récupérer sur `origin` |
| `status [<chemin>...]` | tous les submodules | Équivalent de `git submodule status` + URL du remote |
| `sync` | — | Remet les submodules au commit épinglé (`submodule update --init --recursive` si nécessaire) |
| `--yadm` | désactivé | Opère sur le dépôt yadm (`GIT_DIR=$YADM_REPO`, `GIT_WORK_TREE=$HOME`) |
| `-n`, `--dry-run` | désactivé | `sync` uniquement : signale les écarts sans rien modifier |
| `-h`, `--help` | — | Affiche l'en-tête du script |

| Variable d'environnement | Défaut | Description |
| ------------------------ | ------ | ----------- |
| `YADM_REPO` | `~/.local/share/yadm/repo.git` | Dépôt yadm utilisé par `--yadm` (les anciennes versions de yadm utilisaient `~/.config/yadm/repo.git`) |

Un submodule qui s'appellerait `status` ou `sync` s'écrit `./status`, pour ne pas être pris pour la sous-commande.

Préfixes affichés par `status` (ceux de `git submodule status`) :

| Préfixe | Signification |
| ------- | ------------- |
| ` ` (espace) | au commit enregistré par le parent |
| `-` | non initialisé |
| `+` | commit local différent de celui enregistré |
| `U` | conflit de fusion |

À droite, `url=` donne l'URL de `origin`. Si elle diffère de celle de `.gitmodules`, cette dernière est ajoutée entre parenthèses. Les identifiants contenus dans une URL (`https://jeton@hôte`, `utilisateur:mdp@`) sont remplacés par `***`.

### Exemples d'utilisation

```bash
# État des submodules, avec l'URL d'où viendront les tags
git update-submodule status

# Un seul submodule
git update-submodule status .zsh/custom/plugins/pure

# Épingler pure sur la version v1.23.0 (depuis n'importe où dans le dépôt)
git update-submodule .zsh/custom/plugins/pure v1.23.0

# Depuis un sous-répertoire : le chemin est relatif à l'endroit où l'on se trouve
cd .zsh/custom/plugins && git update-submodule pure/ v1.23.0

# Remettre les submodules sur les commits épinglés (après un pull / un changement de branche)
git update-submodule sync
git update-submodule sync -n          # diagnostic seul

# Même chose sur le dépôt yadm, depuis n'importe quel répertoire
git update-submodule --yadm sync
yadm update-submodule sync            # équivalent, yadm positionne GIT_DIR
yadm-update-submodule sync            # équivalent, wrapper sans --yadm
```

Sortie de `status` (extrait réel : copie de développement où seuls `pure` et `powerlevel10k` sont initialisés) :

```text
 cac55d0b531a0db72294c9bba9453dfa6374c59d .zsh/custom/plugins/pure (v1.28.4)  url=https://github.com/sindresorhus/pure.git
-85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5 .zsh/custom/plugins/zsh-autosuggestions  url=https://github.com/zsh-users/zsh-autosuggestions
-e07f6fb780725e9c0f50a7666700cf91ded30222 .zsh/custom/plugins/zsh-completions  url=https://github.com/zsh-users/zsh-completions
 35833ea15f14b71dbcebc7e54c104d8d56ca5268 .zsh/custom/themes/powerlevel10k (v1.20.0)  url=https://github.com/romkatv/powerlevel10k.git
-f8022980a3423f25e3d5e1b6a60d2372a2ba006b .zsh/oh-my-zsh  url=https://github.com/ohmyzsh/ohmyzsh.git
```

Sortie de `sync` quand un submodule a dérivé (ici `pure` laissé sur un commit plus ancien) :

```text
[INFO]      Vérification de l'état des submodules...
[ATTENTION] Mise à jour des submodules requise :
[ATTENTION]   +e74c483f99625cf462c9afa3c6a6f6eaeed53dcd .zsh/custom/plugins/pure (v1.28.3-14-ge74c483)
[INFO]      Téléchargement et mise à jour en cours...
Chemin de sous-module '.zsh/custom/plugins/pure' : 'cac55d0b531a0db72294c9bba9453dfa6374c59d' extrait
[OK]        Submodules synchronisés.
```

Quand tout est en place : `[OK]        Tous les submodules sont déjà à jour.`

Mise à jour réelle de `pure` (submodule non encore initialisé ; chemins du dépôt raccourcis) :

```text
[INFO]      Initialisation du submodule « .zsh/custom/plugins/pure »...
Submodule '.zsh/custom/plugins/pure' (https://github.com/sindresorhus/pure.git) registered for path '.zsh/custom/plugins/pure'
Cloning into '…/.zsh/custom/plugins/pure'...
Submodule path '.zsh/custom/plugins/pure': checked out 'cac55d0b531a0db72294c9bba9453dfa6374c59d'
[INFO]      Récupération des tags depuis https://github.com/sindresorhus/pure.git...
[OK]        « .zsh/custom/plugins/pure » : cac55d0 → a02209d (v1.23.0), commit 9fe8f02 créé.
```

Le commit créé s'appelle `Mise à jour de pure vers v1.23.0` et ne contient que `.zsh/custom/plugins/pure`. Relancée à l'identique, la commande répond :

```text
[INFO]      Récupération des tags depuis https://github.com/sindresorhus/pure.git...
[OK]        « .zsh/custom/plugins/pure » est déjà enregistré sur v1.23.0 (a02209d) : rien à committer.
```

Refus — un répertoire parent n'est pas un submodule :

```text
[ERREUR]    « .zsh/custom/plugins » n'est pas un submodule déclaré dans .gitmodules.
[INFO]      Submodules disponibles (chemins relatifs à la racine du dépôt) :
  .zsh/custom/plugins/zsh-autosuggestions
  .zsh/custom/plugins/zsh-completions
  …
```

Refus — un fichier est déjà indexé dans le parent :

```text
[ERREUR]    Le dépôt parent a déjà des changements indexés (« git status ») : commitez-les ou retirez-les de l'index (« git restore --staged ») avant de continuer.
```

Refus — tag inexistant :

```text
[INFO]      Récupération des tags depuis https://github.com/sindresorhus/pure.git...
[ERREUR]    Le tag « v9.9.9 » n'existe pas sur https://github.com/sindresorhus/pure.git.
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Succès, submodule déjà enregistré sur ce tag (rien à committer), ou submodules déjà synchronisés |
| 1 | Erreur d'exécution : hors dépôt git, dépôt yadm introuvable (`--yadm`), submodule invalide, dépôt parent dans un état refusé, tag introuvable, conflit de fusion (`sync`), échec de `git`, lancement en root |
| 2 | Erreur d'usage : option inconnue, nombre d'arguments incorrect, `-n` hors de `sync` |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — `-h`, `--yadm`, `-n`, puis détection des mots-clés `status` et `sync`, sinon exactement deux arguments (`<chemin> <tag>`).
2. `check_root`, `check_deps` — refus du root, présence de `git` et `realpath`.
3. `setup_yadm` — avec `--yadm` seulement : exporte `GIT_DIR` et `GIT_WORK_TREE`.
4. `locate_repo` — `TOP` = `git rev-parse --show-toplevel` (avec `GIT_WORK_TREE`, c'est `$HOME`, quel que soit le répertoire courant).
5. `load_declared` — lit `nom<TAB>chemin` de chaque submodule de `.gitmodules` dans `DECLARED`.
6. `cmd_status`, `cmd_update` **ou** `cmd_sync`.

`cmd_sync` : `git submodule status --recursive` capturé dans une variable, arrêt sur `U`, retour si aucun `-`/`+`, affichage des fautifs, puis (hors `-n`) `git submodule update --init --recursive`.

`cmd_update` enchaîne : `to_repo_relative` → `git check-ref-format` → `require_submodule` → `check_parent_ready` → `ensure_initialized` → `fetch --tags origin` → `rev-parse refs/tags/<tag>^{commit}` → `checkout --detach <sha>` → `add` → `diff --cached --quiet` (rien à committer ?) → `commit -- <chemin>`.

`cmd_status` : `git submodule status`, puis, pour chaque ligne, extraction du chemin, recherche du nom de configuration (`submodule_name_for`), `remote_url_for`, `mask_url`.

Deux assistants encapsulent `git -C` : `repo_git` (dépôt parent) et `sub_git <chemin>` (submodule, avec `env -u GIT_DIR -u GIT_WORK_TREE`, voir plus bas).

### Détail des choix techniques

Les trois premiers points sont des défauts de la version initiale, **reproduits** sur un dépôt jetable avant la réécriture.

**Chemin comparé exactement à `.gitmodules`.** L'ancien test `grep -q "$SUB_PATH"` cherchait une *sous-chaîne* (et le `.` était un joker). `vendor` passait donc pour valide alors que le submodule est `vendor/lib`. Le pire vient ensuite : `git -C vendor …` s'exécute dans un répertoire qui n'est pas la racine d'un dépôt, et git remonte alors au dépôt **parent**. Avec un tag homonyme dans le parent, le script a basculé le parent en tête détachée et y a créé un commit parasite. Le chemin est maintenant normalisé (`realpath -m`), comparé en égalité stricte aux `path` de `.gitmodules`, et vérifié comme *gitlink* (mode `160000`) dans l'index.

**Garde-fou `rev-parse --show-toplevel` après l'initialisation.** Même piège, autre porte d'entrée : si `submodule update --init` ne peuple pas le répertoire, la suite agirait sur le parent. `ensure_initialized` exige que la racine git du chemin soit le chemin lui-même.

**Index du parent vide exigé, et `commit -- <chemin>`.** L'ancien script faisait `git add` puis `git commit -m` : tout ce qui était déjà indexé entrait dans le commit « Mise à jour de … ». Le refus intervient *avant* toute modification du submodule, pour ne pas laisser un état à moitié fait. Le `-- <chemin>` du commit est une seconde protection, au cas où l'index changerait entre-temps.

**« Succès » seulement si c'est vrai.** L'ancien script affichait toujours son message de succès, même quand `git commit` répondait `nothing to commit`, et ne testait aucun code de retour. Le script détecte maintenant l'absence de changement (`diff --cached --quiet`) et vérifie le commit.

**`refs/tags/` et SHA du commit.** `git checkout v2.0` choisit une **branche** `v2.0` si elle existe (vérifié : l'ancien script basculait alors sur la branche). Le tag est résolu en `refs/tags/<tag>^{commit}`, puis le checkout se fait sur ce SHA, en tête détachée (voulue : un tag n'est pas une branche).

**`submodule update --init` seulement si le répertoire n'est pas initialisé.** `git submodule update` remet le submodule sur le commit enregistré par le parent ; sur un submodule déjà initialisé mais décalé, ce serait écraser sans prévenir la position courante.

**`fetch --tags origin`, sans `--depth`.** Les submodules sont en `shallow = true` (sauf `pure`). Sur une fixture de 30 commits, `fetch --tags` n'élargit pas le clone superficiel : il reste superficiel après la mise à jour. `origin` est nommé explicitement parce que `status` affiche l'URL de ce même remote : ce qui est affiché est ce qui sera interrogé. Un tag déplacé en amont est refusé par git (« would clobber existing tag ») : le message d'erreur le suggère.

**`sub_git` retire `GIT_DIR` et `GIT_WORK_TREE`.** Sous yadm, git exporte ces deux variables vers la sous-commande : `git -C <submodule> …` les hérite et travaille alors sur le dépôt **parent** au lieu du submodule. Constaté : `status` affichait pour `pure` l'URL du dépôt yadm, et `<chemin> <tag>` aurait fait son `fetch`, son `checkout --detach` et son `rev-parse HEAD` sur le dépôt yadm. Les commandes sur le parent (`repo_git`) gardent les variables, c'est voulu. `git submodule update` n'a pas ce souci : git-submodule les retire lui-même pour ses sous-processus.

**`--yadm` = deux variables d'environnement, rien d'autre.** yadm n'est pas un cas particulier : c'est un dépôt dont le répertoire git est hors de l'arbre de travail. Une fois `GIT_DIR` / `GIT_WORK_TREE` positionnés, `git rev-parse --show-toplevel` renvoie `$HOME` même depuis `/tmp`, et `git -C "$TOP"` place le répertoire courant dans l'arbre de travail, ce que `git-submodule` exige (c'était l'objet du `cd "$HOME"` de l'ancien `yadm-check-submodules.sh`). Aucune branche de code `if yadm` : la même logique sert tous les dépôts. `yadm update-submodule` fonctionne sans `--yadm` parce que yadm lance `git --git-dir … --work-tree …`, et que git exporte les deux variables à la sous-commande.

**`sync` ne tire jamais l'upstream.** Pas de `--remote` : le script ne doit pas pouvoir déplacer un commit épinglé sans commit associé. `-n` est refusé hors de `sync` (code 2) : sur les autres formes il serait silencieusement ignoré, et on croirait à une simulation alors que le script commite.

**Pas de pipe dans un `if` pour `sync`.** `if git submodule status | grep -q …` masque l'échec de git (le code de retour est celui de `grep`) et affichait « tous à jour » juste après un `fatal:`. La sortie est capturée avec `|| die`, dans une affectation distincte de `local`.

**Aucune modification du répertoire courant.** Tout passe par `git -C`. Les chemins saisis restent donc relatifs à l'endroit où l'on se trouve, ce qui permet l'autocomplétion depuis un sous-répertoire.

**Nom de configuration ≠ chemin.** Les clés sont `submodule.<nom>.url`, le nom pouvant différer du chemin. `load_declared` lit `.gitmodules` avec `-z` (séparateur NUL : sûr avec des espaces dans un chemin) et mémorise les couples nom/chemin.

**Origine de l'URL dans `status`.** Dans l'ordre : le `origin` du submodule lui-même (c'est lui que `fetch` interroge), puis `submodule.<nom>.url` dans la configuration du parent (renseignée par `submodule init`), puis `.gitmodules`. Pour un submodule non initialisé, seules les deux dernières sources existent. Quand `origin` et `.gitmodules` divergent, l'écart est affiché : un `fetch` irait chercher les tags ailleurs que prévu.

**Masquage des identifiants.** Une URL `https://jeton@github.com/…` est un secret courant ; `status` finit dans un terminal partagé ou un log. `https` : tout identifiant est masqué. Autres schémas : seul un mot de passe l'est (`ssh://git@hôte` n'est pas un secret et reste lisible).

**Refus du root (Tier 3 de CLAUDE.md).** Lancé en root, git créerait des objets appartenant à root dans le dépôt et dans `.git/modules` de l'utilisateur.

**Code 2 pour l'usage.** La version initiale renvoyait 1 pour un mauvais nombre d'arguments ; l'usage passe à 2, comme `yadm-check-submodules.sh`, pour distinguer une erreur d'appel d'une erreur d'exécution.

**Pas de retour arrière automatique.** Si le commit échoue (hook `pre-commit`, identité git absente…), le submodule reste sur le tag et indexé. Le message affiche les deux commandes : réessayer, ou annuler en remettant l'ancien commit (`git restore --staged` + `git -C <chemin> checkout --detach <ancien>`). Un rollback automatique aurait pu interférer avec un hook interactif.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `git` | 2.7 | `git remote get-url` (lecture de l'URL) ; `git restore --staged`, cité dans le conseil d'annulation, demande 2.23. Testé avec 2.43 |
| `realpath` (coreutils) | — | option `-m` : chemin dont les éléments peuvent ne pas exister |
| `sed` | — | `-E` (regex étendues) pour `mask_url` |
| `awk` | — | extraction de l'aide depuis l'en-tête |
| `bash` | — | testé avec 5.x ; les tableaux vides sont protégés contre `set -u` pour les bash < 4.4 |

### Points d'extension

**Mettre à jour sans committer** — remplacer la fin de `cmd_update` après le `repo_git add` par un simple message, derrière une option `--no-commit` à ajouter dans `parse_args` :

```bash
if [ "$NO_COMMIT" = "yes" ]; then
    success "« ${rel} » sur ${tag}, indexé ; commit laissé à votre charge."
    return 0
fi
```

**Autre remote que `origin`** — `REMOTE` est une constante en tête de script ; en faire une option (`--remote`) suffit, `status` et `fetch` la lisent tous deux.

**Format du message de commit** — une seule ligne, dans `cmd_update` :

```bash
msg="Mise à jour de ${rel##*/} vers ${tag}"
```

**`status` récursif** — transmettre `--recursive` à `git submodule status` ne suffit pas : `load_declared` ne lit que le `.gitmodules` de la racine, il faudrait y ajouter ceux des submodules imbriqués.

### Notes de maintenance

- **Ne pas relâcher le refus d'un index non vide.** C'est lui qui garantit « un commit = un submodule ». Le `-- <chemin>` du commit n'est qu'un filet.
- **Limites connues** : les submodules imbriqués ne sont pas gérés ; `is_gitlink` compare le chemin tel que l'imprime `git ls-files`, donc un chemin contenant guillemets, barre oblique inverse ou caractère de contrôle (git les échappe) serait refusé à tort ; les chemins avec UTF-8 sont acceptés (`core.quotepath=off`).
- **`status` vaut aussi mot-clé réservé** : un submodule appelé `status` s'écrit `./status`.
- **Dépôt cible.** Sans `--yadm`, le script travaille sur le dépôt git du répertoire courant ; avec `--yadm` (ou via `yadm update-submodule`), sur le dépôt yadm. Le dépôt de développement (`projets/dotfile`) et le dépôt yadm de `$HOME` ont chacun leurs submodules, à resynchroniser séparément. Flux habituel : mise à jour dans le dépôt de développement, `git push`, puis `yadm pull` et `yadm-update-submodule sync` sur la machine cible (voir le guide associé, section D). `<chemin> <tag>` avec `--yadm` n'a pas été testé de bout en bout (il commite dans le dépôt yadm) ; `status` et `sync` l'ont été.
- **Deux copies du script.** `~/.local/bin` (déployé par yadm) et `<dépôt de dev>/.local/bin` sont deux fichiers distincts : pour tester une modification, mettre le second en tête du `PATH`, sinon on teste l'ancienne version.
- **`-n` est refusé hors de `sync`** par `parse_args` : le conserver si une nouvelle forme est ajoutée.
- **Tester sans toucher au vrai dépôt.** Les submodules locaux (`file://`) sont bloqués par défaut depuis git 2.38.1 ; il faut `protocol.file.allow=always`. Recette minimale, avec une configuration isolée pour ne pas utiliser `~/.gitconfig` :

  ```bash
  export GIT_CONFIG_GLOBAL=/chemin/gitconfig-test   # user.name, user.email, protocol.file.allow=always
  git init up && cd up                               # amont : quelques commits et tags (v1.0, v2.0…)
  # parent : git submodule add file:///…/up vendor/lib, shallow = true dans .gitmodules,
  # puis git clone --recurse-submodules du parent pour obtenir un clone superficiel
  ```

  Cas à rejouer après toute modification : chemin partiel (`vendor` au lieu de `vendor/lib`), fichier déjà indexé, tag déjà en place, HEAD détaché, submodule modifié, branche homonyme du tag, submodule non initialisé, `status` avec URL contenant un jeton.
