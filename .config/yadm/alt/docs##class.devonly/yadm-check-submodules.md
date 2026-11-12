# yadm-check-submodules.sh

> Script : [`.local/bin/yadm-check-submodules.sh`](../.local/bin/yadm-check-submodules.sh)
> Logique : [git-update-submodule.md](git-update-submodule.md) (sous-commande `sync`)
> Guide associé : [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`yadm-check-submodules.sh` remet les submodules du dépôt dotfiles (oh-my-zsh, powerlevel10k, plugins zsh) au commit épinglé par le dépôt — le réflexe après un `yadm pull` ou sur une machine fraîchement installée. C'est désormais un **alias de compatibilité** : il équivaut à `yadm-update-submodule sync`, c'est-à-dire `git update-submodule --yadm sync`, et ne contient plus de logique. Il ne tire **jamais** la dernière version upstream d'un submodule (c'est `git submodule update --remote`, depuis le dépôt de développement). `--dry-run` se contente du diagnostic.

---

## Section utilisateur

### Description

Vérifie que les submodules du dépôt yadm sont au **commit épinglé** et les synchronise sinon. Usage courant : juste après un `yadm pull`, ou lors de l'installation d'une nouvelle machine ([`dot-test.sh`](../.local/bin/dot-test.sh) l'appelle).

Le script est un simple `exec yadm-update-submodule sync "$@"`. Toute la logique (détection des écarts, conflits, `submodule update`) est dans la sous-commande `sync` de [`git-update-submodule`](git-update-submodule.md) ; pour les nouveautés, privilégier [`yadm-update-submodule`](yadm-update-submodule.md). Le nom est conservé pour ne pas casser `dot-test.sh` ni les habitudes.

Il ne fait que **synchroniser** vers le commit épinglé. Mettre à jour vers upstream est décrit dans [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md).

### Prérequis

Ceux de [`yadm-update-submodule`](yadm-update-submodule.md) : `git`, dépôt yadm, `git-update-submodule` dans le même répertoire.

### Syntaxe

```bash
yadm-check-submodules.sh [-n] [-h]
```

| Option | Défaut | Description |
| ------ | ------ | ----------- |
| `-n`, `--dry-run` | désactivé | Signale les submodules désynchronisés sans rien modifier |
| `-h`, `--help` | — | Affiche l'aide de `git-update-submodule` |

Variable d'environnement `YADM_REPO` (défaut `~/.local/share/yadm/repo.git`) : lue par `git-update-submodule`.

### Exemples d'utilisation

```bash
# Usage courant, après un yadm pull
yadm-check-submodules.sh

# Diagnostic seul
yadm-check-submodules.sh --dry-run
```

```text
[INFO]      Vérification de l'état des submodules...
[OK]        Tous les submodules sont déjà à jour.
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Submodules à jour, ou synchronisation réussie |
| 1 | Erreur d'exécution : dépôt yadm introuvable, échec de `git`, conflit de fusion |
| 2 | Erreur d'usage : option inconnue |

---

## Section développeur

### Architecture interne

`exec "$(dirname "$(readlink -f "$0")")/yadm-update-submodule" sync "$@"` → `git-update-submodule --yadm sync "$@"` → `cmd_sync`.

### Détail des choix techniques

**Pourquoi un alias et non une suppression.** [`dot-test.sh`](../.local/bin/dot-test.sh) et l'habitude de compléter `yadm-` + Tab reposent sur ce nom. Les pièges qui avaient justifié l'ancienne implémentation (`cd "$HOME"` obligatoire pour `git-submodule`, pas de `grep` dans un `if`, traitement séparé de `U`) sont désormais gérés dans `git-update-submodule` : voir sa section *Détail des choix techniques*.

### Dépendances externes

`yadm-update-submodule` et `git-update-submodule`, dans le même répertoire.

### Points d'extension

Aucun ici : ajouter une option ou un comportement dans `git-update-submodule`. Pour synchroniser un sous-ensemble de submodules, y étendre `sync` (`git submodule update` accepte des chemins).

### Notes de maintenance

- **Ne pas y remettre de logique** : le but est que modifier `git-update-submodule` suffise.
- **`dot-test.sh` l'appelle avec `|| true`** : un échec de synchronisation n'interrompt pas l'installation.
- **Chemin du dépôt yadm.** `~/.local/share/yadm/repo.git` pour les versions récentes de yadm, `~/.config/yadm/repo.git` pour les anciennes : `YADM_REPO` couvre les deux.
