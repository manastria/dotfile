# yadm_alt_link.py — Utilisation et maintenance

## Vue d'ensemble

Le script `bin/yadm_alt_link.py` permet de séparer les fichiers utiles
uniquement en développement (`.editorconfig`, `.vscode/`, `.gitignore`) des
fichiers déployés sur les machines cibles via yadm.

**Principe** : chaque fichier dev-only est stocké sous forme de *variante yadm*
avec le suffixe `##class.devonly` dans `.config/yadm/alt/`. Ce suffixe ne
correspond à aucune classe yadm, donc yadm ne crée jamais de lien vers ces
fichiers dans `$HOME`. Seul le checkout de développement y a accès.

**Stratégie de liens** : par défaut, le script crée un symlink du working-name
vers la variante. Pour certains fichiers (`.gitignore`, `.gitattributes`,
`.gitmodules`), un symlink causerait des problèmes avec git : le script utilise
alors un hardlink ou une copie.

## Utilisation

### Commande de base

```bash
# Traiter tous les fichiers listés dans .config/yadm/alt-link-list.txt
python3 bin/yadm_alt_link.py

# Traiter des chemins spécifiques
python3 bin/yadm_alt_link.py .editorconfig .vscode

# Diagnostiquer sans modifier
python3 bin/yadm_alt_link.py --check-only

# Détecter les divergences des fichiers copiés/hardlinkés
python3 bin/yadm_alt_link.py --sync
```

Le fichier `.config/yadm/alt-link-list.txt` contient un chemin par ligne
(les lignes vides et les commentaires `#` sont ignorés).

### Options CLI

| Option | Description |
|---|---|
| `paths...` | Chemins à traiter. Sans argument, lit `.config/yadm/alt-link-list.txt`. |
| `--force` | Remplace le working-name s'il ne correspond pas à la variante. |
| `--sync` | Détecte les divergences entre les fichiers hardlink/copie et leurs variantes, et affiche la commande `cp` pour re-synchroniser. |
| `--check-only` | Diagnostique uniquement, ne modifie rien (ni fichiers, ni index git). |
| `--fix-tracked-excluded` | Retire de l'index git les chemins exclus encore suivis (activé par défaut). |
| `--no-fix-tracked-excluded` | Désactive le retrait automatique de l'index, affiche seulement le diagnostic. |

### Cas de traitement

Le script gère 5 cas selon l'état de la variante et du working-name :

| Cas | Variante | Working-name | Action |
|---|---|---|---|
| 1 | absente | fichier/dossier | Déplace le fichier vers la variante, crée le lien |
| 2 | présente | absent | Crée le lien vers la variante existante |
| 3 | présente | présent (correct) | Rien à faire (affiche `Deja configure`) |
| 3b | présente | présent (incohérent) | Avertissement ; `--force` pour remplacer le lien |
| 4 | absente | symlink | Avertissement : lien orphelin, aucun changement |
| 5 | absente | absent | Rien à faire |

Dans tous les cas, le working-name est ajouté à `.git/info/exclude` et les
fichiers suivis dans l'index sont signalés (et retirés si `--fix-tracked-excluded`).

## Maintenance

### Ajouter un fichier dev-only

1. Ajouter le chemin dans `.config/yadm/alt-link-list.txt` :

```bash
echo "mon-fichier.conf" >> .config/yadm/alt-link-list.txt
```

2. Exécuter le script (le fichier est déplacé vers la variante et le lien créé) :

```bash
python3 bin/yadm_alt_link.py
```

3. Commiter la variante :

```bash
git add .config/yadm/alt/mon-fichier.conf##class.devonly
git add .config/yadm/alt-link-list.txt
git commit -m "feat: add mon-fichier.conf as dev-only variant"
```

### Retirer un fichier dev-only

1. Supprimer le lien et copier la variante à sa place :

```bash
rm mon-fichier.conf
cp .config/yadm/alt/mon-fichier.conf##class.devonly mon-fichier.conf
```

2. Supprimer la variante et retirer l'entrée du fichier liste :

```bash
rm .config/yadm/alt/mon-fichier.conf##class.devonly
# Editer .config/yadm/alt-link-list.txt pour retirer la ligne
```

3. Retirer l'entrée de `.git/info/exclude` si présente.

### Fichiers sans symlink (hardlink/copie)

Les fichiers listés dans `NO_SYMLINK` (`.gitignore`, `.gitattributes`,
`.gitmodules`) ne supportent pas les symlinks avec git. Le script crée un
hardlink ou, en cas d'échec, une copie.

Ces fichiers peuvent diverger de leur variante après modification. Utiliser
`--sync` pour détecter les divergences :

```bash
python3 bin/yadm_alt_link.py --sync
# Affiche par exemple :
#   SYNC: '.gitignore' est plus recent que la variante
#         → cp '.gitignore' '.config/yadm/alt/.gitignore##class.devonly'
```

### Migration depuis `##os.None`

L'ancien suffixe `##os.None` est automatiquement migré vers `##class.devonly`
au premier lancement du script. Les fichiers sont renommés et les symlinks
existants sont réparés. Aucune action manuelle n'est nécessaire.

## Architecture

### Flux de traitement

```
main()
  ├─ Lecture de la racine git (repo_root)
  ├─ Migration ##os.None → ##class.devonly (migrate_old_suffix)
  ├─ Lecture des cibles (get_targets)
  │    └─ CLI args ou .config/yadm/alt-link-list.txt
  ├─ Validation (validate_targets)
  │    ├─ Normalisation et deduplication
  │    ├─ Detection des chemins imbriques
  │    └─ Verification d'existence
  ├─ Traitement de chaque cible (process_one)
  │    ├─ Cas 1-5 : deplacement / lien / remplacement
  │    ├─ Ajout a .git/info/exclude
  │    └─ Diagnostic / retrait de l'index git
  └─ Resume final (statistiques)
```

### Fichiers impliqués

| Fichier | Rôle |
|---|---|
| `bin/yadm_alt_link.py` | Script principal. |
| `.config/yadm/alt-link-list.txt` | Liste des chemins à traiter (un par ligne). |
| `.config/yadm/alt/` | Répertoire des variantes yadm (`*##class.devonly`). |
| `.git/info/exclude` | Exclusions git locales (working-names ajoutés automatiquement). |
