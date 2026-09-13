# `md2docx.sh` — Conversion Markdown vers .docx (profil bts-sio)

> Script : [`.local/bin/md2docx.sh`](../.local/bin/md2docx.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`md2docx.sh` convertit un ou plusieurs fichiers Markdown en document Word `.docx` avec pandoc, en appliquant systématiquement le defaults file **bts-sio** (`-d bts-sio`) qui porte la mise en forme et le template de référence du cours. Il suffit de donner le(s) fichier(s) `.md` en argument, explicitement (`seance1.md seance2.md`) ou via un joker (`*.md`) : le nom de sortie de chacun est déduit automatiquement en remplaçant l'extension `.md` par `.docx`, sans retaper la commande `pandoc -d bts-sio -o ... ...` à chaque séance. Toute option ajoutée après le(s) fichier(s) (par exemple `--toc`) est transmise telle quelle à pandoc pour chaque conversion, ce qui permet d'ajouter une table des matières sans modifier le script ; `-o` reste réservée au cas d'un fichier unique, car elle collisionnerait sinon sur un seul nom de sortie. Il refuse un fichier absent, sans interrompre la conversion des autres fichiers du lot, avec un message explicite plutôt qu'un échec silencieux de pandoc. Le script ne fournit pas lui-même le profil `bts-sio` (styles, template Word de référence) : celui-ci vit dans un projet séparé et doit être résolu par pandoc via son répertoire de données utilisateur avant de pouvoir l'utiliser.

---

## Section utilisateur

### Description

`md2docx.sh` convertit un ou plusieurs fichiers Markdown en `.docx` via pandoc, en imposant deux choses que l'on retape sinon à chaque séance : le defaults file `-d bts-sio` et le nom du fichier de sortie, calculé à partir de chaque entrée (`SEANCE.md` → `SEANCE.docx`).

Ce n'est pas un wrapper générique autour de pandoc : le profil `bts-sio` est fixe (mais surchargeable via une option `-d` supplémentaire, voir *Syntaxe*). En revanche, contrairement à un simple alias `pandoc -d bts-sio`, il accepte plusieurs fichiers en une seule commande (liste explicite ou joker `*.md`) et convertit chacun séparément.

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
md2docx.sh FICHIER.md... [options pandoc...]
md2docx.sh -h|--help
```

| Option / argument | Défaut | Description |
| ------------------ | ------ | ----------- |
| `FICHIER.md...` | — (obligatoire) | Un ou plusieurs fichiers Markdown à convertir, en tête de ligne de commande. Chacun doit exister et avoir l'extension `.md` ; un joker shell (`*.md`) fonctionne aussi bien qu'une liste explicite |
| `-h`, `--help` | — | Affiche l'en-tête du script. **Doit être le tout premier argument** ; passé après le(s) fichier(s), il est transmis à pandoc comme n'importe quelle autre option |
| *(toute autre option)* | — | Transmise telle quelle à pandoc pour **chaque** fichier, insérée **avant** le fichier d'entrée. `-o`/`--output` est refusée dès que plusieurs fichiers sont fournis |

Comme pandoc ne retient que la dernière occurrence d'une option répétée, une option supplémentaire peut surcharger ce que le script impose par défaut — mais `-o` seulement pour un fichier unique :

```bash
md2docx.sh SEANCE.md -o brouillon.docx     # surcharge le fichier de sortie (un seul fichier)
md2docx.sh *.md -d autre-profil            # surcharge le profil bts-sio pour tous les fichiers
```

### Exemples d'utilisation

```bash
# Conversion simple : produit SEANCE.docx dans le même répertoire
md2docx.sh SEANCE.md

# Plusieurs fichiers explicites
md2docx.sh seance1.md seance2.md seance3.md

# Tous les Markdown du répertoire courant
md2docx.sh *.md

# Ajout d'une table des matières, appliquée à chaque fichier
md2docx.sh *.md --toc

# Sortie vers un autre fichier, pour un brouillon (un seul fichier à la fois)
md2docx.sh SEANCE.md -o /tmp/brouillon.docx
```

**Exemple de sortie :**

```
[INFO]      Entrée  : seance1.md
[INFO]      Sortie  : seance1.docx
[INFO]      Profil  : bts-sio
[OK]        Document généré : seance1.docx
[INFO]      Entrée  : seance2.md
[INFO]      Sortie  : seance2.docx
[INFO]      Profil  : bts-sio
[OK]        Document généré : seance2.docx
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Toutes les conversions ont réussi |
| `1` | Erreur d'exécution : `pandoc` absent, ou échec d'au moins une conversion (profil introuvable, Markdown invalide...) |
| `2` | Erreur d'usage : aucun fichier `.md`, fichier introuvable, ou `-o`/`--output` combinée à plusieurs fichiers |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — consomme les arguments de tête se terminant par `.md` dans `INPUTS[@]`, garde le reste (options ou `--help` en première position) dans `PANDOC_ARGS[@]`.
2. `validate_inputs` — existence de chaque fichier de `INPUTS[@]`.
3. `check_output_override` — si plusieurs fichiers, refuse `-o`/`--output` dans `PANDOC_ARGS[@]`.
4. `convert_all` — vérifie que `pandoc` est installé, puis boucle `convert_one` sur `INPUTS[@]` en comptant les échecs.
5. `convert_one` — calcule la sortie d'un fichier par substitution de suffixe (`${input%.md}.docx`) et lance sa conversion.

### Détail des choix techniques

**Fichiers reconnus par motif, pas par position.** `parse_args` consomme tant que l'argument courant se termine par `.md` ; le premier argument qui ne matche plus marque le début des options pandoc. Cela permet `a.md b.md c.md --toc` et `*.md --toc` sans syntaxe dédiée, mais impose que tous les fichiers soient groupés en tête — une option ne peut pas s'intercaler entre deux fichiers.

**Options transmises plutôt que validées.** Contrairement à un script comme `pack-bundle.sh` qui rejette toute option inconnue, `md2docx.sh` transmet tout ce qui suit le(s) fichier(s) à pandoc sans le valider. Pandoc a son propre jeu d'options (`--toc`, `--reference-doc`, `-d`...) qu'il serait redondant et fragile de dupliquer ici ; le script se contente d'imposer ses valeurs par défaut (`-d bts-sio`, `-o <déduit>`) *avant* les options utilisateur, qui peuvent donc les surcharger — à l'exception de `-o`, explicitement bloquée en présence de plusieurs fichiers (voir ci-dessous).

**`-o`/`--output` bloquée seulement à partir de deux fichiers.** Avec un fichier unique, `-o` reste une surcharge légitime (brouillon, sortie temporaire). Avec plusieurs fichiers, chaque sortie est censée être déduite de son entrée ; laisser passer `-o` ferait écraser silencieusement toutes les conversions sur un seul nom. `check_output_override` ne fait qu'une recherche textuelle (`-o` exact, ou préfixe `--output`) dans `PANDOC_ARGS[@]` — elle ne comprend pas la syntaxe pandoc au-delà de ça.

**Une conversion échouée n'interrompt pas les autres.** `convert_all` boucle sur tous les fichiers même après un échec (`convert_one` retourne un code sans déclencher `set -e`, grâce au `||` qui l'encadre), et ne fait échouer le script qu'à la fin, une fois le lot traité — pour qu'un fichier en erreur dans un `*.md` de dix séances n'empêche pas de générer les neuf autres.

**`-h`/`--help` seulement en première position.** Le script ne peut pas distinguer un `--help` destiné à lui-même d'un `--help` à transmettre à pandoc si les deux se mélangent après le(s) fichier(s). Le compromis retenu : seul le tout premier argument est interprété comme flag du script ; le reste part tel quel vers pandoc, `--help` inclus (qui affichera alors l'aide de pandoc, pas celle du script).

**Substitution de suffixe plutôt que `basename`/`sed`.** `${input%.md}.docx` gère aussi bien un chemin relatif qu'absolu, avec ou sans sous-répertoire, sans dépendre d'un outil externe.

**Pas de vérification d'écrasement.** À la différence de `pack-bundle.sh` (sauvegarde, où écraser silencieusement serait dangereux), reconvertir un `.md` modifié est l'usage normal ici : le fichier `.docx` est un résultat dérivé, pas une archive à protéger.

### Dépendances externes

| Binaire | Rôle |
| ------- | ---- |
| `pandoc` | conversion Markdown → docx, résolution du defaults file `bts-sio` |
| `awk` | réimpression de l'en-tête manpage par `--help` |

### Points d'extension

**Rendre le profil configurable par variable d'environnement** — par exemple `PANDOC_PROFILE="${MD2DOCX_PROFILE:-bts-sio}"`, si un second profil (autre référentiel, autre mise en page) devient nécessaire au quotidien ; en attendant, l'option `-d` en ligne de commande suffit à surcharger ponctuellement.

**Traiter les fichiers en parallèle** — `convert_all` boucle séquentiellement ; pour un lot volumineux, un `xargs -P` ou des jobs `&`/`wait` sur `INPUTS[@]` accélérerait la conversion, au prix d'une sortie entrelacée à réordonner.

### Notes de maintenance

- **Le profil `bts-sio` est une dépendance externe non versionnée ici.** Si son emplacement ou son nom change (projet déplacé, lien de données pandoc modifié), seule cette page et l'en-tête du script en gardent la trace : le script lui-même ne fait que passer `-d bts-sio` à pandoc et ne vérifie pas sa présence à l'avance (l'erreur remonte de pandoc, code de retour 1).
- **`--help` après le(s) fichier(s) n'affiche pas l'aide du script.** Comportement voulu (voir *Détail des choix techniques*), à ne pas « corriger » sans réévaluer comment distinguer les deux `--help` sans dupliquer la liste d'options de pandoc.
- **Les fichiers doivent être groupés en tête de ligne de commande.** `seance.md --toc autre.md` ne fonctionne pas : `autre.md` serait transmis à pandoc comme argument de `--toc` plutôt que reconnu comme second fichier, puisque `parse_args` arrête de chercher des `.md` dès le premier argument qui n'en est pas un.
