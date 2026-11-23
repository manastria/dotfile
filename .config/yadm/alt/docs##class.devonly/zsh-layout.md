# `zsh-layout` — Session tmux décrite par un fichier de disposition

> Script : [`.local/bin/zsh-layout`](../.local/bin/zsh-layout)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`zsh-layout -l NOM` ouvre une session tmux dont chaque fenêtre démarre dans son propre répertoire, d'après le fichier `~/.config/zsh-layouts/NOM.conf` (une ligne `numéro|nom|répertoire` par fenêtre). Il ne remplace pas `zsh-daily`, qui ouvre la session `main` dans le répertoire courant sans rien préparer. Si la session existe déjà, elle est **reprise telle quelle**, et depuis l'intérieur de tmux le script bascule vers la session au lieu d'imbriquer un second tmux. Au quotidien on passe par les alias `zsh-projets` (une fenêtre dans `~/projets`) et `zsh-cours` (deux fenêtres, dont `~/projets/cours_astro`). Les options utiles sont `-p` (profil zsh), `-D` (détacher un autre terminal resté connecté) et `-n` (préparer la session sans s'y rattacher).

---

## Section utilisateur

### Description

`zsh-layout` construit une session tmux à partir d'une **disposition** : un fichier qui liste les fenêtres, chacune avec un numéro, un nom et un répertoire de départ. Il remplace les anciens scripts `zsh-cours` et `zsh-projets`, qui ne différaient que par ce tableau.

Dispositions fournies (dans `~/.config/zsh-layouts/`) :

| Disposition | Alias         | Session   | Fenêtres                                          |
| ----------- | ------------- | --------- | ------------------------------------------------- |
| `projets`   | `zsh-projets` | `projets` | 1 `projets` → `~/projets`                         |
| `cours`     | `zsh-cours`   | `cours`   | 1 `projets` → `~/projets`, 2 `astro` → `~/projets/cours_astro` |

La première fenêtre du fichier est celle affichée à l'arrivée dans la session.

Il se distingue de ses voisins :

| Commande       | Session                | Répertoire des fenêtres          | Fenêtres préparées |
| -------------- | ---------------------- | -------------------------------- | ------------------ |
| `zsh-daily`    | `main`                 | celui où on lance la commande    | non                |
| `zsh-layout`   | nom de la disposition  | fixé par le fichier, par fenêtre | oui                |

`zsh-daily` est un alias de `zenv`, une **fonction** du shell interactif (`.shellrc/rc.d/zenv.sh`). `zsh-layout` est un **script** : il ne peut pas appeler `zenv` et refait donc lui-même ce dont il a besoin (profil, création ou reprise, bascule depuis tmux). Les alias `zsh-projets` et `zsh-cours` sont définis dans le même fichier `zenv.sh`, mais ils appellent `zsh-layout`, pas `zenv`.

#### Format d'un fichier de disposition

```
# ~/.config/zsh-layouts/cours.conf
1|projets|~/projets
2|astro|~/projets/cours_astro
```

- Une ligne par fenêtre : `numéro|nom|répertoire`.
- Les lignes vides et celles qui commencent par `#` sont ignorées.
- Un `~` ou `~/` initial est remplacé par `$HOME` ; rien d'autre n'est développé (ni `$VAR`, ni commande).
- Le nom et le répertoire ne doivent pas contenir `|`. Les numéros doivent être uniques.

---

### Prérequis

| Outil        | Rôle                                                              | Vérification     |
| ------------ | ----------------------------------------------------------------- | ---------------- |
| `bash` ≥ 4   | Interpréteur (tableau `WINDOWS`)                                  | `bash --version` |
| `tmux` ≥ 3.2 | Profil transmis par `-e` à un serveur déjà lancé (voir plus bas)  | `tmux -V`        |
| `zsh`        | Shell lancé dans les fenêtres (`default-shell` de `.tmux.conf`)   | `zsh --version`  |

Le fichier `~/.config/zsh-layouts/NOM.conf` et tous les répertoires qu'il cite doivent exister : le script s'arrête sinon, avant de créer quoi que ce soit. `~/.config` est remplacé par `$XDG_CONFIG_HOME` s'il est défini. Aucun droit administrateur n'est requis.

---

### Syntaxe

```
zsh-layout -l DISPOSITION [-p PROFIL] [-s SESSION] [-D] [-n]
zsh-layout -h | --help
```

| Option              | Argument     | Défaut                   | Description                                                        |
| ------------------- | ------------ | ------------------------ | ------------------------------------------------------------------ |
| `-l`, `--layout`    | disposition  | — (obligatoire)          | Fichier `~/.config/zsh-layouts/NOM.conf` à ouvrir (lettres, chiffres, `_` et `-`) |
| `-p`, `--profile`   | profil       | `simple`                 | Profil zsh des fenêtres (`ZSH_PROFILE`) : mêmes valeurs que `zenv` |
| `-s`, `--session`   | nom          | nom de la disposition    | Nom de la session tmux (lettres, chiffres, `_` et `-`)             |
| `-D`, `--detach`    | —            | désactivé                | Détache d'abord les autres clients attachés à la session           |
| `-n`, `--no-attach` | —            | désactivé                | Crée la session sans s'y rattacher                                 |
| `-h`, `--help`      | —            | —                        | Affiche l'en-tête manpage du script                                |

---

### Exemples d'utilisation

```bash
# Ouvrir (ou reprendre) la session de cours, via l'alias
zsh-cours

# Même chose sans alias
zsh-layout --layout cours

# Autre profil zsh (oh-my-zsh sans powerlevel10k)
zsh-projets -p omz

# Préparer la session en arrière-plan, s'y rattacher plus tard
zsh-cours --no-attach
tmux attach -t cours

# Reprendre une session restée ouverte dans un autre terminal
zsh-cours -D

# Deuxième exemplaire de la même disposition, sous un autre nom de session
zsh-projets -s projets-bis
```

**Exemple de sortie** (première exécution, avec `--no-attach`) :

```
[OK]        Session 'cours' créée (disposition cours, 2 fenêtre(s), profil simple).
```

Relancée, la même commande répond :

```
[INFO]      Session 'cours' déjà ouverte : reprise telle quelle.
```

Dans la session, `tmux list-windows` donne :

```
1: projets* (1 panes) [80x24] [layout b25d,80x24,0,0,0] @0 (active)
2: astro- (1 panes) [80x24] [layout b25e,80x24,0,0,1] @1
```

Disposition inconnue (la liste des fichiers présents est donnée) :

```
[ERREUR]    Disposition 'nope' introuvable : /home/…/.config/zsh-layouts/nope.conf (disponibles : cours projets).
```

---

### Codes de retour

| Code | Signification                                                                                                                  |
| ---- | ------------------------------------------------------------------------------------------------------------------------------ |
| `0`  | Session créée ou reprise, puis quittée normalement                                                                             |
| `1`  | Erreur d'exécution : `tmux` absent, disposition introuvable ou mal formée, répertoire introuvable, profil inconnu, échec de `tmux` |
| `2`  | Erreur d'usage : option inconnue, valeur manquante, disposition absente, nom de disposition, de profil ou de session invalide  |

---

## Section développeur

### Architecture interne

```
parse_args          →  options ; validation des noms de disposition, de profil, de session
check_prerequisites →  tmux présent, profil existant
main                →  has-session ? reprise : load_layout, check_directories, create_session
load_layout         →  lit NOM.conf dans le tableau WINDOWS, ligne par ligne, en validant
check_directories   →  chaque répertoire de WINDOWS existe
create_session      →  new-session -d (première fenêtre) puis new-window par entrée suivante,
                       renumérotation, select-window ; rollback_die en cas d'échec
attach_session      →  switch-client (depuis tmux) ou exec attach-session
```

---

### Détail des choix techniques

**Un script plutôt qu'une fonction**
`zenv` est une fonction de `.shellrc/rc.d/zenv.sh`, chargée dans le shell interactif ; un script lancé dans un sous-processus ne la voit pas. Le test de version de tmux (`tmux_has_env_flag`) et la logique « session existante → reprise, depuis tmux → bascule » sont donc **recopiés** de `zenv.sh` : une correction faite dans l'un est à reporter dans l'autre.

**Un script indépendant plutôt qu'une option de `zenv`**
Intégrer les dispositions à `zenv` obligerait à y porter la renumérotation et le rollback, dans une fonction partagée avec bash et déjà chargée à chaque shell. Un script séparé reste testable seul, et `zenv` n'est pas touché.

**Fichiers `.conf` plutôt que des tableaux dans le script**
Ajouter une disposition ne demande plus de copier le script (c'était le cas de `zsh-cours` et `zsh-projets`) : un fichier de deux lignes et un alias suffisent. Les fichiers sont versionnés avec les dotfiles dans `.config/zsh-layouts/`.

**Nom de la disposition restreint à `[A-Za-z0-9_-]`**
Il sert à fabriquer le chemin du fichier : cette restriction exclut `/` et `..` et empêche de sortir de `~/.config/zsh-layouts/`.

**Le fichier n'est lu que si la session n'existe pas**
Une session existante est reprise telle quelle, donc `load_layout` n'est pas appelé. Un fichier devenu invalide ne gêne pas la reprise, et le profil et les fenêtres d'origine sont conservés.

**Validation complète avant de toucher à tmux**
`load_layout` rejette les numéros non entiers ou en double, les champs vides et le `|` en trop, puis `check_directories` vérifie chaque répertoire. Le script échoue ainsi avant la création de la session, ce qui évite d'avoir à la détruire.

**Seul le `~` initial est développé**
Pas de `eval` ni de `$VAR` : un fichier de disposition est de la donnée, jamais du code exécuté.

**`-c` sur chaque fenêtre, et non sur la session seule**
`new-session -c` fixe aussi le répertoire de départ des futures fenêtres, mais seulement à la création. Chaque `new-window` reçoit son propre `-c` : la disposition ne dépend pas de ce défaut, et les fenêtres ouvertes plus tard à la main (`prefix c`) héritent du répertoire de la première.

**Vérification préalable des répertoires**
Avec un `-c` pointant vers un répertoire inexistant, tmux retombe silencieusement sur `$HOME` : la session « réussirait » avec une fenêtre au mauvais endroit.

**Renumérotation de la première fenêtre**
`new-session` ne permet pas de choisir l'index : la première fenêtre prend `base-index` (1 dans `.tmux.conf`, 0 par défaut). Le script relit l'index obtenu et le déplace sur le numéro du fichier si besoin, pour que la disposition ne dépende pas de la configuration tmux.

**`=` devant le nom de session**
`tmux has-session -t projets` accepte un préfixe de nom : avec une session `projets2` ouverte, `projets` serait considérée comme existante. `-t "=projets"` impose la correspondance exacte (même précaution dans `zenv`).

**`rollback_die` plutôt qu'un `trap ERR`**
Une session à moitié construite serait reprise « telle quelle » au lancement suivant, avec des fenêtres manquantes. Chaque commande de `create_session` est donc suivie de `|| rollback_die …`, qui détruit la session avant de quitter. Un `trap ERR` n'est pas fiable ici : il n'est pas hérité par les fonctions sans `set -E`, et une fonction appelée dans un `||` désactiverait `set -e`.

**Profil : préfixe d'environnement et `-e`**
`ZSH_PROFILE=… tmux new-session` suffit quand c'est ce lancement qui démarre le serveur tmux. Si un serveur tourne déjà, seul `-e ZSH_PROFILE=…` (tmux ≥ 3.2) le transmet à la nouvelle session. Avec un tmux plus ancien et un serveur déjà lancé, le profil n'est donc pas pris en compte.

**`TERM=xterm-256color`**
Même valeur que `zenv`, pour que les couleurs du prompt soient identiques quelle que soit la façon d'ouvrir la session.

---

### Dépendances externes

```
bash ≥ 4    →  tableaux, ${var##…} / ${var%%…}, read -r
tmux ≥ 3.2  →  new-session -e (profil sur un serveur déjà lancé) ;
               testé avec tmux 3.4
coreutils   →  head, sed, basename (version de tmux, index de fenêtre, liste des dispositions)
awk         →  réimpression de l'en-tête manpage par --help
```

---

### Points d'extension

**Ajouter une disposition**
Créer `~/.config/zsh-layouts/<nom>.conf`, puis éventuellement un alias à côté de `zsh-cours` dans `.shellrc/rc.d/zenv.sh` :

```bash
# ~/.config/zsh-layouts/tp.conf
1|tp|~/projets/tp
2|notes|~/projets/notes
```

```bash
alias zsh-tp='zsh-layout --layout tp'
```

**Lancer une commande dans une fenêtre**
Ajouter après la boucle de `create_session` (ou lire une quatrième colonne dans le fichier) :

```bash
tmux send-keys -t "=${SESSION}:1" 'git status' Enter
```

**Changer le dossier des dispositions**
`XDG_CONFIG_HOME` est respecté ; sinon la constante `LAYOUTS_DIR` en tête de script.

---

### Notes de maintenance

- **Pas de synchronisation avec la disposition** : une session existante est reprise sans vérification. Modifier un fichier `.conf` ne change donc rien tant que la session n'est pas fermée (`tmux kill-session -t cours`).
- **Profil d'une session reprise** : il reste celui de la création, comme avec `zenv` ; `-p` n'a d'effet qu'à la création.
- **Logique dupliquée avec `zenv.sh`** : `tmux_has_env_flag` et la séquence reprise / bascule existent dans les deux fichiers.
- **Nom de session et profil** : validés par expression régulière avant tout appel à tmux, qui interdit de toute façon `.` et `:` dans un nom de session.
- **Alias uniquement en shell interactif** : `zsh-projets` et `zsh-cours` n'existent pas dans un script ni un lanceur graphique ; appeler alors `zsh-layout --layout …` directement.
- **Anciens scripts** : `zsh-cours` et `zsh-projets` étaient des scripts de `~/.local/bin`. Sur une machine où ils ont été déployés, supprimer les fichiers restants pour qu'ils ne masquent pas les alias.
