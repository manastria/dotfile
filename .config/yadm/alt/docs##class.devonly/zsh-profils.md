# Profils zsh — Utilisation et maintenance

## Vue d'ensemble

Le système de profils zsh permet de lancer différentes configurations
d'environnement (prompt powerlevel10k, tmux, oh-my-zsh) via la commande `zenv`
ou des alias sémantiques.

La variable d'environnement `ZSH_PROFILE` détermine le profil chargé par
`.zshrc` au démarrage de zsh. Par défaut, le profil `base` est utilisé.

## Utilisation

### Commande `zenv`

```bash
# Lister les profils disponibles
zenv

# Lancer zsh avec un profil
zenv simple

# Lancer zsh avec un profil dans tmux
zenv simple --tmux
zenv simple -t
```

### Alias prédéfinis

| Alias         | Profil   | tmux | Usage typique                               |
| ------------- | -------- | ---- | ------------------------------------------- |
| `zsh-daily`   | `simple` | oui  | Travail quotidien : prompt p10k lean + tmux |
| `zsh-remote`  | `ssh`    | oui  | Connexions SSH : 8 couleurs + tmux          |
| `zsh-writer`  | `writer` | oui  | Documentation : prompt épuré + tmux         |
| `zsh-minimal` | `base`   | non  | Debug/test rapide : sans oh-my-zsh          |

### Profils disponibles

**Profils spéciaux** (sans powerlevel10k) :

| Profil | Description                                                                |
| ------ | -------------------------------------------------------------------------- |
| `base` | Configuration minimale, sans oh-my-zsh. Charge `~/.zsh/config/zshrc.base`. |
| `omz`  | oh-my-zsh avec le thème par défaut, sans powerlevel10k.                    |

**Profils powerlevel10k** (auto-découverts depuis `~/.zsh/powerlevel10k/`) :

| Profil      | Fichier p10k         | Description                                   |
| ----------- | -------------------- | --------------------------------------------- |
| `simple`    | `p10k.zsh.simple`    | Prompt lean, adapté au quotidien              |
| `powerline` | `p10k.zsh.powerline` | Prompt powerline classique                    |
| `writer`    | `p10k.zsh.writer`    | Prompt épuré pour la rédaction                |
| `ssh`       | `p10k.zsh.ssh`       | Optimisé pour les sessions SSH (8 couleurs)   |
| `full`      | `p10k.zsh.full`      | Configuration complète avec tous les segments |

## Connexion SSH distante

La fonction `zssh` combine SSH + tmux + profil zsh pour se connecter à une
machine distante qui dispose déjà des dotfiles.

### Commande `zssh`

```bash
# Connexion avec le profil par défaut (ssh)
zssh user@host

# Connexion avec un profil spécifique
zssh -e simple user@host

# Avec des options SSH (port, clé, etc.)
zssh -e writer -p 2222 user@host
zssh -e simple -i ~/.ssh/id_ed25519 user@host

# Afficher l'aide
zssh
```

### Comportement

- **Profil par défaut** : `ssh` (optimisé pour 8 couleurs).
- **Session tmux** : `zssh` crée la session `main` ou s'y rattache si elle
  existe déjà (`tmux new-session -A -s main`). En cas de déconnexion SSH,
  relancer `zssh user@host` retrouve la session en cours.
- **Option `-e`** (ou `--profile`) : doit être le **premier argument**, avant
  les options SSH. Tout le reste est passé tel quel à `ssh`.
- **`-e` plutôt que `-p`** : `-p` est déjà utilisé par SSH pour le port.

### Différence avec `zsh-remote`

|                   | `zsh-remote`           | `zssh`                                 |
| ----------------- | ---------------------- | -------------------------------------- |
| Cible             | Machine **locale**     | Machine **distante** (via SSH)         |
| Commande          | `zenv ssh --tmux`      | `ssh -t … tmux new-session -A -s main` |
| Rattachement tmux | Non (nouvelle session) | Oui (`-A` : attache si existante)      |

## Maintenance

### Ajouter un nouveau profil

1. Générer la configuration p10k (ou copier un fichier existant) :

```bash
# Option A : Lancer l'assistant p10k
ZSH_PROFILE=simple zsh -i
p10k configure
# Sauvegarder le fichier généré sous le nouveau nom

# Option B : Copier et adapter un profil existant
cp ~/.zsh/powerlevel10k/p10k.zsh.simple ~/.zsh/powerlevel10k/p10k.zsh.monprofil
# Éditer le fichier selon les besoins
```

2. C'est tout. Le profil est immédiatement disponible via `zenv monprofil`.
   Aucune modification de `.zshrc` ou d'un autre fichier n'est nécessaire.

3. (Optionnel) Ajouter un alias sémantique dans `~/.shellrc/rc.d/zenv.sh` :

```bash
alias zsh-monprofil='zenv monprofil --tmux'
```

### Supprimer un profil

Supprimer le fichier correspondant :

```bash
rm ~/.zsh/powerlevel10k/p10k.zsh.monprofil
```

Si un alias a été défini dans `~/.shellrc/rc.d/zenv.sh`, le supprimer également.

### Modifier un profil existant

Éditer directement le fichier p10k correspondant :

```bash
vim ~/.zsh/powerlevel10k/p10k.zsh.simple
```

Ou relancer l'assistant interactif p10k depuis le profil souhaité, puis
remplacer le fichier.

## Architecture

### Flux de chargement

```
bash/zsh
  └─ zenv <profil> [--tmux]
       └─ TERM=xterm-256color ZSH_PROFILE=<profil> [tmux | zsh -i]
            └─ .zshrc
                 ├─ base  → .zsh/config/zshrc.base
                 ├─ omz   → .zsh/activate.zsh
                 └─ *     → .zsh/activate.zsh (thème p10k)
                           + .zsh/powerlevel10k/p10k.zsh.<profil>
```

### Fichiers impliqués

| Fichier                                | Rôle                                                                         |
| -------------------------------------- | ---------------------------------------------------------------------------- |
| `.zshrc`                               | Point d'entrée. Lit `ZSH_PROFILE` et charge la configuration correspondante. |
| `.shellrc/rc.d/zenv.sh`                | Fonction `zenv` et alias sémantiques. Chargé par bash et zsh.                |
| `.zsh/powerlevel10k/p10k.zsh.<profil>` | Configuration powerlevel10k pour chaque profil.                              |
| `.zsh/activate.zsh`                    | Activation d'oh-my-zsh.                                                      |
| `.zsh/config/zshrc.base`               | Configuration minimale zsh (profil `base`).                                  |

### Convention de nommage

La valeur de `ZSH_PROFILE` correspond exactement au suffixe du fichier p10k :

- `ZSH_PROFILE=simple` charge `.zsh/powerlevel10k/p10k.zsh.simple`
- `ZSH_PROFILE=powerline` charge `.zsh/powerlevel10k/p10k.zsh.powerline`

Les profils `base` et `omz` sont des cas spéciaux traités explicitement dans
`.zshrc` avant la branche par défaut.
