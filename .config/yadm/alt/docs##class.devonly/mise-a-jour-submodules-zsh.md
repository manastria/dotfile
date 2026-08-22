# Mise à jour des submodules zsh (oh-my-zsh, plugins, thème)

Ce document décrit comment mettre à jour oh-my-zsh et ses plugins, gérés comme submodules git dans ce dépôt dotfiles.

---

## Inventaire des submodules

| Chemin | Dépôt upstream | Rôle |
| ------ | -------------- | ---- |
| `.zsh/oh-my-zsh` | ohmyzsh/ohmyzsh | Framework zsh |
| `.zsh/custom/themes/powerlevel10k` | romkatv/powerlevel10k | Thème |
| `.zsh/custom/plugins/zsh-autosuggestions` | zsh-users/zsh-autosuggestions | Suggestions en ligne |
| `.zsh/custom/plugins/zsh-completions` | zsh-users/zsh-completions | Complétion étendue |
| `.zsh/custom/plugins/zsh-syntax-highlighting` | zsh-users/zsh-syntax-highlighting | Coloration syntaxique |
| `.zsh/custom/plugins/zsh-vi-mode` | jeffreytse/zsh-vi-mode | Mode vi dans le shell |
| `.zsh/custom/plugins/zsh-dircolors-solarized` | manastria/zsh-dircolors-solarized | Couleurs ls |

Tous sont déclarés avec `shallow = true` dans `.gitmodules` (clone superficiel, sans historique complet).

---

## Concepts clés : deux opérations distinctes

| Opération | Commande | Effet |
| --------- | -------- | ----- |
| **Synchroniser** vers le commit épinglé | `yadm submodule update --init --recursive` | Met le répertoire local au commit référencé dans le dépôt — ne tire rien depuis internet si déjà au bon commit |
| **Mettre à jour** vers le dernier commit upstream | `git submodule update --remote` | Tire le dernier commit de la branche par défaut depuis GitHub — met à jour le pointeur dans le dépôt |

`yadm-check-submodules.sh` effectue uniquement la **synchronisation**. La **mise à jour upstream** est une opération séparée, décrite ci-dessous.

---

## Procédures

### A. Vérifier l'état des submodules

```bash
# Depuis le dépôt dotfiles
cd ~/projets/dotfile
git submodule status
```

Préfixes dans la sortie :

| Préfixe | Signification |
| ------- | ------------- |
| ` ` (espace) | Submodule au bon commit, propre |
| `-` | Non initialisé (jamais cloné) |
| `+` | Local en avance sur le commit épinglé |
| `U` | Conflits de fusion |

---

### B. Synchroniser après un `yadm pull` (usage quotidien)

Après avoir tiré des modifications du dépôt dotfiles, les submodules peuvent être désynchronisés.

```bash
yadm submodule update --init --recursive
# ou via le script existant :
~/.local/bin/yadm-check-submodules.sh
```

Le script est lançable depuis n'importe quel répertoire, y compris `/mnt/c` sous WSL, et n'agit que si un submodule est effectivement désynchronisé. Détail des options et des codes de retour : [yadm-check-submodules.md](yadm-check-submodules.md).

---

### C. Mettre à jour un submodule vers la dernière version upstream

#### oh-my-zsh seul

```bash
cd ~/projets/dotfile
git submodule update --remote --depth 1 .zsh/oh-my-zsh
git add .zsh/oh-my-zsh
git commit -m "chore: update oh-my-zsh"
```

#### Un plugin spécifique

```bash
cd ~/projets/dotfile
git submodule update --remote --depth 1 .zsh/custom/plugins/zsh-autosuggestions
git add .zsh/custom/plugins/zsh-autosuggestions
git commit -m "chore: update zsh-autosuggestions"
```

#### Tous les submodules en une fois

```bash
cd ~/projets/dotfile
git submodule update --remote --depth 1
git add .zsh/
git commit -m "chore: update all zsh submodules"
yadm push
```

> `--depth 1` est nécessaire pour conserver les clones superficiels (`shallow = true`).
> Sans cette option, git télécharge l'historique complet.

---

### D. Propager la mise à jour sur une autre machine

Sur la machine cible :

```bash
yadm pull
yadm submodule update --init --recursive
exec $SHELL
```

---

### E. Vérifier qu'oh-my-zsh fonctionne après mise à jour

```bash
# Version d'oh-my-zsh
head -5 ~/.zsh/oh-my-zsh/oh-my-zsh.sh

# Thème actif
echo $ZSH_THEME

# Plugins chargés
echo $plugins

# Rechargement propre
exec $SHELL
```

---

### F. Libérer de l'espace (désactiver sans supprimer)

`git submodule deinit` vide le répertoire de travail du submodule sans le retirer de `.gitmodules`. Le submodule reste déclaré — un `git submodule update --init` suffit à le restaurer.

#### Désactiver un submodule

```bash
cd ~/projets/dotfile
git submodule deinit .zsh/oh-my-zsh
```

Le répertoire `.zsh/oh-my-zsh/` devient vide. `git submodule status` affiche un préfixe `-`.

#### Désactiver tous les submodules en une fois

```bash
cd ~/projets/dotfile
git submodule deinit --all
```

#### Restaurer après désactivation

```bash
cd ~/projets/dotfile
git submodule update --init --recursive
```

> `deinit` ne modifie pas `.gitmodules` ni l'index git — aucun commit n'est nécessaire.

---

## Pièges à éviter

### `omz update` ne met pas à jour le dépôt dotfiles

```bash
omz update   # ❌ modifie ~/.zsh/oh-my-zsh en place
             #    le commit épinglé dans le dépôt reste inchangé
             #    les autres machines ne reçoivent pas la mise à jour
```

Utiliser `git submodule update --remote` dans le dépôt dotfiles à la place.

### Ne jamais committer depuis `~/.zsh/oh-my-zsh`

Les submodules sont en mode "detached HEAD". Tout commit fait dans le répertoire du submodule est perdu au prochain `submodule update`.

### Après une mise à jour majeure d'oh-my-zsh

Vérifier le changelog pour les changements de comportement :

```bash
cat ~/.zsh/oh-my-zsh/CHANGELOG.md | head -80
```

Si le shell se comporte de façon inattendue après mise à jour, revenir au commit précédent :

```bash
cd ~/projets/dotfile
git log --oneline .zsh/oh-my-zsh    # trouver le commit précédent
git checkout <commit-hash> -- .zsh/oh-my-zsh
git commit -m "revert: rollback oh-my-zsh to <commit-hash>"
yadm push
```
