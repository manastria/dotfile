# Migration : fasd + fzf (subrepo) → zoxide + fzf (binaire)

Ce document décrit la procédure de migration complète du système de navigation interactive.

---

## Contexte

| Avant | Après |
| ----- | ----- |
| `fasd` (apt) — abandonné depuis 2017 | `zoxide` (binaire GitHub Releases) — actif |
| `fzf` (sous-module git `.fzf/`) à v0.30 | `fzf` (binaire GitHub Releases) à la dernière version |
| `fzf` également dans `install-paquets.sh` | `fzf` géré uniquement par `install-fzf.sh` |
| `.fzf.bash` / `.fzf.zsh` sourcent `~/.fzf/shell/` | `.fzf.bash` / `.fzf.zsh` utilisent `eval "$(fzf --bash/zsh)"` |
| Fonction `z` personnalisée (fasd + fzf) | `z` et `zi` fournis nativement par zoxide |
| Fonction `v` basée sur `fasd -f` | Fonction `v` basée sur `fdfind` + fzf |

---

## Équivalences de commandes

| Ancienne commande | Nouvelle commande | Note |
| ----------------- | ----------------- | ---- |
| `z motif` | `z motif` | identique — algorithme amélioré |
| `z` (liste interactive) | `zi` | sélecteur fzf natif |
| `z motif` (interactif) | `zi motif` | pré-filtré |
| `v fichier` | `v fichier` | identique — source différente (fd au lieu de fasd) |

> **Note :** `v` ne se souvient plus des fichiers *récemment édités* (fasd trackait l'historique).
> Il fait maintenant une recherche fzf dans l'arborescence du répertoire courant.

---

## Procédure de migration

### Prérequis

- yadm configuré et fonctionnel
- Accès internet sur la machine à migrer
- `fd-find` installé (`apt install fd-find` ou via `install-paquets.sh`)

---

### Étape 1 — Désinstaller fasd

```bash
sudo apt remove --purge fasd
```

Vérifier qu'il n'y a plus de trace :

```bash
command -v fasd && echo "encore présent" || echo "OK"
```

---

### Étape 2 — Supprimer le sous-module fzf

> À faire **dans le dépôt dotfiles** (pas depuis `$HOME`).

```bash
cd ~/projets/dotfile
git rm -r .fzf
git commit -m "refactor: supprime le subrepo fzf (remplacé par install-fzf.sh)"
```

---

### Étape 3 — Installer les nouveaux binaires

```bash
~/.local/bin/install-fzf.sh
~/.local/bin/install-zoxide.sh
```

Vérifier les versions installées :

```bash
fzf --version      # >= 0.48
zoxide --version   # >= 0.9
```

Les binaires sont installés dans `~/.local/bin/`. Vérifier que ce répertoire est dans le `PATH` :

```bash
echo $PATH | grep -q "$HOME/.local/bin" && echo "OK" || echo "Ajouter ~/.local/bin au PATH"
```

---

### Étape 4 — Déployer les dotfiles mis à jour

Sur la machine en cours de migration (si les fichiers ont été modifiés dans le dépôt et poussés) :

```bash
yadm pull
```

Ou, si la migration est faite directement sur la machine :

```bash
yadm add ~/.fzf.bash ~/.fzf.zsh
yadm add ~/.shellrc/rc.d/05-navigation.sh
yadm add ~/.local/bin/install-fzf.sh
yadm add ~/.local/bin/install-zoxide.sh
yadm commit -m "refactor: migration fasd→zoxide, fzf subrepo→binaire"
yadm push
```

---

### Étape 5 — Relancer le shell et vérifier

```bash
exec $SHELL
```

Tests de validation :

```bash
# fzf opérationnel
fzf --version

# Ctrl+R, Ctrl+T, Alt+C doivent fonctionner dans le shell

# zoxide opérationnel
z --version 2>/dev/null || zoxide --version

# Aller dans un répertoire pour l'enregistrer dans zoxide
cd ~/projets
cd ~

# Tester le saut
z projets          # doit atterrir dans ~/projets

# Tester la sélection interactive
zi                 # doit ouvrir un sélecteur fzf

# Tester v
cd ~/projets/dotfile
v toml             # doit proposer les fichiers .toml du répertoire courant
```

---

### Étape 6 — Propager sur les autres machines

Sur chaque autre machine gérée par yadm :

```bash
yadm pull
yadm submodule update --init --recursive   # met à jour les autres submodules zsh

# Puis installer les binaires (non gérés par yadm)
~/.local/bin/install-fzf.sh
~/.local/bin/install-zoxide.sh

sudo apt remove --purge fasd

exec $SHELL
```

---

## Rollback

Si la migration pose problème, revenir à l'ancienne configuration :

```bash
# Réinstaller fasd
sudo apt install fasd

# Restaurer l'ancien .fzf.bash (pointe vers ~/.fzf/shell/)
# et l'ancien 05-navigation.sh (avec fasd --init auto)
yadm checkout HEAD~1 -- .fzf.bash .fzf.zsh .shellrc/rc.d/05-navigation.sh

# Réinitialiser le sous-module fzf
yadm submodule update --init .fzf

exec $SHELL
```

---

## Fichiers modifiés lors de la migration

| Fichier | Nature du changement |
| ------- | -------------------- |
| `.fzf.bash` | `eval "$(fzf --bash)"` au lieu de sourcer `~/.fzf/shell/` |
| `.fzf.zsh` | `eval "$(fzf --zsh)"` au lieu de sourcer `~/.fzf/shell/` |
| `.shellrc/rc.d/05-navigation.sh` | `fasd` → `zoxide`, `z`/`v` réécrites |
| `.local/bin/install-fzf.sh` | Nouveau script — binaire GitHub Releases |
| `.local/bin/install-zoxide.sh` | Nouveau script — binaire GitHub Releases |
| `.local/bin/install-paquets.sh` | Retrait de `fzf` et `fasd` de la liste apt |
| `.fzf/` (subrepo) | Supprimé du dépôt git |
