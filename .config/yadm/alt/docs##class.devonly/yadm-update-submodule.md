# yadm-update-submodule

> Script : [`.local/bin/yadm-update-submodule`](../.local/bin/yadm-update-submodule)
> Script sous-jacent : [git-update-submodule.md](git-update-submodule.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`yadm-update-submodule` applique `git update-submodule` au **dépôt yadm** : c'est exactement `git-update-submodule --yadm`, sans avoir à taper l'option. Il ne contient aucune logique et transmet tous ses arguments tels quels, donc `sync` (remettre les submodules sur les commits épinglés, après un `yadm pull`), `status` et `<chemin> <tag>` y fonctionnent, ainsi que toute option future. Il ne met **pas** les submodules à la dernière version upstream. Son intérêt : se retrouver avec `yadm-` + Tab. `yadm update-submodule …` fait la même chose, mais exige que `~/.local/bin` soit dans le `PATH` de git.

---

## Section utilisateur

### Description

Wrapper transparent de [`git-update-submodule`](git-update-submodule.md) pour le dépôt yadm (répertoire git `~/.local/share/yadm/repo.git`, arbre de travail `$HOME`). Pour le détail des sous-commandes, des garde-fous et des sorties, voir la page de `git-update-submodule`. Trois façons équivalentes de synchroniser le dépôt yadm :

| Commande | Particularité |
| -------- | ------------- |
| `yadm-update-submodule sync` | se retrouve avec `yadm-` + Tab ; chemin résolu à côté du script |
| `yadm update-submodule sync` | yadm transmet à git, qui cherche `git-update-submodule` dans le `PATH` |
| `git update-submodule --yadm sync` | explicite |

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `git-update-submodule` | toute la logique (même répertoire que le wrapper) | `ls ~/.local/bin/git-update-submodule` |
| dépôt yadm | cible des opérations | `ls -d ~/.local/share/yadm/repo.git` |

### Syntaxe

```bash
yadm-update-submodule <arguments de git-update-submodule>
```

Aucune option propre : `-h`, `-n`, `sync`, `status`… sont celles de `git-update-submodule`. La variable `YADM_REPO` (défaut `~/.local/share/yadm/repo.git`) est lue par ce dernier.

### Exemples d'utilisation

```bash
yadm-update-submodule sync        # après un yadm pull
yadm-update-submodule sync -n     # diagnostic seul
yadm-update-submodule status      # état + URL d'origine
```

```text
$ yadm-update-submodule status
 cac55d0b531a0db72294c9bba9453dfa6374c59d .zsh/custom/plugins/pure (v1.28.4)  url=https://github.com/sindresorhus/pure.git
 35833ea15f14b71dbcebc7e54c104d8d56ca5268 .zsh/custom/themes/powerlevel10k (35833ea1)  url=https://github.com/romkatv/powerlevel10k.git
```

### Codes de retour

Ceux de `git-update-submodule` (0 succès, 1 erreur d'exécution, 2 erreur d'usage) : le wrapper fait un `exec`, il n'a pas de code propre.

---

## Section développeur

### Architecture interne

Une seule ligne utile : `exec "$(dirname "$(readlink -f "$0")")/git-update-submodule" --yadm "$@"`.

### Détail des choix techniques

**Transparent par construction.** Le wrapper ne parse rien : une option ou une sous-commande ajoutée à `git-update-submodule` est disponible ici immédiatement, sans toucher ce fichier. C'est la raison d'être du wrapper ; ne pas y ajouter de logique.

**Chemin résolu à côté du script**, pas par le `PATH` : `~/.local/bin` n'est pas toujours dans le `PATH` (sudo, cron). Conséquence : `git-update-submodule` doit rester dans le même répertoire.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `readlink` (coreutils) | — | `-f`, résolution du chemin réel (le wrapper peut être un lien) |
| `git-update-submodule` | — | toute la logique |

### Points d'extension

Aucun, volontairement : toute évolution se fait dans `git-update-submodule`.

### Notes de maintenance

- Pas d'en-tête d'aide propre : `-h` affiche celle de `git-update-submodule` (qui mentionne `--yadm`).
- [`yadm-check-submodules.sh`](yadm-check-submodules.md) est un alias de compatibilité qui appelle ce wrapper avec `sync`.
- Ne pas confondre avec `yadm-alt-link.py` ou `yadm-push-ssh.sh` : seul ce wrapper concerne les submodules.
