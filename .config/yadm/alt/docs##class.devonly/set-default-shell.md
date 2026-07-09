# `set-default-shell.sh` — Gestionnaire de shell par défaut et de profil zsh

---

## Section utilisateur

### Description

`set-default-shell.sh` est un menu interactif qui permet de :

- basculer le shell par défaut de l'utilisateur entre `bash` et `zsh` ;
- choisir le profil zsh actif parmi `base`, `light` et `omz-ascii` (voir
  [zsh-profils.md](zsh-profils.md) pour la liste complète des profils zsh,
  y compris les profils powerlevel10k).

Il fonctionne aussi bien sur un compte local (via `chsh`) que sur un compte
centralisé SSSD/LDAP, où `chsh` échoue silencieusement. Dans ce dernier cas,
le script bascule sur un mécanisme de fichier sentinel lu par `.bashrc`.

---

### Prérequis

| Outil   | Rôle                                  | Vérification     |
| ------- | -------------------------------------- | ----------------- |
| `chsh`  | Changement de shell par défaut (compte local) | `chsh --version` |
| `getent` | Lecture du shell actuel (compte SSSD/LDAP) | `getent --version` |

Aucun de ces outils n'est strictement requis : en leur absence, le script se
rabat sur le mécanisme de sentinel.

---

### Syntaxe

```bash
./set-default-shell.sh
```

Le script est entièrement interactif, sans option en ligne de commande.

---

### Exemples d'utilisation

```bash
# Lancer le menu
~/.local/bin/set-default-shell.sh
```

Menu principal :

```
  1) Passer à zsh comme shell par défaut
  2) Passer à bash comme shell par défaut
  3) Configurer le profil zsh (light / base / omz-ascii)
  q) Quitter
```

Choisir `1` puis répondre `o` à « Configurer aussi le profil zsh ? » permet
d'enchaîner directement le choix du profil après le passage à zsh.

---

### Profils zsh proposés

| Profil       | Description                                                         |
| ------------ | --------------------------------------------------------------------- |
| `light`      | Prompt Pure, sans oh-my-zsh, plugins essentiels (autosuggestions, syntax-highlighting). |
| `base`       | zsh minimal, sans oh-my-zsh ni plugin.                               |
| `omz-ascii`  | oh-my-zsh complet (plugins git, autosuggestions, syntax-highlighting, etc.) avec un thème ASCII/ANSI sans icône Unicode ni police powerline — pensé pour une console Linux (TTY, `Ctrl+Alt+F1`) dont le jeu de caractères est limité. |

---

### Codes de retour

Le script utilise `set -e` : toute commande en échec interrompt l'exécution.
Un choix de menu invalide affiche un avertissement (`warn`) et se termine
sans modification (le choix `1`/`2` du menu principal sort avec le code `1`).

---

## Section développeur

### Architecture interne

Le script s'articule autour de deux mécanismes de sentinel indépendants,
tous deux lus par `.bashrc` / `.zshrc` au démarrage du shell :

| Fichier            | Lu par                | Rôle                                                              |
| ------------------ | ---------------------- | ------------------------------------------------------------------ |
| `~/.zsh-force`     | `.bashrc`              | Si présent, `bash` lance `zsh` automatiquement (contournement SSSD/LDAP où `chsh` est inopérant). |
| `~/.zsh-profile`   | `.zshrc`               | Contient le nom du profil actif (`base`, `light` ou `omz-ascii`), lu si `ZSH_PROFILE` n'est pas déjà positionnée dans l'environnement. |
| `~/.zsh-light` *(legacy)* | `.zshrc`        | Ancien sentinel booléen équivalent à `ZSH_PROFILE=light`. Conservé en lecture pour rétrocompatibilité ; le script n'écrit plus jamais ce fichier (il le supprime dès qu'un profil est choisi via le menu). |

Fonctions principales :

- `_current_shell()` : lit le shell par défaut via `getent passwd` (fallback
  `/etc/passwd`).
- `_is_sssd_user()` : détecte un compte centralisé (absent de `/etc/passwd`).
- `_try_chsh()` : tente `chsh -s <shell>`, retourne un code d'échec exploitable
  plutôt que de faire échouer tout le script.
- `_switch_to_zsh()` / `_switch_to_bash()` : basculent le shell, avec repli sur
  le sentinel `~/.zsh-force` si `chsh` échoue ou si le compte est SSSD.
- `_current_zsh_profile()` : résout le profil actif en suivant l'ordre de
  priorité `~/.zsh-profile` → `~/.zsh-light` (legacy) → `base`.
- `_configure_zsh_profile()` : affiche le sous-menu des 3 profils, écrit le
  choix dans `~/.zsh-profile` et nettoie `~/.zsh-light` s'il existe.

### Tier sudo appliqué

**Tier 3** : le script refuse explicitement de s'exécuter en `root`
(`if [ "$(id -u)" -eq 0 ]`). Il ne manipule que des fichiers sous `$HOME`
(`~/.zsh-force`, `~/.zsh-profile`) et l'éventuel changement de shell via
`chsh`, qui s'exécute dans le contexte de l'utilisateur courant.

### Points d'extension

- **Ajouter un profil zsh au menu** : ajouter une entrée numérotée dans
  `_configure_zsh_profile()` et le décrire dans le tableau d'en-tête ; le
  profil doit déjà exister côté `.zshrc` (voir
  [zsh-profils.md](zsh-profils.md#maintenance) pour la procédure côté
  `.zshrc`/thème).
- **Autre mécanisme de compte centralisé** : `_is_sssd_user()` teste
  uniquement l'absence de l'entrée dans `/etc/passwd` ; un environnement
  NIS ou Winbind pourrait nécessiter une détection différente.
