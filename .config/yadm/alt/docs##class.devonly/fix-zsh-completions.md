# fix-zsh-completions.sh

> Script : [`.local/bin/fix-zsh-completions.sh`](../.local/bin/fix-zsh-completions.sh)

---

# Section utilisateur

## Description

Répare les fichiers de complétion zsh cassés qui font échouer `compinit` au démarrage du shell :

```
compinit:527: no such file or directory: /usr/share/zsh/vendor-completions/_docker
```

`compinit` lit **tous** les fichiers de chaque répertoire de `$fpath`. Un lien symbolique mort y suffit à produire cette erreur à chaque ouverture de shell — sans autre conséquence que le bruit, mais à chaque prompt.

Le cas typique est **WSL + Docker Desktop** : l'intégration WSL installe `_docker` sous forme de lien vers `/mnt/wsl/docker-desktop/cli-tools/…`, un point de montage qui n'existe **que lorsque Docker Desktop tourne côté Windows**. Docker Desktop arrêté, le lien pointe dans le vide.

Le script traite deux situations :

| Situation | Action |
| --------- | ------ |
| Lien symbolique **mort** (cible introuvable) | Suppression du lien |
| Lien vers un **montage volatile** (`/mnt`, `/media`, `/run/media`) dont la cible est lisible | Remplacement par une **copie réelle** (« gel »), pour que la complétion survive au démontage |

Le gel est le correctif durable : une fois la copie en place, arrêter Docker Desktop ne casse plus rien. Contrepartie — c'est un instantané, qui ne suit plus les mises à jour de l'outil. Relancer le script montage présent rafraîchit la copie.

À ne pas confondre avec les autres scripts du dépôt : [`install-docker.sh`](../.local/bin/install-docker.sh) installe le moteur Docker natif sous Linux ; ce script-ci ne touche qu'aux fichiers de complétion zsh.

## Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 3.2 | tableaux, substitution de processus `< <(…)` | `bash --version` |
| `find` (findutils) | inspection des répertoires | `find --version` |
| `sudo` | modification des répertoires système | `sudo -v` |
| `install`, `readlink` (coreutils) | copie et résolution des liens | `install --version` |

Le script **refuse de tourner en root** : il peut écrire dans `~/.zsh/completions`, où des fichiers appartenant à root seraient un piège. Les répertoires système sont élevés au cas par cas, uniquement quand c'est nécessaire.

## Syntaxe

```bash
fix-zsh-completions.sh [-n] [-y] [--no-freeze] [DIR]... [-h]
```

| Option / argument | Défaut | Description |
| ----------------- | ------ | ----------- |
| `DIR` (répétable) | — | Répertoire de complétion supplémentaire à inspecter, en plus des répertoires par défaut |
| `-n`, `--dry-run` | désactivé | Montre ce qui serait fait, sans rien modifier |
| `-y`, `--yes` | désactivé | Ne pose aucune question (mode non interactif) |
| `--no-freeze` | gel activé | Ne traite que les liens morts ; laisse intacts les liens vers un montage volatile |
| `-h`, `--help` | — | Affiche l'en-tête du script |

Répertoires inspectés par défaut, quand ils existent :

- `/usr/share/zsh/vendor-completions`
- `/usr/share/zsh/site-functions`
- `/usr/local/share/zsh/site-functions`
- `~/.zsh/completions`

## Exemples d'utilisation

```bash
# Diagnostic : que trouverait le script ?
fix-zsh-completions.sh --dry-run

# Docker Desktop arrêté : supprimer le lien mort
fix-zsh-completions.sh

# Docker Desktop démarré : figer les complétions (correctif durable)
fix-zsh-completions.sh -y

# Inspecter en plus un répertoire ajouté à fpath par un plugin
fix-zsh-completions.sh ~/.zsh/custom/plugins/zsh-completions/src
```

Sortie réelle, Docker Desktop arrêté :

```
=== Réparation des complétions zsh ===

[INFO]      Inspection des répertoires de complétion...
[ATTENTION] Lien mort : /usr/share/zsh/vendor-completions/_docker → /mnt/wsl/docker-desktop/cli-tools/usr/share/zsh/vendor-completions/_docker
  Supprimer ce lien ? [o/N] o
[OK]          Supprimé.
[INFO]        La cible est sur un montage volatile. Relancez ce script
[INFO]        montage présent pour figer une copie réutilisable.
[INFO]      Rechargez un shell pour vérifier : exec zsh
[INFO]      Si l'erreur persiste, videz le cache de compinit : rm -f ~/.zcompdump*
```

Rien à faire :

```
=== Réparation des complétions zsh ===

[INFO]      Inspection des répertoires de complétion...
[OK]        Aucun lien de complétion à réparer.
```

## Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Rien à faire, ou réparations effectuées |
| 1 | Erreur d'exécution (lancement en root, copie ou suppression impossible) |
| 2 | Erreur d'usage : option inconnue, répertoire introuvable |

---

# Section développeur

## Architecture interne

`main()` enchaîne :

1. `parse_args` — options et répertoires supplémentaires ; valide l'existence des `DIR`.
2. `check_not_root` — refus si `id -u` vaut 0.
3. `mktemp -d` + `trap … EXIT` — répertoire temporaire pour les instantanés.
4. `scan` — parcourt les répertoires et remplit deux tableaux : `DEAD_LINKS` (cible introuvable) et `VOLATILE_LINKS` (cible lisible sous un préfixe volatile).
5. Sortie anticipée si les deux tableaux pertinents sont vides.
6. `remove_dead_links` — suppression, avec confirmation.
7. `freeze_volatile_links` — copie temporaire, suppression du lien, `install` de la copie.

`is_volatile`, `confirm` et `run_privileged` sont les utilitaires partagés par les deux phases de réparation.

## Détail des choix techniques

**Pourquoi supprimer, et pas renommer.** `compinit` lit tout fichier du répertoire sauf `*~` et `*.zwc`. Renommer `_docker` en `_docker.disabled` ne résout donc rien : le lien mort serait toujours lu, et l'erreur persisterait. Seules la suppression et le remplacement par un fichier réel fonctionnent.

**Pourquoi geler par défaut.** Docker Desktop reprovisionne ses liens à chaque démarrage de l'intégration WSL. Supprimer le lien mort règle le symptôme du jour, mais le problème revient au cycle suivant (démarrage puis arrêt de Docker Desktop). Remplacer le lien par une copie réelle rompt la dépendance au montage. `--no-freeze` reste disponible pour qui préfère suivre strictement le fichier fourni par Docker.

**Copie temporaire avant suppression.** Dans `freeze_volatile_links`, le fichier est d'abord copié dans `$TMP_DIR`, puis seulement le lien est supprimé. Si le montage disparaît pendant l'opération (Docker Desktop qu'on arrête au mauvais moment), on ne se retrouve pas avec ni lien ni fichier.

**Ne jamais écrire « à travers » le lien.** `install -m 0644 source lien` suivrait le lien symbolique et écrirait dans la cible, c'est-à-dire dans l'arborescence de Docker Desktop. D'où le `rm -f` préalable, systématique.

**Élévation sélective (`run_privileged`).** Le script suit le Tier 2 de [CLAUDE.md](../CLAUDE.md) : il tourne en utilisateur, et n'appelle `sudo` que pour les répertoires dont il n'a pas l'écriture (`[ -w "$dir" ]`). Un lien cassé dans `~/.zsh/completions` est donc réparé sans mot de passe, et la copie créée appartient bien à l'utilisateur. Le refus de root (`check_not_root`) est la contrepartie obligatoire : lancé avec `sudo`, le script créerait des fichiers root dans `$HOME`.

**Détection du lien mort.** `find -maxdepth 1 -type l` liste les liens ; `[ ! -e "$link" ]` (qui *suit* le lien) distingue les morts. `find -xtype l` aurait fait la même chose, mais le test explicite permet de récupérer au passage la cible avec `readlink -f` pour le classement `is_volatile`.

**`-maxdepth 1`.** `compinit` ne descend pas dans les sous-répertoires des entrées de `$fpath` ; les inspecter produirait des faux positifs sans rapport avec l'erreur traitée.

## Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 3.2 | tableaux, `read -r -d ''`, substitution de processus |
| `findutils` | — | `find -maxdepth -type l -print0` |
| `coreutils` | — | `readlink -f`, `install -m`, `mktemp -d` |
| `sudo` | — | écriture dans `/usr/share/zsh/…` |

## Points d'extension

**Ajouter un répertoire par défaut** — compléter le tableau `DEFAULT_DIRS` ; les répertoires inexistants sont ignorés :

```bash
readonly DEFAULT_DIRS=(
    /usr/share/zsh/vendor-completions
    …
    /opt/homebrew/share/zsh/site-functions
)
```

**Considérer un autre montage comme volatile** — par exemple un partage réseau monté à la demande :

```bash
readonly VOLATILE_PREFIXES=(/mnt/ /media/ /run/media/ /net/)
```

**Traiter d'autres répertoires de `$fpath`** — les passer en argument plutôt que d'éditer le script :

```bash
fix-zsh-completions.sh $(zsh -f -c 'print -l $fpath')
```

## Notes de maintenance

- **Le gel fige une version.** Après une mise à jour majeure de Docker Desktop, la complétion figée peut ignorer de nouvelles sous-commandes. Relancer le script Docker Desktop démarré : le lien recréé par l'intégration WSL sera de nouveau gelé, avec le contenu à jour.
- **Le lien peut réapparaître.** L'intégration WSL de Docker Desktop reprovisionne `/usr/share/zsh/vendor-completions/_docker`. Un `_docker` gelé peut donc être remplacé par un nouveau lien symbolique : le script est prévu pour être relancé, il est idempotent.
- **Cache `compinit`.** Après réparation, un `~/.zcompdump` obsolète peut continuer de référencer le fichier disparu. Le script le rappelle en fin d'exécution : `rm -f ~/.zcompdump*`.
- **Pas de restauration.** Un lien supprimé n'est pas sauvegardé. C'est assumé : il s'agit d'un lien mort, sans contenu à préserver.
