# Navigation interactive — fasd + fzf

Ce document décrit le système de navigation rapide dans le shell, combinant **fasd** (historique pondéré des fichiers et répertoires visités) et **fzf** (sélecteur interactif flou).

---

## Section utilisateur

### Description

fasd et fzf transforment la navigation shell en deux axes complémentaires :

- **fasd** mémorise chaque fichier et répertoire visité et les classe par fréquence d'usage.
- **fzf** affiche une liste filtrable en temps réel, avec prévisualisation.

Combinés, ils permettent de rejoindre un répertoire visité il y a deux semaines en tapant deux lettres.

---

### Installation

```bash
~/.local/bin/install-fzf.sh   # télécharge le binaire depuis GitHub Releases
sudo apt install fasd          # via install-paquets.sh
```

Vérification :

```bash
fzf --version    # >= 0.48 requis pour l'intégration shell intégrée
fasd --version
```

---

### Désactivation sur machine lente

Créer ce fichier vide pour court-circuiter le chargement de fasd et fzf :

```bash
mkdir -p ~/.config && touch ~/.config/no_advanced_nav
```

Supprimer le fichier pour réactiver.

---

### Raccourcis clavier fzf dans le shell

Ces raccourcis sont actifs dans tous les shells dès qu'un prompt interactif est ouvert.

| Raccourci | Action |
| --------- | ------ |
| `Ctrl+R` | Recherche floue dans l'historique des commandes |
| `Ctrl+T` | Recherche floue de fichiers — colle le résultat à la position du curseur |
| `Alt+C` | Sélection interactive d'un sous-répertoire — exécute `cd` sur le choix |

---

### Raccourcis dans la fenêtre fzf

Ces touches sont disponibles à l'intérieur de tout sélecteur fzf.

| Touche | Action |
| ------ | ------ |
| `F1` | Prévisualise l'élément sélectionné avec `less` |
| `Ctrl+X` | Ouvre l'élément sélectionné dans `vim` |
| `Ctrl+Y` | Copie l'élément dans le presse-papiers (`xsel`) et ferme |
| `Ctrl+P` | Active ou désactive le panneau de prévisualisation |
| `Alt+A` | Sélectionne tous les éléments |
| `Alt+C` | Désélectionne tous les éléments |
| `PgUp` / `PgDn` | Défilement demi-page dans la liste |
| `Shift+↑` / `Shift+↓` | Défilement dans le panneau de prévisualisation |

---

### Fonctions de navigation fasd + fzf

#### `z` — changer de répertoire

```bash
z                  # liste tous les répertoires visités → sélection interactive
z pro              # filtre sur "pro" → sélection interactive dans les résultats
```

`z` remplace l'alias natif de fasd pour imposer le sélecteur fzf.

#### `v` — ouvrir un fichier récent

```bash
v                  # liste tous les fichiers récents → sélection → ouvre dans $EDITOR
v rapport          # filtre sur "rapport" → sélection → ouvre dans $EDITOR
```

---

### Complétion fzf sur les commandes

La complétion fzf s'active avec `**` suivi de `Tab` après n'importe quelle commande.

```bash
vim **[Tab]            # recherche floue de fichiers, insère le chemin
cd **[Tab]             # recherche floue de répertoires
kill -9 **[Tab]        # recherche floue de processus (PID)
ssh **[Tab]            # recherche floue dans ~/.ssh/config
export **[Tab]         # recherche floue dans les variables d'environnement
```

Le séparateur `**` déclenche le mode complétion fzf. La frappe filtre la liste en temps réel.

---

### Fonctions avancées (zsh uniquement)

Ces fonctions sont disponibles en zsh via autoload.

| Fonction | Usage | Description |
| -------- | ----- | ----------- |
| `cdf` | `cdf motif` | `cd` flou dans l'arborescence du **répertoire courant** |
| `vf` | `vf motif` | Recherche un fichier globalement (`locate` → fzf) et l'ouvre dans vim |
| `c` | `c motif` | `cd` vers un marque-page SQLite (avec fallback `locate` + fzf) |

---

## Section développeur

### Architecture générale

```
fasd  ──► historique pondéré (fichiers + répertoires visités)
fzf   ──► sélecteur interactif (filtrage flou + prévisualisation)
  │
  ├─ seul     : Ctrl+R, Ctrl+T, Alt+C, complétion **[Tab]
  └─ + fasd   : fonctions z et v (navigation pondérée par fréquence)
```

---

### Ordre de chargement

```
Shell démarré
    │
    ├─ bash  ──► .bashrc  ──► rc.d/*.sh  ──► 05-navigation.sh
    │                     └─► .fzf.bash  (PATH + intégration shell)
    │
    └─ zsh   ──► .zshrc   ──► rc.d/*.sh  ──► 05-navigation.sh
                          └─► zshrc.d/   ──► 04_fzf.zsh
                          └─► .fzf.zsh   (PATH + intégration shell)
```

---

### Fichiers de configuration

| Fichier | Shell | Rôle |
| ------- | ----- | ---- |
| `.shellrc/rc.d/05-navigation.sh` | bash + zsh | Point d'entrée principal : sentinel, vérification des binaires, chargement fasd, fonctions `z` et `v` |
| `.shellrc/zshrc.d/04_fzf.zsh` | zsh | Variables d'environnement fzf : commande par défaut, prévisualisation, raccourcis clavier |
| `.fzf.bash` | bash | Intégration shell fzf (`eval "$(fzf --bash)"`) |
| `.fzf.zsh` | zsh | Intégration shell fzf (`eval "$(fzf --zsh)"`) |
| `.zsh/autoload/fuzzy/cdf` | zsh | Autoload : `cd` flou dans le répertoire courant |
| `.zsh/autoload/fuzzy/vf` | zsh | Autoload : recherche globale de fichier + ouverture vim |
| `.zsh/autoload/fuzzy/c` | zsh | Autoload : navigation par marque-pages SQLite |
| `.local/bin/install-fzf.sh` | — | Installation du binaire fzf depuis GitHub Releases |

---

### Détail de `05-navigation.sh`

**Sentinel** — sortie anticipée si `~/.config/no_advanced_nav` existe :

```bash
if [ -f "$HOME/.config/no_advanced_nav" ]; then
    return
fi
```

**Vérification des binaires** — sortie silencieuse si l'un est absent :

```bash
if ! command -v fzf >/dev/null 2>&1 || ! command -v fasd >/dev/null 2>&1; then
    return
fi
```

**Chargement de l'intégration shell fzf** selon le shell courant :

```bash
[ -n "$BASH_VERSION" ] && [ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -n "$ZSH_VERSION"  ] && [ -f ~/.fzf.zsh  ] && source ~/.fzf.zsh
```

**Initialisation fasd** (pose les alias natifs `a`, `s`, `d`, `f`, `sd`, `sf`) :

```bash
eval "$(fasd --init auto)"
```

**Fonctions `z` et `v`** — surchargent les alias fasd natifs pour injecter fzf.

---

### Variables d'environnement fzf (04_fzf.zsh)

| Variable | Valeur | Effet |
| -------- | ------ | ----- |
| `FZF_DEFAULT_COMMAND` | `fdfind -H .` | Utilise `fd` au lieu de `find` (plus rapide, respecte `.gitignore`) |
| `FZF_DEFAULT_OPTS` | `--bind '…'` | Injecte les raccourcis clavier dans tous les appels fzf |
| `FZF_ALT_C_COMMAND` | `fdfind -H --type d` | `Alt+C` liste uniquement les répertoires |
| `FZF_ALT_C_OPTS` | `--preview 'tree -C {}'` | Prévisualisation arborescente au survol |
| `FZF_PREVIEW_ARGS` | `batcat --style=numbers …` | Prévisualisation de fichiers avec coloration syntaxique |

Les raccourcis sont construits via le tableau `FZF_BINDARGS` converti en chaîne CSV avant d'être passé à `--bind`.

---

### Intégration shell fzf (.fzf.bash / .fzf.zsh)

Depuis fzf **0.48**, l'intégration shell (complétion `**[Tab]` + raccourcis `Ctrl+R/T`, `Alt+C`) est intégrée au binaire :

```bash
# bash
eval "$(fzf --bash)"

# zsh
eval "$(fzf --zsh)"
```

Ces deux fichiers remplacent l'ancienne approche basée sur le sous-module git `.fzf/` qui fournissait les scripts `shell/key-bindings.zsh` et `shell/completion.zsh`.

---

### Dépendances

| Outil | Rôle | Optionnel |
| ----- | ---- | --------- |
| `fzf` ≥ 0.48 | Sélecteur interactif | Non |
| `fasd` | Historique pondéré | Non (désactive `z` et `v`) |
| `fdfind` (`fd`) | Recherche de fichiers rapide | Oui — fallback sur `find` |
| `batcat` (`bat`) | Prévisualisation avec coloration | Oui — fallback sur `cat` |
| `tree` | Prévisualisation d'arborescence (`Alt+C`) | Oui |
| `xsel` | Copie presse-papiers (`Ctrl+Y`) | Oui |
| `sqlite3` | Marque-pages pour la fonction `c` | Oui (zsh uniquement) |

---

### Notes de maintenance

- `fasd` n'est plus maintenu depuis 2017 mais reste fonctionnel. Alternative active : `zoxide` (`z` compatible, écrit en Rust).
- La version minimale de fzf est **0.48** pour que `fzf --bash` / `fzf --zsh` fonctionnent. En dessous, l'intégration shell est silencieusement ignorée (guard `command -v fzf`).
- Relancer `~/.local/bin/install-fzf.sh` pour mettre à jour fzf vers la dernière version.
