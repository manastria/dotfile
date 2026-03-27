# Navigation interactive — zoxide + fzf

Ce document décrit le système de navigation rapide dans le shell, combinant **zoxide** (historique pondéré des répertoires visités) et **fzf** (sélecteur interactif flou).

---

## Section utilisateur

### Description

zoxide et fzf transforment la navigation shell en deux axes complémentaires :

- **zoxide** mémorise chaque répertoire visité et les classe par fréquence d'usage (algorithme *frecency* : fréquence + récence).
- **fzf** affiche une liste filtrable en temps réel, avec prévisualisation.

Combinés, ils permettent de rejoindre un répertoire visité il y a deux semaines en tapant deux lettres.

---

### Installation

```bash
~/.local/bin/install-fzf.sh      # binaire fzf depuis GitHub Releases
~/.local/bin/install-zoxide.sh   # binaire zoxide depuis GitHub Releases
```

Vérification :

```bash
fzf --version      # >= 0.48 requis
zoxide --version   # >= 0.9 recommandé
```

---

### Désactivation sur machine lente

Créer ce fichier vide pour court-circuiter le chargement de zoxide et fzf :

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

### Navigation avec zoxide

#### `z` — saut rapide

```bash
z pro              # saute vers le répertoire fréquent contenant "pro"
z doc conf         # filtre sur plusieurs termes
z -                # retourne au répertoire précédent
```

zoxide choisit automatiquement le répertoire le plus probable. S'il se trompe, utiliser `zi`.

#### `zi` — sélection interactive

```bash
zi                 # liste tous les répertoires connus → sélection fzf
zi pro             # pré-filtre sur "pro" → sélection fzf
```

`zi` ouvre le sélecteur fzf avec les répertoires classés par score de fréquence.

---

### Fonction `v` — ouvrir un fichier

```bash
v                  # recherche floue dans le répertoire courant → ouvre dans $EDITOR
v rapport          # pré-filtre sur "rapport" → sélection → ouvre dans $EDITOR
```

La recherche descend récursivement depuis le répertoire courant, y compris les dossiers cachés.

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
zoxide ──► historique pondéré (répertoires visités, algo frecency)
fzf    ──► sélecteur interactif (filtrage flou + prévisualisation)
  │
  ├─ seul      : Ctrl+R, Ctrl+T, Alt+C, complétion **[Tab]
  ├─ + zoxide  : z (saut auto), zi (sélection interactive)
  └─ + fd      : v (recherche de fichiers dans le répertoire courant)
```

---

### Ordre de chargement

```
Shell démarré
    │
    ├─ bash  ──► .bashrc  ──► rc.d/*.sh  ──► 05-navigation.sh
    │                                          ├─ source .fzf.bash
    │                                          ├─ eval "$(zoxide init bash)"
    │                                          └─ function v()
    │
    └─ zsh   ──► .zshrc   ──► rc.d/*.sh  ──► 05-navigation.sh
                          └─► zshrc.d/   ──► 04_fzf.zsh
                                             ├─ source .fzf.zsh
                                             ├─ eval "$(zoxide init zsh)"
                                             └─ function v()
```

---

### Fichiers de configuration

| Fichier | Shell | Rôle |
| ------- | ----- | ---- |
| `.shellrc/rc.d/05-navigation.sh` | bash + zsh | Point d'entrée : sentinel, vérification des binaires, init zoxide, fonction `v` |
| `.shellrc/zshrc.d/04_fzf.zsh` | zsh | Variables d'environnement fzf : commande par défaut, prévisualisation, raccourcis clavier |
| `.fzf.bash` | bash | Intégration shell fzf (`eval "$(fzf --bash)"`) |
| `.fzf.zsh` | zsh | Intégration shell fzf (`eval "$(fzf --zsh)"`) |
| `.zsh/autoload/fuzzy/cdf` | zsh | Autoload : `cd` flou dans le répertoire courant |
| `.zsh/autoload/fuzzy/vf` | zsh | Autoload : recherche globale de fichier + ouverture vim |
| `.zsh/autoload/fuzzy/c` | zsh | Autoload : navigation par marque-pages SQLite |
| `.local/bin/install-fzf.sh` | — | Installation du binaire fzf depuis GitHub Releases |
| `.local/bin/install-zoxide.sh` | — | Installation du binaire zoxide depuis GitHub Releases |

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
if ! command -v fzf >/dev/null 2>&1 || ! command -v zoxide >/dev/null 2>&1; then
    return
fi
```

**Intégration shell fzf** selon le shell courant (sourcing de `.fzf.bash` ou `.fzf.zsh`).

**Initialisation zoxide** (pose les commandes `z` et `zi`) :

```bash
[ -n "$BASH_VERSION" ] && eval "$(zoxide init bash)"
[ -n "$ZSH_VERSION"  ] && eval "$(zoxide init zsh)"
```

**Fonction `v`** — recherche fzf + fd dans le répertoire courant :

```bash
v() {
    local file
    file="$(fdfind -H --type f . | fzf --height 40% --reverse --query="${*:-}" --select-1 --exit-0)"
    [ -n "$file" ] && ${EDITOR:-vim} "$file"
}
```

---

### Variables d'environnement fzf (`04_fzf.zsh`)

| Variable | Valeur | Effet |
| -------- | ------ | ----- |
| `FZF_DEFAULT_COMMAND` | `fdfind -H .` | Utilise `fd` au lieu de `find` (plus rapide, respecte `.gitignore`) |
| `FZF_DEFAULT_OPTS` | `--bind '…'` | Injecte les raccourcis clavier dans tous les appels fzf |
| `FZF_ALT_C_COMMAND` | `fdfind -H --type d` | `Alt+C` liste uniquement les répertoires |
| `FZF_ALT_C_OPTS` | `--preview 'tree -C {}'` | Prévisualisation arborescente au survol |
| `FZF_PREVIEW_ARGS` | `batcat --style=numbers …` | Prévisualisation de fichiers avec coloration syntaxique |

---

### Intégration shell fzf (`.fzf.bash` / `.fzf.zsh`)

Depuis fzf **0.48**, l'intégration shell (complétion `**[Tab]` + raccourcis `Ctrl+R/T`, `Alt+C`) est intégrée au binaire :

```bash
eval "$(fzf --bash)"   # bash
eval "$(fzf --zsh)"    # zsh
```

---

### Dépendances

| Outil | Rôle | Optionnel |
| ----- | ---- | --------- |
| `fzf` ≥ 0.48 | Sélecteur interactif | Non |
| `zoxide` ≥ 0.9 | Historique pondéré des répertoires | Non (désactive `z`, `zi` et `v`) |
| `fdfind` (`fd`) | Source pour `v` et `FZF_DEFAULT_COMMAND` | Oui — `v` devient inopérante sans lui |
| `batcat` (`bat`) | Prévisualisation avec coloration | Oui |
| `tree` | Prévisualisation arborescente (`Alt+C`) | Oui |
| `xsel` | Copie presse-papiers (`Ctrl+Y`) | Oui |
| `sqlite3` | Marque-pages pour la fonction `c` | Oui (zsh uniquement) |

---

### Notes de maintenance

- zoxide maintient sa base de données dans `~/.local/share/zoxide/db.zo`. La supprimer repart d'un historique vide.
- Relancer `~/.local/bin/install-zoxide.sh` pour mettre à jour vers la dernière version.
- Relancer `~/.local/bin/install-fzf.sh` pour mettre à jour fzf.
- La version minimale de fzf est **0.48** pour que `fzf --bash` / `fzf --zsh` fonctionnent. En dessous, l'intégration shell est silencieusement ignorée.
- `zi` requiert fzf installé et accessible dans le `PATH` — zoxide le détecte automatiquement.
