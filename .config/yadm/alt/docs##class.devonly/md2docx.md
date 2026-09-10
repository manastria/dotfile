# `md2docx.sh` — Conversion Markdown vers .docx (profil bts-sio)

> Script : [`.local/bin/md2docx.sh`](../.local/bin/md2docx.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`md2docx.sh` convertit un fichier Markdown en document Word `.docx` avec pandoc, en appliquant systématiquement le defaults file **bts-sio** (`-d bts-sio`) qui porte la mise en forme et le template de référence du cours. Il suffit de donner le fichier `.md` en argument : le nom de sortie est déduit automatiquement en remplaçant l'extension `.md` par `.docx`, sans retaper la commande `pandoc -d bts-sio -o ... ...` à chaque séance. Toute option ajoutée après le fichier (par exemple `--toc` ou `-o autre-nom.docx`) est transmise telle quelle à pandoc, ce qui permet de surcharger ponctuellement la sortie ou d'ajouter une table des matières sans modifier le script. Il refuse un fichier absent ou dont l'extension n'est pas `.md`, avec un message explicite plutôt qu'un échec silencieux de pandoc. Le script ne fournit pas lui-même le profil `bts-sio` (styles, template Word de référence) : celui-ci vit dans un projet séparé et doit être résolu par pandoc via son répertoire de données utilisateur avant de pouvoir l'utiliser.

---

## Section utilisateur

### Description

`md2docx.sh` convertit un fichier Markdown en `.docx` via pandoc, en imposant deux choses que l'on retape sinon à chaque séance : le defaults file `-d bts-sio` et le nom du fichier de sortie, calculé à partir de l'entrée (`SEANCE.md` → `SEANCE.docx`).

Ce n'est pas un wrapper générique autour de pandoc : le profil `bts-sio` est fixe (mais surchargeable via une option `-d` supplémentaire, voir *Syntaxe*), et le script attend un fichier unique en entrée — pas de conversion par lot.

Équivalent manuel :

```bash
pandoc -d bts-sio -o SEANCE.docx SEANCE.md
```

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `pandoc` | moteur de conversion | `pandoc --version` |
| profil `bts-sio` | defaults file pandoc (styles, template Word de référence) | `pandoc --defaults-file bts-sio --dump-args` (échoue si le profil est introuvable) |

Le profil `bts-sio` n'est pas fourni par ce dépôt : c'est un defaults file pandoc nommé `bts-sio.yaml`, que pandoc résout via son répertoire de données utilisateur (`pandoc --version` en affiche le chemin, typiquement `~/.local/share/pandoc/defaults/bts-sio.yaml` ou un lien vers un projet externe). Sans lui, `-d bts-sio` échoue avec une erreur pandoc explicite (`could not find data file...`).

### Syntaxe

```bash
md2docx.sh FICHIER.md [options pandoc...]
md2docx.sh -h|--help
```

| Option / argument | Défaut | Description |
| ------------------ | ------ | ----------- |
| `FICHIER.md` | — (obligatoire) | Fichier Markdown à convertir. Doit exister et avoir l'extension `.md` |
| `-h`, `--help` | — | Affiche l'en-tête du script. **Doit être le tout premier argument** ; passé après le fichier, il est transmis à pandoc comme n'importe quelle autre option |
| *(toute autre option)* | — | Transmise telle quelle à pandoc, insérée **avant** le fichier d'entrée |

Comme pandoc ne retient que la dernière occurrence d'une option répétée, une option supplémentaire peut surcharger ce que le script impose par défaut :

```bash
md2docx.sh SEANCE.md -o brouillon.docx     # surcharge le fichier de sortie
md2docx.sh SEANCE.md -d autre-profil       # surcharge le profil bts-sio
```

### Exemples d'utilisation

```bash
# Conversion simple : produit SEANCE.docx dans le même répertoire
md2docx.sh SEANCE.md

# Ajout d'une table des matières
md2docx.sh SEANCE.md --toc

# Sortie vers un autre fichier, pour un brouillon
md2docx.sh SEANCE.md -o /tmp/brouillon.docx
```

**Exemple de sortie :**

```
[INFO]      Entrée  : SEANCE.md
[INFO]      Sortie  : SEANCE.docx
[INFO]      Profil  : bts-sio
[OK]        Document généré : SEANCE.docx
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Conversion réussie |
| `1` | Erreur d'exécution : `pandoc` absent, ou échec de la conversion (profil introuvable, Markdown invalide...) |
| `2` | Erreur d'usage : pas d'argument, fichier introuvable, extension différente de `.md` |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — isole le premier argument (fichier ou `--help`), garde le reste dans `PANDOC_ARGS[@]`.
2. `validate_input` — existence du fichier, extension `.md`.
3. `resolve_output` — calcule `OUTPUT` par substitution de suffixe (`${INPUT%.md}.docx`).
4. `convert` — vérifie que `pandoc` est installé, puis lance la conversion.

### Détail des choix techniques

**Options transmises plutôt que validées.** Contrairement à un script comme `pack-bundle.sh` qui rejette toute option inconnue, `md2docx.sh` transmet tout ce qui suit le fichier à pandoc sans le valider. Pandoc a son propre jeu d'options (`--toc`, `--reference-doc`, `-o`, `-d`...) qu'il serait redondant et fragile de dupliquer ici ; le script se contente d'imposer ses deux valeurs par défaut (`-d bts-sio`, `-o <déduit>`) *avant* les options utilisateur, qui peuvent donc les surcharger.

**`-h`/`--help` seulement en première position.** Le script ne peut pas distinguer un `--help` destiné à lui-même d'un `--help` à transmettre à pandoc si les deux se mélangent après le nom du fichier. Le compromis retenu : seul le tout premier argument est interprété comme flag du script ; le reste part tel quel vers pandoc, `--help` inclus (qui affichera alors l'aide de pandoc, pas celle du script).

**Substitution de suffixe plutôt que `basename`/`sed`.** `${INPUT%.md}.docx` gère aussi bien un chemin relatif qu'absolu, avec ou sans sous-répertoire, sans dépendre d'un outil externe.

**Pas de vérification d'écrasement.** À la différence de `pack-bundle.sh` (sauvegarde, où écraser silencieusement serait dangereux), reconvertir un `.md` modifié est l'usage normal ici : le fichier `.docx` est un résultat dérivé, pas une archive à protéger.

### Dépendances externes

| Binaire | Rôle |
| ------- | ---- |
| `pandoc` | conversion Markdown → docx, résolution du defaults file `bts-sio` |
| `awk` | réimpression de l'en-tête manpage par `--help` |

### Points d'extension

**Accepter plusieurs fichiers en entrée** — bouclerait `validate_input`/`resolve_output`/`convert` sur `$@` plutôt que sur un seul `INPUT` ; non fait volontairement, l'usage réel étant une conversion à la fois pendant la rédaction d'une séance.

**Rendre le profil configurable par variable d'environnement** — par exemple `PANDOC_PROFILE="${MD2DOCX_PROFILE:-bts-sio}"`, si un second profil (autre référentiel, autre mise en page) devient nécessaire au quotidien ; en attendant, l'option `-d` en ligne de commande suffit à surcharger ponctuellement.

### Notes de maintenance

- **Le profil `bts-sio` est une dépendance externe non versionnée ici.** Si son emplacement ou son nom change (projet déplacé, lien de données pandoc modifié), seule cette page et l'en-tête du script en gardent la trace : le script lui-même ne fait que passer `-d bts-sio` à pandoc et ne vérifie pas sa présence à l'avance (l'erreur remonte de pandoc, code de retour 1).
- **`--help` après le fichier n'affiche pas l'aide du script.** Comportement voulu (voir *Détail des choix techniques*), à ne pas « corriger » sans réévaluer comment distinguer les deux `--help` sans dupliquer la liste d'options de pandoc.
