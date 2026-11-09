# zssh.sh

> Script : [`.local/bin/zssh.sh`](../.local/bin/zssh.sh)
> Guide associé : [zsh-profils.md](zsh-profils.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`zssh.sh` ouvre une session SSH vers une machine qui possède déjà les dotfiles, et y lance une session tmux (`main` par défaut) avec un profil zsh choisi (`ssh` par défaut). La session est créée ou reprise : après une coupure réseau, relancer la même commande retrouve le travail en cours. Il ne lance **pas** de profil sur la machine locale, c'est le rôle de `zenv`. Les options courantes sont `-e PROFIL` pour le profil distant, `-s SESSION` pour choisir la session tmux distante (`main` par défaut) et `-D` pour détacher les autres clients déjà attachés à la session. Ces options se placent avant les options ssh (`-p`, `-i`…), qui sont transmises telles quelles.

---

## Section utilisateur

### Description

Remplace l'ancienne fonction shell `zssh` (autrefois dans `zenv.sh`) par un script autonome, doté d'une aide `--help`. Il exécute `ssh -t HOTE "tmux new-session -A -s main"` avec `ZSH_PROFILE` et `TERM` positionnés côté distant.

Différence avec `zenv` : `zenv` lance un profil zsh sur la machine **locale** ; `zssh.sh` le fait sur une machine **distante**.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `ssh` (local) | connexion | `ssh -V` |
| `tmux` (distant) | session persistante | `ssh hôte tmux -V` |
| dotfiles (distant) | profils zsh (`ZSH_PROFILE`) | `ssh hôte 'ls ~/.shellrc'` |

### Syntaxe

```bash
zssh.sh [-e PROFIL] [-s SESSION] [-D] [OPTIONS_SSH...] HOTE
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-e`, `--profile` | PROFIL | `ssh` | Profil zsh distant (lettres, chiffres, `.`, `_`, `-`) |
| `-s`, `--session` | SESSION | `main` | Session tmux distante à créer ou reprendre (lettres, chiffres, `_`, `-`) |
| `-D`, `--detach` | — | désactivé | Détache les autres clients de la session (`tmux new-session -D`) |
| `-h`, `--help` | — | — | Affiche l'en-tête du script |
| `OPTIONS_SSH`, `HOTE` | — | — | Transmis à `ssh` |

### Exemples d'utilisation

```bash
# Profil par défaut
zssh.sh user@host

# Autre profil, port et clé personnalisés
zssh.sh -e writer -p 2222 -i ~/.ssh/id_ed25519 user@host

# Choisir la session tmux distante (créée si absente)
zssh.sh -s projet user@host

# Reprendre une session restée ouverte sur un autre poste
zssh.sh -D user@host
```

Sans hôte :

```
[ERREUR]    Hôte manquant.
Essayez : zssh.sh --help
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Session terminée normalement |
| 1 | `ssh` absent |
| 2 | Erreur d'usage : option inconnue, valeur manquante, hôte absent, profil ou nom de session invalide |
| autre | Code de retour de `ssh` (255 : échec de connexion) |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — lit `-e`, `-s`, `-D`, `-h` jusqu'au premier argument inconnu ; le reste va dans `SSH_ARGS`.
2. `check_ssh` — présence de `ssh`.
3. `connect` — `exec ssh -t …` avec la commande distante.

### Détail des choix techniques

**Options zssh avant les options ssh.** Tout ce qui suit le premier argument inconnu part vers `ssh`. Un `-D` placé après (`zssh.sh -p 22 -D hôte`) est donc le `-D` de ssh (redirection dynamique de port), pas celui de zssh. C'est pourquoi `-D` détache côté tmux sans être ambigu tant qu'il reste en tête.

**`-D` de tmux, avec `-A`.** `new-session -A -D` se comporte comme `attach-session -d` : si la session existe, les autres clients sont détachés avant le rattachement ; sinon, elle est créée.

**`-s` et ssh.** `-s` est aussi une option ssh (sous-système), mais comme les options de zssh se placent en tête, il n'y a pas d'ambiguïté : placé après le premier argument inconnu, il part vers ssh.

**Profil et session validés par regex.** Les noms sont insérés entre apostrophes dans une commande interprétée par le shell distant ; restreindre les caractères est plus sûr que d'échapper.

**`exec ssh`.** Le code de retour de ssh devient celui du script.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `ssh` | — | `-t` (pseudo-terminal) |
| `tmux` (distant) | 1.8 | `new-session -A` ; `-D` associé à `-A` |
| `bash` | 4.4 | tableau vide avec `set -u` (`SSH_ARGS`) |

### Points d'extension

**Autre option distante** — ajouter un cas dans `parse_args` (avant `--`) et la valider comme `PROFILE` et `SESSION` :

```bash
-s|--session) SESSION="$2"; shift 2 ;;
```

### Notes de maintenance

- L'ancienne fonction `zssh` a été retirée de `.shellrc/rc.d/zenv.sh`. Sur une machine non mise à jour, le shell la trouve encore pour la commande `zssh` ; la commande `zssh.sh` appelle bien le script. L'alias `zssh` (défini dans `.shellrc/rc.d/alias.sh`) pointe vers le script.
- Pas de `sudo` ni de garde root : le script n'écrit rien en local.
