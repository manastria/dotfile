# install-fonts.sh

> Script : [`.local/bin/install-fonts.sh`](../.local/bin/install-fonts.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-fonts.sh` installe des polices **pour l'utilisateur courant** : il copie tous les `.ttf`, `.otf` et `.ttc` trouvés (sous-dossiers compris) dans `~/.local/share/fonts`, puis reconstruit le cache avec `fc-cache`. Il ne **télécharge rien** et n'installe pas de polices système dans `/usr/share/fonts` : il faut d'abord avoir récupéré et dézippé les polices, par exemple une Nerd Font pour le terminal. Il s'appelle avec le dossier source en seul argument (`install-fonts.sh ~/Downloads/FiraCode`), le répertoire courant par défaut. Aucun `sudo` n'est nécessaire (le script refuse même de tourner en root) et il est relançable : une police déjà installée n'est **jamais écrasée**, sauf avec `--force`. `--help` affiche l'aide.

---

## Section utilisateur

### Description

Copie les polices TrueType, OpenType et les collections `.ttc` d'un répertoire local vers le répertoire de polices de l'utilisateur (`~/.local/share/fonts`, lu automatiquement par fontconfig), puis met à jour le cache des polices pour qu'elles soient visibles sans redémarrer la session.

Il se distingue des scripts `install-*.sh` voisins : ceux-ci téléchargent et installent un logiciel, alors que celui-ci ne fait que **déployer des fichiers déjà présents sur le disque**. Il ne touche pas à la configuration des applications (terminal, éditeur) : choisir la police reste à faire dans chacune.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `find`, `cp` | recherche et copie des fichiers | `find --version` |
| `fc-cache` (paquet `fontconfig`) | reconstruction du cache des polices | `command -v fc-cache` |
| polices dézippées | source des fichiers `.ttf` / `.otf` / `.ttc` | `find <dossier> -iname '*.ttf' -o -iname '*.otf'` |

### Syntaxe

```bash
install-fonts.sh [--force] [RÉPERTOIRE]
install-fonts.sh -h | --help
```

| Option / argument | Défaut | Description |
| ----------------- | ------ | ----------- |
| `RÉPERTOIRE` | `.` (répertoire courant) | Dossier où chercher les polices, récursivement |
| `-f`, `--force` | désactivé | Écrase les polices déjà présentes dans la destination |
| `-h`, `--help` | — | Affiche l'en-tête du script |

Une police dont le nom existe déjà dans la destination est **ignorée** avec un avertissement. Conséquence : deux fichiers de même nom dans des sous-dossiers différents ne sont pas tous deux installés, seul le premier trouvé l'est. Avec `--force`, tout est écrasé, le dernier trouvé gagne et un avertissement signale le doublon.

Destination fixe : `~/.local/share/fonts` (non configurable sans modifier le script).

### Exemples d'utilisation

```bash
# Installer les polices du répertoire courant
cd ~/Downloads/FiraCode && install-fonts.sh

# Installer depuis un dossier précis
install-fonts.sh ~/Downloads/FiraCode

# Réinstaller en écrasant les polices déjà présentes
install-fonts.sh --force ~/Downloads/FiraCode

# Vérifier qu'une police est connue de fontconfig
fc-list | grep -i "fira"
```

Sortie réelle, première exécution (dossier contenant un `.ttf`, un `.OTF` dans un sous-dossier, un nom avec espace, un doublon `F-Regular.ttf` dans `a/` et un fichier texte ignoré ; `$HOME` abrégé, couleurs omises) :

```
=== Installation de polices (utilisateur) ===

[INFO]      Recherche de polices dans : .
'./F-Regular.ttf' -> '$HOME/.local/share/fonts/F-Regular.ttf'
'./with space/My Font.ttf' -> '$HOME/.local/share/fonts/My Font.ttf'
[ATTENTION] Doublon 'F-Regular.ttf' : './a/F-Regular.ttf' remplace './F-Regular.ttf'.
'./a/F-Regular.ttf' -> '$HOME/.local/share/fonts/F-Regular.ttf'
'./sub/F-Bold.OTF' -> '$HOME/.local/share/fonts/F-Bold.OTF'
[INFO]      Mise à jour du cache des polices...
[OK]        4 fichier(s) installé(s) dans $HOME/.local/share/fonts (0 ignoré(s)).
```

Sans `--force`, le doublon `a/F-Regular.ttf` est ignoré, et une seconde exécution ne copie plus rien :

```
[INFO]      Recherche de polices dans : .
[ATTENTION] Déjà présent, ignoré : F-Regular.ttf (--force pour écraser)
[ATTENTION] Déjà présent, ignoré : My Font.ttf (--force pour écraser)
[ATTENTION] Déjà présent, ignoré : F-Regular.ttf (--force pour écraser)
[ATTENTION] Déjà présent, ignoré : F-Bold.OTF (--force pour écraser)
[OK]        Rien à installer : 4 police(s) déjà présente(s).
```

Erreurs courantes :

```
[ERREUR]    Le répertoire '/nonexistent' n'existe pas.
[ERREUR]    Aucune police (.ttf/.otf/.ttc) trouvée dans './vide'.
[ERREUR]    Option inconnue : --foo (voir --help)
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Terminé, aide affichée, ou toutes les polices étaient déjà présentes (rien à faire) |
| 1 | Erreur : option inconnue, exécution en root, répertoire source introuvable, aucune police trouvée, `fc-cache` absent, échec de `cp` ou de `fc-cache` |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — `-f`/`--force`, `-h`/`--help` (affiche l'en-tête et sort), option inconnue refusée, premier argument positionnel = `SRC_DIR`.
2. `check_prereqs` — refus du root, existence de `SRC_DIR`, présence de `fc-cache`.
3. `install_fonts` — `mkdir -p`, boucle sur `find -print0` (ignore les fichiers déjà présents sauf `--force`, détecte les doublons), erreur si aucune police, puis `fc-cache -f` uniquement si au moins un fichier a été copié.

### Détail des choix techniques

**Aide extraite de l'en-tête.** `sed -n '2,/^$/{…}' "$0"` imprime les commentaires de la ligne 2 jusqu'à la première ligne vide, en retirant le `# `. L'aide et l'en-tête manpage ne peuvent donc pas diverger. Conséquence : l'en-tête doit rester un bloc de commentaires **sans ligne vide** (utiliser `#` seul pour séparer les sections) ; une ligne vide coupe l'aide.

**Refus des options inconnues.** Sans le `-*)`, `install-fonts.sh --foo` aurait cherché un répertoire nommé `--foo` et affiché une erreur trompeuse.

**Vérifications avant toute copie.** `fc-cache` est contrôlé dans `check_prereqs` : l'ancienne version copiait les fichiers, échouait sur `fc-cache` puis affichait « Terminé ! » avec le code 0. Désormais `set -euo pipefail` propage aussi les échecs de `cp` et `fc-cache`.

**Boucle `read -d ''` plutôt que `find -exec cp`.** Elle permet de compter les fichiers, de refuser un dossier sans police et de repérer les doublons (tableau associatif `seen`, bash 4+). `-print0` rend la boucle sûre pour les noms avec espaces.

**Pas d'écrasement par défaut.** Le test porte sur le nom dans `DEST_DIR` (`[[ -e … ]]`), pas sur le contenu : une police mise à jour sous le même nom exige `--force`. Un dossier dont toutes les polices sont déjà installées n'est pas une erreur (code 0, `fc-cache` non relancé). Le doublon interne à la source suit la même règle : le second fichier de même nom est vu comme « déjà présent » car le premier vient d'être copié.

**Refus du root.** Le script écrit dans `$HOME` : lancé via `sudo`, il créerait des fichiers appartenant à root dans le dossier de l'utilisateur (palier 3 de la convention sudo du dépôt).

**`find` plutôt qu'un glob.** `-iname` couvre `.TTF` / `.OTF`, `.ttc` couvre les collections, et la récursion gère les archives qui rangent les polices par famille ou par style.

**`~/.local/share/fonts`.** Emplacement XDG lu par fontconfig sans configuration : pas de droits root, pas de modification de `/usr/share/fonts`.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 4.0 | tableau associatif (`declare -A`) |
| `find` | — | `-iname`, `-print0` |
| `cp` | GNU coreutils | `-v` (affichage des copies) |
| `fc-cache` | fontconfig | `-f` (reconstruction forcée) |

### Points d'extension

**Destination configurable** :

```bash
DEST_DIR="${FONTS_DEST:-$HOME/.local/share/fonts}"
```

**Autres formats** — adapter le `find` de `install_fonts` (`.woff2` n'est utile qu'au web) :

```bash
done < <(find "$SRC_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" \) -print0)
```

**Désinstaller** — ajouter une option `--remove` qui supprime dans `DEST_DIR` les noms trouvés dans `SRC_DIR`, puis relance `fc-cache -f`.

### Notes de maintenance

- **L'aide est l'en-tête.** `sed` s'arrête à la première ligne vide : ne pas en insérer dans le bloc de commentaires initial (utiliser `#` seul).
- **Doublons.** Les polices sont copiées à plat. Sans `--force`, la première gagne ; avec `--force`, la dernière (avertissement dans les deux cas, pas d'échec).
- **Aucune désinstallation.** Pour retirer une police, supprimer le fichier dans `~/.local/share/fonts` puis relancer `fc-cache -f`.
- **Convention sudo.** Palier 3 (refus du root) : le message de refus utilise `echo` brut, comme le modèle de `CLAUDE.md`, et non `error`.
