# `set-default-shell.sh` — Shell par défaut et profil zsh

> Script : [`.local/bin/set-default-shell.sh`](../.local/bin/set-default-shell.sh)
> Guide associé : [zsh-profils.md](zsh-profils.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`set-default-shell.sh` est le menu interactif qui bascule le shell de connexion entre `bash` et `zsh`, et choisit le profil zsh actif parmi `light`, `base` et `omz-ascii`. Il ne prend aucune option : on le lance, il affiche l'état courant (shell par défaut, sentinel, profil) et on répond au menu. Sur un compte local il passe par `chsh` ; sur un compte centralisé SSSD/LDAP, où `chsh` est inopérant, il crée le fichier `~/.zsh-force` que `.bashrc` détecte pour lancer `zsh` — ce repli est automatique, sans rien à décider. Le profil retenu est écrit dans `~/.zsh-profile`, que `.zshrc` lit sauf si la variable `ZSH_PROFILE` est déjà positionnée dans l'environnement. Il n'installe pas zsh, et son menu ne propose que trois des profils reconnus par `.zshrc` : les variantes powerlevel10k se choisissent par `ZSH_PROFILE`. Comme toujours, les changements ne prennent effet qu'à la prochaine ouverture de terminal.

---

## Section utilisateur

### Description

`set-default-shell.sh` est un menu interactif qui permet de :

- basculer le shell par défaut de l'utilisateur entre `bash` et `zsh` ;
- choisir le profil zsh actif parmi `light`, `base` et `omz-ascii`.

Il fonctionne aussi bien sur un compte local (via `chsh`) que sur un compte centralisé SSSD/LDAP, où `chsh` échoue. Dans ce dernier cas, le script bascule sur un mécanisme de fichier sentinel lu par `.bashrc`, sans que l'utilisateur ait à choisir.

Ce qu'il **ne fait pas** :

- il n'installe pas `zsh` (l'option 1 s'arrête si `/bin/zsh` est absent) ;
- il ne couvre pas tous les profils gérés par `.zshrc` — `omz` et les variantes powerlevel10k se sélectionnent via la variable `ZSH_PROFILE` ou en écrivant `~/.zsh-profile` à la main. Voir [zsh-profils.md](zsh-profils.md).

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `zsh` | **Requis** pour l'option 1 : le script le cherche dans le `PATH` | `command -v zsh` |
| `chsh` (passwd) | Changement de shell par défaut sur un compte local | `chsh --version` |
| `getent` (libc-bin) | Lecture du shell actuel dans la base passwd | `getent passwd "$USER"` |

`chsh` et `getent` ne sont pas strictement requis : en leur absence, ou en cas d'échec, le script se rabat sur le sentinel `~/.zsh-force`.

Le script **refuse de s'exécuter en root** (Tier 3) : il n'écrit que dans `$HOME`.

---

### Syntaxe

```bash
set-default-shell.sh
```

Entièrement interactif : aucune option, aucun argument, pas de `-h`. Le script traite **un seul choix** puis se termine ; pour enchaîner deux opérations, le relancer (à l'exception du profil zsh, proposé automatiquement après un passage à zsh).

---

### Exemples d'utilisation

```bash
# Lancer le menu
~/.local/bin/set-default-shell.sh
```

Sortie réelle :

```
═══════════════════════════════════════════
    Gestionnaire de shell par défaut
═══════════════════════════════════════════

  Utilisateur       : jpdemory
  Shell par défaut  : /usr/bin/zsh
  Sentinel ~/.zsh-force : inactif
  Profil zsh        : light

  1) Passer à zsh comme shell par défaut
  2) Passer à bash comme shell par défaut
  3) Configurer le profil zsh (light / base / omz-ascii)
  q) Quitter

  Votre choix :
```

Choisir `1` puis répondre `o` à « Configurer aussi le profil zsh ? » enchaîne directement sur le sous-menu des profils :

```
  Profil zsh
  ─────────────────────────────────────────────
  • light     : prompt Pure + plugins essentiels
                (recommandé sans oh-my-zsh)
  • base      : zsh minimal sans plugins
  • omz-ascii : oh-my-zsh (plugins complets) avec un
                prompt ASCII/ANSI sans icônes Unicode
                (recommandé en console Linux, Ctrl+Alt+F1)
  ─────────────────────────────────────────────
  Profil actif : light

  1) Activer le profil light
  2) Activer le profil base
  3) Activer le profil omz-ascii
  r) Retour
```

Toute action se termine par le rappel :

```
[INFO]      Fermez et rouvrez votre terminal pour appliquer les changements.
```

---

### Profils zsh proposés

| Profil | Description |
| ------ | ----------- |
| `light` | Prompt Pure, sans oh-my-zsh, plugins essentiels (autosuggestions, syntax-highlighting) |
| `base` | zsh minimal, sans oh-my-zsh ni plugin |
| `omz-ascii` | oh-my-zsh complet avec un thème ASCII/ANSI sans icône Unicode ni police powerline — pensé pour une console Linux (TTY, `Ctrl+Alt+F1`) |

`.zshrc` en reconnaît davantage (`omz`, et tout suffixe correspondant à un fichier `p10k.zsh.<profil>`), mais ils ne figurent pas dans ce menu.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Action effectuée, ou sortie par `q`. Un choix invalide **dans le sous-menu des profils** revient au fil normal et sort aussi en `0` |
| `1` | Choix invalide au menu principal ; lancement en root ; `zsh` absent alors que l'option 1 est demandée ; toute commande en échec (`set -e`) |

---

## Section développeur

### Architecture interne

Script linéaire : les fonctions sont définies, puis `_print_status` s'affiche, une lecture au clavier, et un `case` déclenche l'action. Pas de `main()`.

Deux sentinels, tous deux lus au démarrage du shell :

| Fichier | Lu par | Rôle |
| ------- | ------ | ---- |
| `~/.zsh-force` | `.bashrc` | S'il existe et que `zsh` est trouvable dans le `PATH`, `bash` s'efface par un `exec zsh -l` — contournement du cas SSSD/LDAP où `chsh` est inopérant |
| `~/.zsh-profile` | `.zshrc` | Nom du profil actif, lu seulement si `ZSH_PROFILE` n'est pas déjà dans l'environnement |
| `~/.zsh-light` *(hérité)* | `.zshrc` | Ancien sentinel booléen valant `ZSH_PROFILE=light`. Encore lu pour la rétrocompatibilité, mais le script ne l'écrit plus et le supprime dès qu'un profil est choisi |

Fonctions :

- `_canonical()` / `_same_shell()` — normalisent les chemins avant comparaison (`/bin/bash` et `/usr/bin/bash` sont le même shell) ;
- `_shell_bin()` — emplacement réel de `zsh` ou `bash` via `command -v`, jamais un chemin en dur ;
- `_is_login_shell()` — vérifie la présence du shell dans `/etc/shells`, que `chsh` exige ;
- `_current_shell()` — shell par défaut via `getent passwd`, avec repli sur `/etc/passwd` puis `(inconnu)` ;
- `_is_sssd_user()` — compte centralisé, détecté par l'absence de l'entrée dans `/etc/passwd` ;
- `_try_chsh()` — tente `chsh -s <shell>` et renvoie un code exploitable au lieu de faire échouer le script ;
- `_switch_to_zsh()` / `_switch_to_bash()` — bascule, avec repli sur `~/.zsh-force` ;
- `_current_zsh_profile()` — `~/.zsh-profile` → `~/.zsh-light` (hérité) → `base` ;
- `_configure_zsh_profile()` — sous-menu, écrit `~/.zsh-profile`, nettoie `~/.zsh-light` ;
- `_print_status()` — encadré d'état et menu principal.

---

### Détail des choix techniques

**Le sentinel plutôt que `chsh` seul.** Sur un compte SSSD/LDAP, la base passwd n'est pas modifiable localement : `chsh` échoue, parfois sans message clair. Comme `bash` reste le shell imposé par l'annuaire, la seule prise possible est `.bashrc`, qui lance `zsh` quand `~/.zsh-force` existe. Le script détecte le cas **avant** d'essayer (`_is_sssd_user`), et sinon rattrape l'échec de `chsh` par le même repli : l'utilisateur obtient zsh dans les deux cas.

**`_try_chsh` appelé dans un `if`.** Le script tourne sous `set -e` : un `chsh` en échec (mot de passe erroné, PAM restrictif) tuerait le script au milieu d'une bascule. Encapsuler l'appel dans une fonction testée par `if` neutralise `set -e` pour cette commande précise, ce qui laisse le repli s'exécuter.

**`_switch_to_bash` supprime le sentinel d'abord.** Sans cela, `chsh -s /bin/bash` réussirait mais `.bashrc` relancerait `zsh` immédiatement : l'utilisateur croirait la bascule sans effet. La suppression du sentinel est donc faite en premier, et suffit à elle seule sur un compte centralisé.

**`echo -n` pour écrire le profil.** `~/.zsh-profile` est lu par `.zshrc` avec `$(<fichier)`, qui supprime les sauts de ligne finaux : le fichier reste lisible qu'il ait été écrit par le script ou à la main avec un `echo` ordinaire.

**Chemins de shells résolus, jamais écrits en dur.** `/bin/zsh` et `/usr/bin/zsh` désignent le même binaire sur une distribution à `/usr` fusionné, mais `getent` renvoie l'un ou l'autre selon la façon dont le compte a été créé. Le script cherche donc le binaire avec `command -v` et compare les chemins **canonalisés** (`realpath -m`) : sans cela, `_switch_to_bash` croyait devoir agir alors que bash était déjà le shell par défaut, et redemandait le mot de passe pour un `chsh` sans effet.

**Sortie capturée, jamais testée à travers un pipeline.** Dans `getent … | cut …`, le code de retour est celui de `cut`, qui vaut `0` même quand `getent` n'a rien trouvé. Un enchaînement `getent | cut || grep | cut || echo "(inconnu)"` ne se replie donc jamais et renvoie une chaîne vide. `_current_shell()` capture le résultat, puis teste s'il est vide — même correction que dans [yadm-check-submodules.md](yadm-check-submodules.md).

**Contrôle de `/etc/shells` avant `chsh`.** `chsh` refuse tout shell absent de ce fichier, avec un message peu parlant. Le script prévient et enchaîne sur le sentinel plutôt que de laisser l'utilisateur devant un échec obscur. Si `/etc/shells` est illisible, le contrôle est neutre : c'est `chsh` qui tranche.

**Écriture du profil, pas de la variable.** Le script n'exporte jamais `ZSH_PROFILE` : la variable d'environnement reste prioritaire sur le fichier (`.zshrc` ne consulte `~/.zsh-profile` que si elle est vide). Un profil forcé pour une session (`ZSH_PROFILE=base zsh`) n'est donc pas écrasé par le dernier choix du menu.

---

### Dépendances externes

| Binaire | Fonctionnalité qui l'impose |
| ------- | --------------------------- |
| `bash` 3.2 | `[[ ]]`, `=~` sur la réponse `o/N` |
| `getent` (libc-bin) | lecture du shell dans la base passwd, y compris pour un compte non local |
| `chsh` (paquet `passwd`) | changement du shell de connexion sur un compte local |
| `coreutils` | `cut`, `cat`, `touch`, `rm` |
| `grep` | détection du compte local dans `/etc/passwd` |

---

### Tier sudo appliqué

**Tier 3** — le script refuse `root` (`if [ "$(id -u)" -eq 0 ]`, puis `die`). Il n'écrit que dans `$HOME` (`~/.zsh-force`, `~/.zsh-profile`) ; `chsh` demande lui-même le mot de passe et s'applique au compte courant. Lancé avec `sudo`, il modifierait le shell de root et créerait des sentinels dans `/root`.

---

### Points d'extension

**Ajouter un profil au menu** — ajouter une entrée numérotée dans `_configure_zsh_profile()`, le décrire dans l'encadré, et vérifier que `.zshrc` sait le traiter :

```bash
    case "${profile_choice}" in
        1) profile_name="light" ;;
        ...
        4) profile_name="omz" ;;
```

**Autre mécanisme de compte centralisé** — `_is_sssd_user()` ne teste que l'absence de l'entrée dans `/etc/passwd` ; NIS ou Winbind demanderaient une détection différente.

**Mode non interactif** — le script n'accepte aucun argument. Pour l'appeler depuis un script d'installation, écrire directement les sentinels :

```bash
echo -n "light" > ~/.zsh-profile
touch ~/.zsh-force        # si chsh est inopérant
```

---

### Notes de maintenance

- **Chemins de shells (corrigé).** Le script comparait `"${cur}" != "/bin/bash"` avec un chemin en dur, alors que `getent` renvoie `/usr/bin/bash` sur une distribution à `/usr` fusionné : il relançait un `chsh` inutile, mot de passe à la clé. Résolu par `_shell_bin` + `_same_shell`. Le même chemin en dur existait dans `.bashrc` (`[ -x /bin/zsh ]`), où il aurait rendu le sentinel silencieusement inerte sur une distribution sans `/bin/zsh` ; il utilise désormais `command -v zsh`.
- **Repli de `_current_shell()` (corrigé).** Le repli sur `/etc/passwd` ne se déclenchait jamais et la fonction pouvait renvoyer une chaîne vide, faute de pouvoir tester le code de retour d'un pipeline. La sortie est maintenant capturée puis testée. Ne pas réintroduire de `cmd | cut || repli` dans ce script.
- **Un seul choix par exécution.** Le menu principal n'est pas dans une boucle : après une action, le script affiche le rappel de redémarrage et se termine. C'est volontaire (chaque action demande de rouvrir le terminal), mais surprend qui s'attend à revenir au menu.
- **Écart avec le squelette du dépôt.** `#!/bin/bash` + `set -e`, pas d'en-tête manpage complet, pas de `main()`, pas de `-h` — script antérieur aux conventions de [CLAUDE.md](../CLAUDE.md).
- **Le menu ne reflète pas `.zshrc`.** Ajouter un profil dans `.zshrc` ne le fait pas apparaître ici : les deux listes sont indépendantes et doivent être tenues à jour ensemble.
