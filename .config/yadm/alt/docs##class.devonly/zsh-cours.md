# `zsh-cours` — Session tmux de cours, une fenêtre par répertoire

> Script : [`.local/bin/zsh-cours`](../.local/bin/zsh-cours)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`zsh-cours` ouvre une session tmux nommée `cours` dont chaque fenêtre démarre dans son propre répertoire : la fenêtre 1 dans `~/projets`, la fenêtre 2 dans `~/projets/cours_astro`. C'est l'équivalent « disposition imposée » de `zsh-daily`, qui ouvre au contraire la session `main` dans le répertoire courant, sans rien préparer. Si la session existe déjà, elle est **reprise telle quelle** : le script ne recrée ni ne déplace aucune fenêtre, et depuis l'intérieur de tmux il bascule vers la session au lieu d'imbriquer un second tmux. Les options utiles au quotidien sont `-p` (profil zsh, `simple` par défaut), `-D` (détacher un autre terminal resté connecté) et `-n` (préparer la session sans s'y rattacher). Les fenêtres se changent dans le tableau `WINDOWS` en tête du script.

---

## Section utilisateur

### Description

`zsh-cours` construit une session tmux à partir d'une liste fixe de fenêtres, chacune avec un numéro, un nom et un répertoire de départ :

| Fenêtre | Nom       | Répertoire                |
| ------- | --------- | ------------------------- |
| 1       | `projets` | `~/projets`               |
| 2       | `astro`   | `~/projets/cours_astro`   |

La fenêtre 1 est celle affichée à l'arrivée dans la session.

Il se distingue de ses voisins :

| Commande      | Session      | Répertoire des fenêtres      | Fenêtres préparées |
| ------------- | ------------ | ---------------------------- | ------------------ |
| `zsh-daily`   | `main`       | celui où on lance la commande | non               |
| `zsh-cours`   | `cours`      | fixé par le script, par fenêtre | oui             |

`zsh-daily` est un alias de `zenv`, une **fonction** du shell interactif (`.shellrc/rc.d/zenv.sh`). `zsh-cours` est un **script** : il ne peut pas appeler `zenv` et refait donc lui-même ce dont il a besoin (profil, création ou reprise, bascule depuis tmux).

---

### Prérequis

| Outil       | Rôle                                           | Vérification   |
| ----------- | ---------------------------------------------- | -------------- |
| `bash` ≥ 4  | Interpréteur (tableau `WINDOWS`)               | `bash --version` |
| `tmux` ≥ 3.2 | Profil transmis par `-e` à un serveur déjà lancé (voir plus bas) | `tmux -V` |
| `zsh`       | Shell lancé dans les fenêtres (`default-shell` de `.tmux.conf`) | `zsh --version` |

Les répertoires `~/projets` et `~/projets/cours_astro` doivent exister : le script s'arrête sinon. Aucun droit administrateur n'est requis.

---

### Syntaxe

```
zsh-cours [-p PROFIL] [-s SESSION] [-D] [-n]
zsh-cours -h | --help
```

| Option            | Argument | Défaut   | Description                                                                 |
| ----------------- | -------- | -------- | --------------------------------------------------------------------------- |
| `-p`, `--profile` | profil   | `simple` | Profil zsh des fenêtres (`ZSH_PROFILE`) : mêmes valeurs que `zenv`          |
| `-s`, `--session` | nom      | `cours`  | Nom de la session tmux (lettres, chiffres, `_` et `-`)                      |
| `-D`, `--detach`  | —        | désactivé | Détache d'abord les autres clients attachés à la session                   |
| `-n`, `--no-attach` | —      | désactivé | Crée la session sans s'y rattacher                                          |
| `-h`, `--help`    | —        | —        | Affiche l'en-tête manpage du script                                         |

---

### Exemples d'utilisation

```bash
# Ouvrir (ou reprendre) la session de cours
zsh-cours

# Autre profil zsh (oh-my-zsh sans powerlevel10k)
zsh-cours -p omz

# Préparer la session en arrière-plan, s'y rattacher plus tard
zsh-cours --no-attach
tmux attach -t cours

# Reprendre une session restée ouverte dans un autre terminal
zsh-cours -D
```

**Exemple de sortie** (première exécution, avec `--no-attach`) :

```
[OK]        Session 'cours' créée (2 fenêtres, profil simple).
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

---

### Codes de retour

| Code | Signification                                                                                         |
| ---- | ----------------------------------------------------------------------------------------------------- |
| `0`  | Session créée ou reprise, puis quittée normalement                                                    |
| `1`  | Erreur d'exécution : `tmux` absent, répertoire introuvable, profil inconnu, échec de `tmux`           |
| `2`  | Erreur d'usage : option inconnue, valeur manquante, nom de profil ou de session invalide              |

---

## Section développeur

### Architecture interne

```
parse_args          →  options ; validation des noms de profil et de session
check_prerequisites →  tmux présent, profil existant, répertoires de WINDOWS présents
main                →  has-session ? reprise : create_session
create_session      →  new-session -d (fenêtre 1) puis new-window par entrée suivante,
                       renumérotation, select-window ; rollback_die en cas d'échec
attach_session      →  switch-client (depuis tmux) ou exec attach-session
```

---

### Détail des choix techniques

**Un script plutôt qu'une fonction**
`zenv` est une fonction de `.shellrc/rc.d/zenv.sh`, chargée dans le shell interactif ; un script lancé dans un sous-processus ne la voit pas. Le test de version de tmux (`tmux_has_env_flag`) et la logique « session existante → reprise, depuis tmux → bascule » sont donc **recopiés** de `zenv.sh` : une correction faite dans l'un est à reporter dans l'autre.

**`-c` sur chaque fenêtre, et non sur la session seule**
`new-session -c` fixe aussi le répertoire de départ des futures fenêtres, mais seulement à la création. Chaque `new-window` reçoit son propre `-c` : la disposition ne dépend pas de ce défaut, et les fenêtres ouvertes plus tard à la main (`prefix c`) héritent du répertoire de la première.

**Vérification préalable des répertoires**
Avec un `-c` pointant vers un répertoire inexistant, tmux retombe silencieusement sur `$HOME` : la session « réussirait » avec une fenêtre au mauvais endroit. Le script échoue avant de créer quoi que ce soit.

**Renumérotation de la première fenêtre**
`new-session` ne permet pas de choisir l'index : la première fenêtre prend `base-index` (1 dans `.tmux.conf`, 0 par défaut). Le script relit l'index obtenu et le déplace sur le numéro du tableau si besoin, pour que la disposition ne dépende pas de la configuration tmux.

**`=` devant le nom de session**
`tmux has-session -t cours` accepte un préfixe de nom : avec une session `cours2` ouverte, `cours` serait considérée comme existante. `-t "=cours"` impose la correspondance exacte (même précaution dans `zenv`).

**`rollback_die` plutôt qu'un `trap ERR`**
Une session à moitié construite serait reprise « telle quelle » au lancement suivant, avec des fenêtres manquantes. Chaque commande de `create_session` est donc suivie de `|| rollback_die …`, qui détruit la session avant de quitter. Un `trap ERR` n'est pas fiable ici : il n'est pas hérité par les fonctions sans `set -E`, et une fonction appelée dans un `||` désactiverait `set -e`.

**Profil : préfixe d'environnement et `-e`**
`ZSH_PROFILE=… tmux new-session` suffit quand c'est ce lancement qui démarre le serveur tmux. Si un serveur tourne déjà, seul `-e ZSH_PROFILE=…` (tmux ≥ 3.2) le transmet à la nouvelle session. Avec un tmux plus ancien et un serveur déjà lancé, le profil n'est donc pas pris en compte.

**`TERM=xterm-256color`**
Même valeur que `zenv`, pour que les couleurs du prompt soient identiques quelle que soit la façon d'ouvrir la session.

---

### Dépendances externes

```
bash ≥ 4    →  tableau readonly WINDOWS, ${var##…} / ${var%%…}
tmux ≥ 3.2  →  new-session -e (profil sur un serveur déjà lancé) ;
               testé avec tmux 3.4
coreutils   →  head, sed (lecture de la version et de l'index de fenêtre)
awk         →  réimpression de l'en-tête manpage par --help
```

---

### Points d'extension

**Ajouter ou modifier une fenêtre**
Une ligne du tableau `WINDOWS` (`numéro|nom|répertoire`) par fenêtre ; la première est celle affichée à l'arrivée :

```bash
readonly WINDOWS=(
    "1|projets|${HOME}/projets"
    "2|astro|${HOME}/projets/cours_astro"
    "3|notes|${HOME}/projets/notes"
)
```

Le nom de fenêtre et le chemin ne doivent pas contenir `|`.

**Une seconde disposition (autre cours, autre projet)**
Copier le script sous un autre nom en changeant `DEFAULT_SESSION` et `WINDOWS`. Si les dispositions se multiplient, l'étape suivante est de lire `WINDOWS` depuis un fichier (`~/.config/zenv/layouts/<nom>.conf`) et de fusionner l'ensemble dans `zenv` avec une option `--layout`.

**Lancer une commande dans une fenêtre**
Ajouter après la boucle de `create_session` :

```bash
tmux send-keys -t "=${SESSION}:2" 'git status' Enter
```

---

### Notes de maintenance

- **Pas de synchronisation avec la disposition** : une session existante est reprise sans vérification. Modifier `WINDOWS` ne change donc rien tant que la session `cours` n'est pas fermée (`tmux kill-session -t cours`).
- **Profil d'une session reprise** : il reste celui de la création, comme avec `zenv` ; `-p` n'a d'effet qu'à la création.
- **Logique dupliquée avec `zenv.sh`** : `tmux_has_env_flag` et la séquence reprise / bascule existent dans les deux fichiers.
- **Nom de session et profil** : validés par expression régulière avant tout appel à tmux, qui interdit de toute façon `.` et `:` dans un nom de session.
