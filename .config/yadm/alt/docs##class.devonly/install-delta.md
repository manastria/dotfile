# `install-delta.sh` — pager de diff Git colorisé

> Script : [`.local/bin/install-delta.sh`](../.local/bin/install-delta.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-delta.sh` installe **delta**, qui remplace le pager de `git diff`/`git show`/`git log -p` par un rendu avec coloration syntaxique, numérotation des lignes et alignement côte à côte. Il télécharge le binaire officiel depuis les releases GitHub du projet et l'installe dans `~/.local/bin`, sans droits root et sans passer par les paquets APT. Une fois le binaire en place, il propose — avec confirmation, jamais en silence — de configurer Git pour l'utiliser réellement (`core.pager`, `interactive.diffFilter`) ; sans cette étape, `delta` reste un binaire installé mais inutilisé par Git. Rien n'est modifié si la réponse est négative, ou si `delta` est déjà le pager configuré. Relancé, le script met à jour le binaire vers la dernière version et ne re-propose pas la configuration Git si elle est déjà en place.

---

## Section utilisateur

### Description

`delta` est un pager de diff : il ne remplace **pas** `git diff` lui-même, il se branche derrière (comme `less`) pour reformater sa sortie. D'où l'étape de configuration Git optionnelle : installer le binaire ne suffit pas à ce que Git s'en serve, contrairement à `bat` (voir `install-bat.sh`) qui fonctionne dès qu'il est dans le `PATH`.

À distinguer d'un simple alias `git diff | delta` : la configuration posée par ce script (`core.pager`, `interactive.diffFilter`) couvre aussi `git add -p`, `git show`, `git log -p` et le mode interactif, pas seulement `git diff` en ligne de commande.

### Ce que la configuration Git change (et ce qu'elle ne change pas)

Avec confirmation de l'utilisateur, le script exécute :

```bash
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
```

- `core.pager` : `delta` devient le pager pour `git diff`, `git show`, `git log -p`, etc.
- `interactive.diffFilter` : `delta --color-only` habille aussi le mode interactif (`git add -p`) sans casser son fonctionnement (pas de pagination dans ce mode).
- `delta.navigate` : navigation entre fichiers modifiés avec `n`/`N` dans le pager.

Le script ne touche **pas** à `merge.conflictstyle` ni `diff.colorMoved`, deux réglages souvent recommandés avec `delta` mais qui changent un comportement Git au-delà du seul rendu visuel — laissés au choix de l'utilisateur, à activer manuellement si souhaité. `delta.side-by-side` (rendu deux colonnes) n'est pas activé non plus par défaut ; le script le signale en fin d'exécution.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `curl` | Interrogation de l'API GitHub et téléchargement de l'archive | `curl --version` |
| `tar` | Extraction de l'archive `.tar.gz` | `tar --version` |
| `git` | Configuration optionnelle du pager (`git config --global`) | `git --version` |

Aucun droit administrateur n'est requis : le script refuse même de s'exécuter en root (installation dans `$HOME/.local/bin`, configuration dans `$HOME/.gitconfig`).

---

### Syntaxe

```
install-delta.sh [-h]
```

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Affiche l'en-tête manpage du script |

---

### Exemples d'utilisation

```bash
bash install-delta.sh
```

Sortie d'une première installation, configuration Git acceptée :

```text
=== Installation de delta ===

[INFO]      Recherche de la dernière version de delta...
[INFO]      Téléchargement de delta 0.19.2 (x86_64-unknown-linux-musl)...
[OK]        delta 0.19.2 installé dans /home/utilisateur/.local/bin/delta.
[OK]        Installation vérifiée : delta 0.19.2
Configurer Git pour utiliser delta (core.pager, interactive.diffFilter) ? [O/n] o
[OK]        Git configuré pour utiliser delta (~/.gitconfig).
[INFO]      Astuce : delta.side-by-side = true affiche le diff sur deux colonnes.

Terminé. Essayer avec : git diff
```

À la relance, si `delta` est déjà le pager configuré, la ligne de confirmation est remplacée par : `Git est déjà configuré pour utiliser delta comme pager.` — sans prompt.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | delta installé (ou déjà à jour) |
| 1 | Erreur d'exécution : téléchargement, extraction, architecture non supportée, binaire introuvable après installation |
| 2 | Erreur d'usage : option inconnue |

---

## Section développeur

### Architecture interne

```text
main()
├── parse_args()           # -h uniquement
├── check_not_root()
├── check_dependencies()   # curl, tar
├── [ delta déjà présent ] ─► info (mise à jour quand même, pas de blocage)
├── detect_arch()          # uname -m → ARCH_TAG
├── fetch_latest_tag()     # API GitHub → LATEST_TAG
├── install_binary()       # téléchargement + extraction + install
├── verify_install()       # delta --version
└── configure_git_pager()  # prompt, idempotent, jamais silencieux
```

---

### Détail des choix techniques

**`grep` sans `-m1` pour lire la réponse de l'API GitHub.** `LATEST_TAG` est capturé par `curl ... | grep '"tag_name"' | sed ...`. Un `grep -m1` semblait naturel (une seule valeur voulue), mais il s'arrête dès la première correspondance trouvée et **ferme le pipe** avant que `curl` ait fini d'écrire toute la réponse — ce qui produit une erreur d'écriture (`curl: (23) Failure writing output to destination`), transformée par `pipefail` en échec de toute l'affectation, alors même que la donnée recherchée avait déjà été récupérée correctement. Sans `-m1`, `grep` lit jusqu'à l'EOF de `curl` avant de rendre la main ; l'API `/releases/latest` ne renvoie de toute façon qu'un seul `tag_name`, donc le résultat est identique — seul le comportement du pipe change. Voir `install-bat.sh` pour la reproduction complète de cette erreur.

**`TMP_DIR` n'est pas `local`.** Il est déclaré dans `install_binary()` mais sans `local`, exprès : le `trap 'rm -rf "$TMP_DIR"' EXIT` posé juste après reste actif pour tout le reste du script, y compris si `verify_install()` ou `configure_git_pager()` échouent plus tard. Une variable `local` aurait quitté sa portée au retour de `install_binary()`, et le trap aurait référencé une variable non définie au moment de se déclencher — `unbound variable` sous `set -u`.

**Pas de build `musl` pour `aarch64`/`arm` chez delta**, contrairement à `bat`. `detect_arch()` retombe sur les variantes `gnu` (liées à la glibc de la machine) pour ces deux architectures, `musl` restant disponible et préféré pour `x86_64`. Vérifié directement sur les assets de la dernière release GitHub du projet (`dandavison/delta`) plutôt que supposé par analogie avec `bat`.

**`configure_git_pager()` ne modifie jamais silencieusement une configuration existante.** Trois cas : `core.pager` déjà à `delta` → rien ne se passe, aucun prompt ; `core.pager` positionné sur autre chose → affiché avant de demander confirmation ; `core.pager` absent → confirmation demandée directement. Dans tous les cas où l'utilisateur répond non (`[nN]`), aucune commande `git config` n'est exécutée — le comportement par défaut au prompt (`[O/n]`) est d'accepter sur simple Entrée, cohérent avec `setup_config()` dans `install-ghostty.sh`.

**Le tag delta n'a pas de préfixe `v`** (`0.19.2`, pas `v0.19.2`), contrairement à `bat`. Le tag renvoyé par l'API GitHub est réutilisé tel quel dans le nom de l'asset et l'URL de téléchargement, sans tentative de normalisation — chaque script respecte la convention réelle de son propre projet plutôt que d'en imposer une commune.

---

### Dépendances externes

| Binaire | Rôle |
| ------- | ---- |
| `curl` | API GitHub (`releases/latest`) et téléchargement de l'archive |
| `tar` | Extraction de l'archive `.tar.gz` |
| `install` (coreutils) | Copie du binaire avec le mode `0755` |
| `git` | Lecture/écriture de la configuration globale (`configure_git_pager()`) |

---

### Points d'extension

**Ajouter une architecture** — compléter le `case` de `detect_arch()`, en vérifiant au préalable dans les assets de la dernière release GitHub (`https://api.github.com/repos/dandavison/delta/releases/latest`) si un build `musl` existe désormais pour cette architecture, avant de retomber sur `gnu`.

**Activer d'autres réglages recommandés avec delta** (`delta.side-by-side`, `merge.conflictstyle = diff3`, `diff.colorMoved`) — ajouter les commandes `git config --global` correspondantes dans `configure_git_pager()`, chacune sous sa propre justification si elle change un comportement Git au-delà du rendu (voir *Ce que la configuration Git change*).

---

### Notes de maintenance

- **La configuration Git posée est volontairement minimale.** Toute extension doit se demander si le réglage ajouté change uniquement l'affichage (sans risque, à ajouter directement) ou un comportement Git plus large comme `merge.conflictstyle` (à laisser en suggestion plutôt qu'en configuration automatique, pour ne pas surprendre un usage Git existant).
- **La structure de l'archive est supposée stable** (`delta-${TAG}-${ARCH_TAG}/delta`) : un changement de nommage côté projet casserait `install_binary()` avec un message explicite (`Binaire delta introuvable dans l'archive téléchargée`), jamais silencieusement.
