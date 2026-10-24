# tar-dir.sh

> Script : [`.local/bin/tar-dir.sh`](../.local/bin/tar-dir.sh)
> Script voisin : [pack-split.md](pack-split.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`tar-dir.sh` regroupe chaque répertoire donné en un fichier `NOM.tar`, **sans compression**, avec une barre de progression : `tar-dir.sh TP*` produit un `.tar` par répertoire, à côté de chacun. Il ne compresse ni ne découpe rien — c'est l'étape préalable à `pack-split.sh`, qui traite un fichier mais pas un répertoire (`tar-dir.sh TP && pack-split.sh pack TP.tar`) ; pour obtenir directement un `.tar.zst`, c'est `pack-dir.sh`. Si un `.tar` existe déjà, le script ne le touche pas, passe au répertoire suivant et rappelle toutes les erreurs dans un bilan final. Chaque archive est écrite sous `.tar.partial` puis renommée : un `.tar` présent est toujours complet. `-o` choisit le répertoire de sortie (par exemple la clé USB).

---

## Section utilisateur

### Description

Crée `NOM.tar` pour chaque répertoire `NOM` donné et l'écrit dans le répertoire parent de la source (ou dans celui donné par `-o`). L'archive contient `NOM/…` en chemins relatifs : elle s'extrait n'importe où.

**Sélection des répertoires** — un ou plusieurs arguments, listés un à un ou par joker :

- `tar-dir.sh TP*` : le **shell** développe le joker avant l'appel ;
- `tar-dir.sh 'TP*'` : motif protégé par des guillemets, développé par le **script** (même globbing que le shell). Utile quand le nombre d'entrées dépasserait la longueur maximale d'une ligne de commande ;
- un argument qui existe sans être un répertoire (cas de `*` dans un dossier qui mêle fichiers et répertoires) est **ignoré**, sans compter comme un échec.

**Un répertoire en échec n'arrête pas le lot.** Si `NOM.tar` existe déjà, le fichier n'est pas touché, le script passe au répertoire suivant, et toutes les erreurs sont rappelées dans le bilan final.

Différence avec les scripts voisins :

| Script | Entrée | Sortie | Compression |
| ------ | ------ | ------ | ----------- |
| `tar-dir.sh` | répertoire | `NOM.tar` | aucune |
| [`pack-dir.sh`](pack_dir.md) | répertoire | `NOM_AAAAMMJJ_HHMM.tar.zst` (ou `.zip`) | oui, exclusions de dev |
| [`pack-split.sh`](pack-split.md) | **fichier** | répertoire de volumes zstd + par2 | oui, découpage |

Aucune exclusion n'est appliquée : tout le contenu est archivé, `.git` compris. Aucun horodatage n'est ajouté au nom.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `tar` | Archivage | `tar --version` |
| `pv` | Barre de progression | `pv --version` |
| `find`, `awk`, `numfmt` | Estimation et affichage des tailles (coreutils, findutils) | `find --version` |

```bash
sudo apt install pv
```

Aucun droit administrateur n'est requis.

---

### Syntaxe

```
tar-dir.sh REPERTOIRE... [-o DIR] [-h]
```

`REPERTOIRE...` : un ou plusieurs répertoires ou motifs.

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-o`, `--output` | chemin | parent de chaque répertoire | Répertoire de sortie, créé au besoin |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage |

---

### Exemples d'utilisation

```bash
# ~/projets/TP  →  ~/projets/TP.tar
tar-dir.sh ~/projets/TP

# Une archive par répertoire, sélection par joker (développé par le shell)
tar-dir.sh ~/projets/TP*

# Plusieurs répertoires, directement sur la clé USB
tar-dir.sh TP1 TP2 cours -o /media/usb

# Joker protégé : développé par le script
tar-dir.sh 'logs-2026-*'

# Préparer un transfert vers un Drive
tar-dir.sh ~/projets/TP && pack-split.sh pack ~/projets/TP.tar -d
```

**Exemple de sortie** (`tar-dir.sh TP*`, où `TP2.tar` existe déjà) :

```
[1/3]
[INFO]      Répertoire : /home/user/projets/TP1
[INFO]      Archive    : /home/user/projets/TP1.tar
[INFO]      Environ 61MB à archiver.
tar: 61,0MiB 0:00:00 [ 512MiB/s] [================================>] 99%
[OK]        Archive créée : /home/user/projets/TP1.tar (61MB)

[2/3]
[ATTENTION] Le fichier existe déjà, répertoire sauté : /home/user/projets/TP2.tar

[3/3]
[INFO]      Répertoire : /home/user/projets/TP3
…
[OK]        Archive créée : /home/user/projets/TP3.tar (12MB)

=== Bilan ===
[OK]        2 archive(s) créée(s).
[ATTENTION] 1 argument(s) ignoré(s), ce ne sont pas des répertoires :
    - TP2.tar
[ERREUR]    1 échec(s) :
    - TP2 : le fichier existe déjà : /home/user/projets/TP2.tar
```

Dans cet exemple, `TP2.tar` est aussi développé par `TP*` : il est signalé comme ignoré (ce n'est pas un répertoire), sans conséquence.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Tous les répertoires archivés (les arguments ignorés parce que ce ne sont pas des répertoires ne sont pas des échecs) |
| `1` | Au moins un répertoire non archivé : `.tar` déjà existant, source introuvable, motif sans résultat, échec de `tar`, disque plein, source = `/` ; ou `pv` absent |
| `2` | Erreur d'usage : option inconnue, aucun argument |

> Le code 1 est renvoyé **après** avoir traité tous les répertoires : les archives réussies sont bien créées. Auparavant, un `.tar` existant donnait le code 2 ; ce n'est plus une erreur d'usage mais un échec par répertoire.

---

## Section développeur

### Architecture interne

```
main
├── parse_args       options, liste d'arguments (au moins un)
├── check_tools      pv
├── collect_targets  jokers protégés développés (compgen -G), tri répertoires / ignorés / introuvables
├── pour chaque répertoire : archive_one
│     chemins, refus d'un .tar existant, estimate_size, tar | pv > .partial, mv
└── report           bilan : créées, ignorées, échecs → code de retour
```

---

### Détail des choix techniques

**Refus d'un `.tar` existant, sans option d'écrasement.**
Écraser une archive en silence peut détruire la seule sauvegarde d'une version précédente. Le répertoire est sauté, l'erreur est conservée pour le bilan, et l'utilisateur tranche ensuite (`rm`, `mv` ou `-o`).

**Erreurs différées au bilan.**
`archive_one` ajoute la raison à `FAILURES` et renvoie 1 au lieu d'appeler `die` : un seul répertoire fautif ne doit pas interrompre un lot de plusieurs dizaines. Le bilan final regroupe les erreurs pour qu'elles ne soient pas noyées dans les barres de progression.

**Étapes testées explicitement dans `archive_one`.**
La fonction est appelée dans un `if` : bash y désactive `set -e`, même pour les commandes imbriquées. Un échec de `mkdir`, `tar` ou `mv` ne ferait donc pas sortir la fonction ; chaque étape est suivie d'un test et d'un `return 1`.

**Jokers : shell d'abord, script pour les motifs protégés.**
Un argument qui n'existe pas et contient `*`, `?` ou `[` est développé par `compgen -G`. Cela contourne la limite `ARG_MAX` de la ligne de commande et garde un message clair (« aucun résultat ») pour un motif vide, là où bash passerait le motif littéral.

**Non-répertoires ignorés, pas en erreur.**
`tar-dir.sh *` dans un dossier mixte est un usage normal : traiter les fichiers comme des échecs noierait les vraies erreurs.

**`NOM.tar.partial` puis `mv`.**
Une interruption ou un disque plein ne doit pas laisser un `NOM.tar` tronqué qui passerait pour valide. Le trap `EXIT` supprime le `.partial` en cas d'échec ; `INT` et `TERM` passent par `exit` pour le déclencher.

**`tar -cf - | pv > fichier` et non `tar -cf fichier`.**
`tar` n'a pas de progression native ; `pv` en intercalaire donne débit, durée écoulée et barre sur le flux. `set -o pipefail` fait échouer le tout si `tar` échoue.

**Barre approximative.**
`pv` a besoin d'un total avant de commencer. Il est estimé en additionnant la taille des fichiers réguliers, 1 024 octets par entrée (en-tête de 512 o + remplissage) et 10 Ko de fin d'archive. C'est un majorant : la barre s'arrête vers 99 %. `du -sb` est écarté, il compte aussi la taille des répertoires eux-mêmes.

**`-C parent -- NOM`.**
`tar` reçoit le nom relatif de la source, pas son chemin absolu : l'archive contient `NOM/…` et rien de plus. Le `--` protège un répertoire dont le nom commence par `-`.

**Refus de `/`.**
`realpath` résout `.` ou `..` en `/` si on se trouve à la racine ; archiver tout le système n'est jamais voulu ici.

---

### Dépendances externes

```
bash ≥ 4     →  set -o pipefail, mapfile, compgen -G (jokers protégés)
tar          →  GNU tar (-C, --)
pv           →  progression sur flux (-N, -s)
findutils    →  find -printf '%y %s'
coreutils    →  realpath, stat, numfmt
```

---

### Points d'extension

**Exclure des motifs** (`.git`, `node_modules`) : ajouter `--exclude` à la commande `tar` de `create_tar` ; l'estimation de taille sera alors surévaluée, ce qui ne gêne pas. Pour un besoin plus large, voir [`pack-dir.sh`](pack_dir.md).

```bash
tar -cf - --exclude='.git' -C "$(dirname -- "$SRC_ABS")" -- "$NAME" \
    | pv -N "tar" -s "$total" > "$PARTIAL"
```

**Horodatage dans le nom** : construire `OUT` dans `resolve_paths` avec `$(date +%Y%m%d_%H%M)`.

---

### Notes de maintenance

- **Doublons** : deux arguments désignant le même répertoire (ou deux sources de même nom envoyées vers le même `-o`) donnent un échec « existe déjà » pour le second, volontairement.
- **Estimation** : sur un répertoire très volumineux (millions de fichiers), le `find` initial peut prendre plusieurs secondes, signalé par le message « Estimation de la taille… ».
- **Fichiers modifiés pendant l'archivage** : `tar` peut avertir (« file changed as we read it ») ; le total estimé n'est alors plus exact. La barre reste indicative.
- **Interruption (Ctrl-C)** : arrête tout le lot, supprime le `.partial` en cours, et n'affiche pas de bilan ; les archives déjà terminées restent.
- **Archive dans la source** : avec `-o` pointant à l'intérieur du répertoire archivé, `tar` s'inclurait lui-même ; ce cas n'est pas détecté.
