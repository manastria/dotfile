# yadm-check-submodules.sh

> Script : [`.local/bin/yadm-check-submodules.sh`](../.local/bin/yadm-check-submodules.sh)
> Guide associé : [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md)

---

# Section utilisateur

## Description

Vérifie que les submodules du dépôt dotfiles géré par yadm (oh-my-zsh, powerlevel10k, plugins zsh) sont au **commit épinglé** par le dépôt, et les synchronise sinon. Usage courant : juste après un `yadm pull`, ou lors de l'installation d'une nouvelle machine ([`dot-test.sh`](../.local/bin/dot-test.sh) l'appelle).

Le script ne fait que **synchroniser** vers le commit épinglé. Il ne tire jamais la dernière version *upstream* d'un submodule — cette opération, distincte, est décrite dans [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md).

Équivalent manuel :

```bash
yadm submodule update --init --recursive
```

L'intérêt du script est de ne rien faire quand tout est déjà en place, de rapporter précisément ce qui cloche, et de fonctionner quel que soit le répertoire courant.

## Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `git` | opérations sur les submodules | `git --version` |
| dépôt yadm | données du dépôt dotfiles | `ls -d ~/.local/share/yadm/repo.git` |
| accès réseau | uniquement si un submodule doit être cloné | `git ls-remote https://github.com/ohmyzsh/ohmyzsh` |

## Syntaxe

```bash
yadm-check-submodules.sh [-n] [-h]
```

| Option | Défaut | Description |
| ------ | ------ | ----------- |
| `-n`, `--dry-run` | désactivé | Signale les submodules désynchronisés sans rien modifier |
| `-h`, `--help` | — | Affiche l'en-tête du script |

| Variable d'environnement | Défaut | Description |
| ------------------------ | ------ | ----------- |
| `YADM_REPO` | `~/.local/share/yadm/repo.git` | Chemin du dépôt yadm |

## Exemples d'utilisation

```bash
# Usage courant, après un yadm pull
yadm-check-submodules.sh

# Diagnostic seul, sans téléchargement
yadm-check-submodules.sh --dry-run

# Dépôt yadm à un emplacement non standard
YADM_REPO=/srv/dotfiles/repo.git yadm-check-submodules.sh
```

Tout est en place :

```
[INFO]      Vérification de l'état des submodules...
[OK]        Tous les submodules sont déjà à jour.
```

Un submodule n'a jamais été cloné :

```
[INFO]      Vérification de l'état des submodules...
[ATTENTION] Mise à jour des submodules requise :
[ATTENTION]   -1a2b3c4d5e6f7890abcdef1234567890abcdef12 .zsh/custom/plugins/zsh-vi-mode
[INFO]      Téléchargement et mise à jour en cours...
[OK]        Submodules synchronisés.
```

Préfixes de `git submodule status` interprétés par le script :

| Préfixe | Signification | Traitement |
| ------- | ------------- | ---------- |
| ` ` (espace) | au bon commit | rien |
| `-` | non initialisé | `submodule update --init` |
| `+` | commit local différent de celui épinglé | `submodule update` |
| `U` | conflit de fusion | arrêt en erreur, intervention manuelle |

## Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Submodules à jour, ou synchronisation réussie |
| 1 | Erreur d'exécution : `git` absent, dépôt yadm introuvable, échec de `git`, conflit de fusion |
| 2 | Erreur d'usage : option inconnue |

---

# Section développeur

## Architecture interne

`main()` enchaîne :

1. `parse_args` — `--dry-run`, `--help`.
2. `check_repo` — présence de `git`, existence de `$YADM_REPO`, puis `cd "$HOME"`.
3. `check_submodules` — `git submodule status --recursive`, analyse des préfixes, puis `git submodule update --init --recursive` si nécessaire.

`yadm_git()` encapsule le préfixe `git --git-dir=… --work-tree=…` commun à tous les appels.

## Détail des choix techniques

**`cd "$HOME"` obligatoire.** yadm range ses données dans un dépôt dont l'arbre de travail est `$HOME`. `git-submodule` est un script shell qui appelle `require_work_tree` : il exige que le **répertoire courant** soit dans l'arbre de travail, en plus de `--work-tree`. Lancé depuis un chemin extérieur — typiquement `/mnt/c/Users/…` sous WSL — il échouait avec :

```
fatal: /usr/lib/git-core/git-submodule cannot be used without a working tree.
```

D'où le `cd "$HOME"` dans `check_repo`, avant tout appel à git.

**Pas de `git status | grep` dans un `if`.** La version initiale testait :

```bash
if $YADM_GIT submodule status --recursive | grep -q '^[-+]'; then
```

Le code de retour d'un pipeline est celui de sa **dernière** commande : l'échec de git était masqué par le `grep`, qui renvoyait 1 sur une entrée vide. Le script affichait alors *« Tous les submodules sont déjà à jour »* juste après le `fatal:` de git — un faux positif silencieux, exactement dans le cas où l'information importait. `set -o pipefail` n'aurait pas suffi : dans une condition `if`, `set -e` et `pipefail` ne déclenchent pas de sortie. La sortie est donc capturée dans une variable, avec `|| die` explicite.

**Affectation séparée de la déclaration.** `local status="$(cmd)"` renvoie le code de retour de `local`, pas de `cmd`. Le script déclare `local status` puis affecte sur une ligne distincte, seule forme où le `|| die` porte réellement sur git.

**Traitement séparé de `U`.** Un submodule en conflit de fusion n'est pas réparable par `submodule update` — le lancer masquerait le conflit ou échouerait de façon obscure. Le script s'arrête et affiche les lignes concernées.

**`#!/usr/bin/env bash` et `set -euo pipefail`.** Alignement sur les scripts récents de `.local/bin/` ; le `-u` protège notamment `${YADM_REPO}` d'une variable vide mal exportée.

## Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `git` | 1.8 | `git --git-dir --work-tree submodule`, `--recursive` sur `status` |
| `bash` | 3.2 | `<<<` (here-string), `[[ ]]` |
| `awk` | — | extraction de l'aide depuis l'en-tête |

## Points d'extension

**Synchroniser un sous-ensemble de submodules** — `git submodule update` accepte des chemins :

```bash
yadm_git submodule update --init --recursive -- .zsh/oh-my-zsh
```

**Rendre le script silencieux quand tout va bien** (appel depuis l'init du shell) — conditionner les `info`/`success` à une variable `QUIET`, en gardant les `warn`/`error`.

**Contrôler la profondeur des clones** — les submodules sont déclarés `shallow = true` dans `.gitmodules` ; ajouter `--depth 1` à `submodule update` si un jour un clone complet remonte par erreur.

## Notes de maintenance

- **Ce script ne met pas à jour vers upstream.** Toute demande de type « mets à jour oh-my-zsh » relève de `git submodule update --remote`, décrit dans [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md). Ne pas ajouter `--remote` ici : le script serait alors capable de modifier les commits épinglés sans commit associé.
- **`dot-test.sh` l'appelle avec `|| true`** : un échec de synchronisation n'interrompt pas l'installation. Ne pas compter sur ce script pour signaler un problème bloquant dans ce contexte.
- **Chemin du dépôt yadm.** `~/.local/share/yadm/repo.git` est l'emplacement des versions récentes de yadm ; les anciennes utilisaient `~/.config/yadm/repo.git`. La variable `YADM_REPO` permet de couvrir les deux sans modifier le script.
