# backup-projets.sh

> Script : [`.local/bin/backup-projets.sh`](../.local/bin/backup-projets.sh)
> Configuration : [`.config/backup-projets/projets.conf.sample`](../.config/backup-projets/projets.conf.sample)
> Scripts voisins : [pack_project.md](pack_project.md), [pack-bundle.md](pack-bundle.md), [usb-mount.md](usb-mount.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`backup-projets.sh` recopie sur une clé USB tous les projets listés dans `~/.config/backup-projets/projets.conf` — c'est le dernier geste avant d'éteindre : si un commit n'a pas été poussé, ou pas même fait, le travail est malgré tout sur la clé pour le cours du lendemain. La copie est un **miroir incrémental** : seuls les fichiers modifiés depuis la veille sont transférés, les `.git` sont conservés et les `node_modules`, `.venv`, `target` et consorts sont écartés comme le fait `pack-project.sh`. Contrairement à ce dernier, le résultat n'est pas une archive mais une arborescence directement ouvrable depuis n'importe quel poste de la salle, et clonable par un `git clone` depuis la clé ; seuls font exception les projets marqués `@` dans la configuration, ceux qui contiennent des données personnelles, qui partent en archive chiffrée par `age` et jamais en clair. Chaque projet est aussi inspecté côté Git, **sans accès réseau**, pour signaler dans le récapitulatif ce qui n'a pas été publié. La clé est reconnue à un fichier marqueur déposé une fois pour toutes par `--init`, ce qui la rend insensible à la lettre de lecteur attribuée par Windows ; le script refuse par ailleurs d'écrire sur un `/mnt/<lettre>` que WSL n'a pas monté, ou monté sans `uid=`, deux pièges classiques qui, l'un, remplit le disque virtuel sans rien déposer sur la clé, l'autre, fait tout recopier à chaque passe. Au quotidien, deux options suffisent : `--dry-run` pour vérifier avant, et `--archive` pour ajouter un instantané `.tar.zst` horodaté quand on veut pouvoir revenir en arrière.

---

## Section utilisateur

### Description

Sauvegarde de sécurité d'une liste de projets vers un support amovible, pensée pour être lancée tous les soirs sans y réfléchir. Le problème qu'elle résout n'est pas la perte de la machine, mais l'oubli : un `git commit` non fait, un `git push` non lancé, et les ressources d'un cours ne sont pas là le lendemain devant la classe.

Trois scripts d'archivage cohabitent dans ce dépôt, et ils ne répondent pas à la même question :

| Script | Produit | Contenu | Bon usage |
| ------ | ------- | ------- | --------- |
| [`pack-project.sh`](../.local/bin/pack-project.sh) | une archive `.tar.zst` | l'arborescence complète, `.git` inclus | figer **un** projet avant une manipulation risquée |
| [`pack-bundle.sh`](../.local/bin/pack-bundle.sh) | un fichier `.bundle` | l'historique Git seul, rien de non commité | transmettre ou archiver un dépôt hors ligne |
| `backup-projets.sh` | un miroir sur la clé | **tout ce qui est sur le disque**, commité ou non | filet de sécurité quotidien avant d'éteindre |

Ce que le script fait, projet par projet :

1. **relève l'état Git** — modifications non commitées, commits non poussés — sans contacter le moindre serveur ;
2. **synchronise** le projet vers `<clé>/backup-projets/miroir/<nom>/` avec `rsync`, en conservant `.git` et en écartant les artefacts de développement ;
3. **archive** en option le résultat dans `<clé>/backup-projets/archives/<nom>_AAAAMMJJ_HHMM.tar.zst`, en ne gardant que les *N* dernières ;
4. **rapporte** l'ensemble dans un tableau à l'écran et dans `<clé>/backup-projets/DERNIERE-SAUVEGARDE.txt`, lisible depuis le Bloc-notes du poste de la classe.

Un projet contenant des **données personnelles** se marque `@` dans la configuration. L'étape 2 est alors remplacée : aucun miroir, mais une archive unique `<clé>/backup-projets/chiffre/<nom>.tar.zst.age`, produite directement depuis la source et chiffrée par `age` pour une clé publique. Une clé perdue ne révèle donc que le nom du projet, la taille de l'archive et sa date. En échange, les fichiers ne s'ouvrent plus directement depuis la clé, et l'archive est réécrite en entier à chaque passe.

Si le chiffrement est impossible — `age` absent, clé publique introuvable ou invalide — le projet passe en `ÉCHEC`. Il n'est **jamais** copié en clair, et les autres projets partent normalement.

Les **liens symboliques cassés** de la source ne font pas échouer la sauvegarde. Ils sont exclus et signalés dans le récapitulatif : un lien mort ne contient aucune donnée, il n'y a rien à sauvegarder et rien à perdre.

Un **Ctrl+C** arrête toute la sauvegarde, pas seulement la copie en cours : le script affiche le récapitulatif partiel de ce qui est passé, nomme le projet qui était en cours de copie — son miroir est donc incomplet — et sort en code `130`. Aucun rapport n'est écrit sur le support dans ce cas : celui de la sauvegarde précédente, qui décrit une passe complète, reste plus honnête qu'un rapport tronqué qui se ferait passer pour la dernière en date.

Ce que le script ne fait **pas** : il ne commite rien, ne pousse rien, ne modifie aucun dépôt. Pour l'état de synchronisation détaillé, avec `git fetch` et détection des divergences, c'est [`check-git-sync.sh`](../.local/bin/check-git-sync.sh) — les deux s'enchaînent bien.

L'arborescence obtenue sur la clé :

```text
CLÉ/
├── .backup-projets                        marqueur déposé par --init
└── backup-projets/
    ├── miroir/
    │   ├── gclasse/                       fichiers ouvrables tels quels
    │   │   ├── .git/                      → git clone possible depuis la clé
    │   │   └── …
    │   └── dotfile/
    ├── chiffre/                           projets marqués « @ »
    │   └── etud-liste.tar.zst.age         illisible sans la clé privée
    ├── archives/                          seulement avec --archive
    │   ├── gclasse_20260829_1830.tar.zst
    │   └── etud-liste_20260829_1830.tar.zst.age
    └── DERNIERE-SAUVEGARDE.txt            récapitulatif de la dernière passe
```

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `rsync` | copie incrémentale (3.1 minimum pour `--info=progress2`) | `rsync --version` |
| `numfmt` | volumes lisibles dans le récapitulatif (coreutils) | `numfmt --version` |
| `git` | colonne d'état de publication ; facultatif, `-G` s'en passe | `git --version` |
| `tar`, `zstd` | pour `--archive` et les projets `@` | `zstd --version` |
| `age` | uniquement pour les projets `@` | `age --version` |
| une clé publique | fichier de destinataires des projets `@` | `ls ~/.config/backup-projets/destinataires.txt` |
| une clé **montée** | sous WSL, un lecteur branché après le démarrage ne l'est pas | `stat -c %m /mnt/h` doit rendre `/mnt/h`, pas `/` |
| montée avec **votre identité** | sans `uid=`, les fichiers appartiennent à root et leur date est verrouillée | `ls -lna /mnt/h` doit montrer votre UID, pas `0` |
| une clé préparée | fichier marqueur `.backup-projets` à sa racine | `backup-projets.sh --init /mnt/e` |
| le fichier de liste | projets à sauvegarder | `ls ~/.config/backup-projets/projets.conf` |

Le script **refuse de s'exécuter en root** : le miroir doit appartenir à l'utilisateur, et une clé montée dans sa session n'est de toute façon pas visible depuis l'environnement de `sudo`.

### Syntaxe

```bash
backup-projets.sh [-c FICHIER] [-d DIR] [-o MOTIF] [-a] [-k N] [-r FICHIER] [-n] [-G] [-L] [-q] [-h]
backup-projets.sh --init POINT_DE_MONTAGE
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-c`, `--config` | `FICHIER` | `~/.config/backup-projets/projets.conf` | Liste des projets. Variable `BACKUP_PROJETS_CONF` équivalente. |
| `-d`, `--dest` | `DIR` | détection par marqueur | Destination explicite. Variable `BACKUP_PROJETS_DEST` équivalente. |
| `-o`, `--only` | `MOTIF` | tous | Ne traiter que les projets dont le nom sur la clé correspond au motif glob. Répétable. |
| `-a`, `--archive` | — | non | Créer aussi une archive `.tar.zst` horodatée par projet (`.tar.zst.age` pour un projet `@`, qui reste chiffré). |
| `-k`, `--keep` | `N` | `3` | Archives conservées par projet. Sans effet sans `-a`. |
| `-r`, `--recipients` | `FICHIER` | `~/.config/backup-projets/destinataires.txt` | Clés publiques `age` des projets `@`, une par ligne. Variable `BACKUP_PROJETS_RECIPIENTS` équivalente. |
| `-n`, `--dry-run` | — | non | Simulation : n'écrit rien sur la clé, pas même les répertoires. |
| `-G`, `--no-git` | — | non | Ne pas inspecter l'état Git. Utile sur un gros dépôt monté en 9p. |
| `-L`, `--deref` | — | auto | Remplacer les liens symboliques par leur cible. Activé d'office si la clé ne sait pas en stocker. |
| `-q`, `--quiet` | — | non | N'afficher que le récapitulatif final. |
| `--allow-local` | — | non | Autoriser une destination sur le système de fichiers racine. Lève le garde-fou anti-`/mnt` non monté, pour un essai vers un répertoire local. |
| `--no-times` | — | non | Accepter un support qui refuse de dater les fichiers. La comparaison se fait alors sur la **taille seule** : une modification qui ne change pas la taille passe inaperçue. À éviter. |
| `--init` | `DIR` | — | Déposer le marqueur sur `DIR` et quitter. |
| `-h`, `--help` | — | — | Réimprime l'en-tête manpage du script. |

La variable `PACK_ZSTD_LEVEL` fixe le niveau de compression des archives (défaut `3`), comme pour [`pack-project.sh`](../.local/bin/pack-project.sh).

#### Fichier de configuration

Une entrée par ligne, `#` pour les commentaires :

| Forme | Effet |
| ----- | ----- |
| `/chemin/projet` | sauvegarde ce répertoire |
| `~/projets/*` | glob : chaque sous-répertoire devient un projet |
| `/chemin/projet\|autre-nom` | impose le nom du répertoire sur la clé |
| `!/chemin/motif` | exclusion (motif glob), valable où qu'elle soit écrite dans le fichier |
| `@/chemin/motif` | chiffrement (motif glob), valable où qu'il soit écrit dans le fichier |

Le `~` de tête est développé ; rien d'autre ne l'est, le fichier n'étant jamais évalué par le shell. Il n'y a donc rien à échapper : `/mnt/f/Cisco Activités` s'écrit tel quel, alors que `/mnt/f/Cisco\ Activités` désignerait un dossier contenant réellement une barre oblique inverse. Les lignes nommées sont traitées avant les globs, si bien qu'un nom explicite l'emporte sur le nom déduit du glob qui ramènerait le même répertoire.

Une ligne `@` ne **liste** pas le projet : elle change la façon de sauvegarder un projet ramené par une autre ligne, typiquement `~/projets/*`. Si aucun projet ne correspond, le script s'arrête en code `2` avant toute copie, car une faute de frappe laisserait partir en clair le projet à protéger. Une exclusion `!` l'emporte sur `@`.

### Exemples d'utilisation

```bash
# Préparation de la clé, une seule fois : dépose le marqueur à sa racine
backup-projets.sh --init /mnt/e

# Sauvegarde du soir : la clé est retrouvée toute seule, quelle que soit
# la lettre que Windows lui a attribuée ce jour-là
backup-projets.sh

# Vérifier ce qui partirait, sans rien écrire
backup-projets.sh --dry-run

# Avec instantané figé, cinq archives conservées par projet
backup-projets.sh --archive --keep 5

# Un seul projet, vers un disque externe qui n'est pas la clé habituelle
backup-projets.sh --only gclasse --dest /mnt/g/sauvegardes

# Sauvegarder, puis faire le point sur ce qui reste à publier
backup-projets.sh && check-git-sync.sh ~/projets
```

Sortie réelle d'une sauvegarde quotidienne (mode `-q`) :

```text
=== Sauvegarde des projets ===
[INFO]      Liste         : /home/jpdemory/.config/backup-projets/projets.conf
[INFO]      Projets       : 4
[INFO]      Support détecté : /mnt/e
[INFO]      La clé ne stocke pas les liens symboliques : ils seront remplacés par leur cible.
[INFO]      Espace libre  : 41,2Gio

=== RÉCAPITULATIF ===
PROJET       COPIE      GIT                        DÉTAIL
--------------------------------------------------------------------------
gclasse      OK         3 modif(s), 2 à pousser    47 fichier(s), 12,4Mio | 38s
quatro       OK         publié                     1015 fichier(s), 52,7Mio | 5s
dotfile      OK         1 modif(s)                 672 fichier(s), 7,0Mio
cours_astro  OK         publié                     0 fichier(s), 0,0o

[ATTENTION] 2 projet(s) non publié(s) — c'est bien pour eux que la clé existe.
[OK]        Sauvegarde terminée. 4 projet(s) sur /mnt/e.
```

La colonne `DÉTAIL` porte le différentiel réellement transféré : `0 fichier(s)` signifie que la sauvegarde de la veille était déjà à jour. Le temps n'est affiché qu'au-delà de cinq secondes.

Le piège le plus coûteux, sous WSL — la clé est branchée, Windows lui a donné la lettre `H:`, mais WSL ne l'a pas montée. `/mnt/h` n'est alors qu'un répertoire vide du disque virtuel :

```text
[ERREUR]    « /mnt/h » n'est pas un support monté : ce chemin appartient au système de fichiers racine.
Y écrire remplirait le disque de WSL sans rien déposer sur la clé.

Sous WSL, un lecteur branché après le démarrage n'est pas monté tout seul.
Montez-le, puis relancez :
    sudo mount -t drvfs H: /mnt/h

Pour une destination locale assumée (essai, disque interne), ajoutez --allow-local.
```

Second piège, immédiatement après le premier : la clé est bien montée, mais sans `uid=`. Tout ce qu'on y écrit appartient alors à root, et seul le propriétaire d'un fichier peut en fixer la date :

```text
[ERREUR]    Le support « /mnt/h » refuse que l'on fixe la date des fichiers.
Sans date conservée, rsync ne distingue plus ce qui a changé : chaque
sauvegarde recopierait l'intégralité des projets.

Les fichiers y appartiennent à l'utilisateur 0, pas à vous (jpdemory, 1000).
Le support est monté sans « uid= » ; seul le propriétaire d'un fichier peut le dater.
Remontez-le avec votre identité :
    sudo umount /mnt/h
    sudo mount -t drvfs H: /mnt/h -o uid=1000,gid=1000,noatime

Pour passer outre malgré tout, ajoutez --no-times (comparaison sur la taille).
```

La séquence complète, correcte, pour une clé branchée en cours de session :

```bash
sudo mount -t drvfs H: /mnt/h -o uid=$(id -u),gid=$(id -g),noatime
backup-projets.sh --init /mnt/h      # une seule fois par clé
backup-projets.sh                    # la clé est désormais retrouvée seule
```

Les deux vérifications, à tout moment :

```bash
stat -c %m /mnt/h     # « /mnt/h » = monté ; « / » = répertoire vide du disque WSL
ls -lna /mnt/h        # 3e et 4e colonnes = votre UID/GID, et non 0 0
```

Une clé absente ou non préparée :

```text
[ERREUR]    Aucun support portant le marqueur .backup-projets n'a été trouvé.
Branchez la clé, ou préparez-la une fois pour toutes :
    backup-projets.sh --init /mnt/e
Une destination ponctuelle reste possible avec --dest DIR.
```

Une source injoignable — le cas qui justifie à lui seul le garde-fou. Le disque Windows n'est pas monté, son point de montage est vide, et le miroir n'est **pas** effacé pour autant :

```text
gclasse  VIDE  3 modif(s)  source vide alors que le miroir ne l'est pas — disque non monté ? miroir laissé intact
```

Un répertoire réellement vide, ramené par un glob, est simplement signalé en jaune et n'entache pas le code de retour :

```text
template-dir  VIDE  hors git  répertoire vide, rien à sauvegarder
```

Un projet contenant un lien symbolique mort — un lien de déploiement vers un coffre Obsidian déplacé, par exemple :

```text
[INFO]      obsidian-asset-hash-rename  ←  /home/jpdemory/projets/obsidian-asset-hash-rename
symlink has no referent: "/home/jpdemory/projets/obsidian-asset-hash-rename/asset-hash-rename"
IO error encountered -- skipping file deletion
rsync error: some files/attrs were not transferred (see previous errors) (code 23)
[ATTENTION] 1 lien(s) symbolique(s) cassé(s) — seconde passe sans eux.

obsidian-asset-hash-rename  OK  publié  64 fichier(s), 116,4Kio | 1 lien(s) cassé(s) ignoré(s)
```

Le projet est sauvegardé, le code de retour reste `0`. Pour faire disparaître l'avertissement, il faut corriger la source : supprimer le lien mort, ou recréer sa cible.

Une sauvegarde interrompue au clavier :

```text
[INFO]      gclasse  ←  /mnt/f/_Obsidian/gclasse
rsync error: received SIGINT, SIGTERM, or SIGHUP (code 20) at rsync.c(716) [sender=3.2.7]

[ATTENTION] Interruption — la sauvegarde s'arrête.

=== RÉCAPITULATIF PARTIEL ===
PROJET   COPIE       GIT  DÉTAIL
--------------------------------------------------
gclasse  INTERROMPU  -    copie interrompue — miroir incomplet | 5s

[ATTENTION] 2 projet(s) sur 3 n'ont pas été traités.
[ATTENTION] Aucun rapport n'a été écrit sur le support : celui de la sauvegarde précédente est conservé.
```

Récupérer un projet depuis la clé, en cours :

```bash
# soit ouvrir les fichiers directement
ls /mnt/e/backup-projets/miroir/gclasse/

# soit repartir de l'historique Git, avec tous les commits non poussés
git clone /mnt/e/backup-projets/miroir/gclasse ~/projets/gclasse
```

#### Chiffrer un projet

Préparation, une seule fois :

```bash
sudo apt install age

# Paire de clés. Passphrase laissée vide = age en génère une solide et l'affiche.
# La clé privée n'est écrite que chiffrée par cette passphrase.
age-keygen | age -p > ~/.config/backup-projets/identite.age

# Enregistrer la clé publique affichée (« Public key: age1… »)
echo age1… > ~/.config/backup-projets/destinataires.txt

# Pour pouvoir restaurer depuis n'importe quel poste : la clé privée voyage
# avec la sauvegarde, et tout repose alors sur la solidité de la passphrase
cp ~/.config/backup-projets/identite.age /mnt/e/backup-projets/
```

La passphrase est à ranger dans un gestionnaire de mots de passe : sans elle, les archives sont irrécupérables.

Marquer ensuite le projet dans `projets.conf` :

```text
~/projets/*
@~/projets/etud-liste
```

Sortie réelle, sur une clé USB, pour deux projets totalisant 997 fichiers :

```text
PROJET      COPIE       GIT            DÉTAIL
---------------------------------------------------------------
assiduite   CHIFFRÉ     publié         archive 568,9Kio
etud-liste  CHIFFRÉ     sans upstream  archive 30,3Mio
```

Sans clé publique, le projet échoue au lieu de partir en clair, et la passe continue :

```text
assiduite   ÉCHEC       -    non sauvegardé : clé publique introuvable (/home/jpdemory/.config/backup-projets/destinataires.txt)
dotfile     OK          -    4 fichier(s), 59,6Kio | 8s
etud-liste  ÉCHEC       -    non sauvegardé : clé publique introuvable (/home/jpdemory/.config/backup-projets/destinataires.txt)
```

Une faute de frappe sur la marque arrête tout avant la première copie :

```text
[ERREUR]    Marque de chiffrement sans projet correspondant : « @/home/jpdemory/projets/etud-lste ». Rien n'a été copié.
```

Un projet copié en clair avant d'être marqué laisse son miroir sur la clé. Le script le signale à chaque passe et n'y touche pas :

```text
[ATTENTION] Copie(s) en clair d'un projet à chiffrer encore présente(s) sur le support :
            /mnt/h/backup-projets/miroir/etud-liste
[ATTENTION] À supprimer à la main. Sur une clé, un effacement ne rend pas les données irrécupérables.
```

Restaurer un projet chiffré, dans un répertoire dédié : l'archive contient le contenu du projet, sans répertoire englobant.

```bash
mkdir -p ~/restauration/etud-liste
age -d -i ~/.config/backup-projets/identite.age \
    /mnt/e/backup-projets/chiffre/etud-liste.tar.zst.age \
    | tar --zstd -xf - -C ~/restauration/etud-liste
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Tous les projets ont été sauvegardés. |
| `1` | Sauvegarde non garantie : au moins un projet en échec, absent, partiellement copié, impossible à chiffrer ou dont la source a disparu, ou un prérequis manquant (`rsync` absent, support non inscriptible). |
| `2` | Erreur d'usage : option inconnue, configuration illisible ou vide, motif `@` sans projet correspondant, support de destination introuvable, ambigu, non monté, ou incapable de dater les fichiers. |
| `130` | Interrompu au clavier (Ctrl+C). Récapitulatif partiel affiché, aucun rapport écrit sur le support. |

L'état Git n'entre **pas** dans le code de retour : un projet non publié est une sauvegarde réussie, c'est même la raison d'être du script. Pour un code de retour qui réagit à l'état de publication, enchaîner avec [`check-git-sync.sh`](../.local/bin/check-git-sync.sh).

---

## Section développeur

### Architecture interne

`main()` déroule six étapes :

1. `parse_args` puis `check_not_root` — le refus de root vient avant tout le reste, y compris `--init`.
2. `init_dest` et sortie immédiate si `--init` a été demandé.
3. `check_deps` — `rsync` et `numfmt` sont obligatoires ; l'absence de `git` dégrade silencieusement vers `-G`, celle de `zstd` n'est fatale qu'avec `-a`.
4. `load_config` → `resolve_projects` — lecture du fichier vers `SPEC_PATH`/`SPEC_LABEL`/`EXCLUDE_PATTERNS`/`ENCRYPT_PATTERNS`, puis résolution des globs et des collisions de noms vers `PROJ_PATH`/`PROJ_LABEL`. `check_encrypt_patterns` contrôle les marques `@` sur la liste complète, avant le filtrage `--only`.
5. `check_encryption` → `prepare_dest` → `setup_workdir` — état du chiffrement dans `HAS_ENCRYPTED`/`CRYPT_ERROR`, détection ou validation de la destination, sonde de liens symboliques, contrôle d'espace, répertoire temporaire avec `trap`.
6. Boucle sur les projets : `git_state`, puis `encrypt_project` et `snapshot_encrypted` pour un projet `@`, `sync_project` et `archive_project` pour les autres, accumulation dans les tableaux `R_*` ; puis `render_table`, `write_report`, `warn_orphans`, `warn_clear_copies` et calcul du code de sortie.

Les fonctions d'analyse communiquent par variables globales (`CUR_STATE`, `CUR_DETAIL`, `GIT_LABEL`, `GIT_SEV`) : une fonction bash ne rend qu'un entier, et sérialiser un tuple à travers `stdout` obligerait à re-parser une chaîne à chaque appel. C'est la convention déjà retenue par [`check-git-sync.sh`](../.local/bin/check-git-sync.sh).

### Détail des choix techniques

**Miroir plutôt qu'archive.** Une archive `.tar.zst` de la liste complète relit l'intégralité des sources à chaque lancement. Mesuré sur cette machine, un projet sur `/mnt/f` se lit à ~19 Mo/s (montage 9p) contre ~97 Mo/s sur `ext4` : quelques giga-octets de cours coûtent alors plusieurs minutes, chaque soir, même sans avoir rien modifié. Le miroir ramène les passes suivantes au différentiel — deux secondes en pratique. Accessoirement, sur le poste de la classe, une arborescence s'ouvre sans rien décompresser.

**`--delete-excluded` avec un garde-fou.** Le miroir est un vrai miroir : ce qui disparaît de la source disparaît de la clé, sans quoi il accumulerait indéfiniment des fichiers renommés. D'où un risque précis : un disque Windows non monté laisse un point de montage **vide**, et `rsync --delete` effacerait alors la sauvegarde du projet — exactement au moment où elle est le plus utile. `check_source` refuse donc toute source dont `ls -A` ne rend rien, et laisse le miroir intact. Le même contrôle protège l'archive chiffrée, qu'une archive vide remplacerait.

Encore faut-il ne pas crier au loup : un glob `~/projets/*` finit toujours par ramener un répertoire réellement vide. Le script tranche en comparant à l'état du miroir — source vide **et** miroir peuplé signale un disque disparu (rouge, code `1`) ; source vide et miroir vide ou inexistant n'est qu'une remarque (jaune, sans effet sur le code de retour). C'est le rôle de `CUR_SEV` : l'état affiché et la gravité réelle sont deux choses distinctes, et seule la seconde est comptée à la fin.

**`--modify-window=2`.** Les horodatages FAT et exFAT ont une granularité de deux secondes. Sans cette tolérance, `rsync` considère chaque fichier comme modifié et retransfère tout, à chaque passe : le caractère incrémental disparaît sans le moindre message d'erreur.

**Liens symboliques : sonde plutôt que déduction.** Le type de montage ne dit rien de la question. Sous WSL, une clé exFAT est vue comme du `v9fs`, exactement comme un disque NTFS qui, lui, accepte les liens. `detect_deref` crée donc un lien symbolique de test à la racine du support et le supprime aussitôt : si l'appel échoue, `--copy-links` est activé et les liens sont remplacés par leur cible. Le dépôt `dotfile` lui-même contient un lien (`docs` → `.config/yadm/alt/docs##class.devonly/`), le cas n'est pas théorique.

**Aucun accès réseau.** `git_state` compare `HEAD` à `@{u}` sans `fetch`. La sauvegarde doit fonctionner sur un réseau capricieux ou absent, et le script ne cherche pas à savoir si le distant a bougé : uniquement si des commits locaux risquent de n'exister nulle part ailleurs. Un `fetch` bloquant sur une authentification expirée, un soir de départ, serait le pire des comportements. Le diagnostic complet reste le rôle de `check-git-sync.sh`.

**Archives construites depuis le miroir.** `archive_project` lit `MIRROR_ROOT`, jamais la source. Le miroir est déjà expurgé des artefacts de développement, et il est local au support : relire un giga-octet à travers un montage 9p une seconde fois coûterait une minute pour un résultat identique. Les projets `@` sont l'exception : ils n'ont pas de miroir, et `snapshot_encrypted` copie simplement l'archive chiffrée du jour.

**`age` en clé publique.** La sauvegarde est un geste du soir, sans surveillance : elle ne doit réclamer aucun secret. `age -R` chiffre avec la seule clé publique, si bien que rien de ce qui sert à chiffrer ne permet de déchiffrer, ni sur la machine ni sur la clé. Les autres candidats ont été écartés pour des raisons précises :

| Outil | Motif du rejet |
| ----- | -------------- |
| `openssl enc` | pas de mode authentifié : une archive altérée n'est pas détectée de façon fiable ; passphrase à fournir à chaque passe |
| `gpg -c` | passphrase à chaque passe, ou stockée dans un fichier en clair ; le mode clé publique impose de gérer un trousseau |
| `gocryptfs -reverse` | seul à conserver l'incrémental, mais dépend de FUSE, et sa passphrase est demandée au montage |
| VeraCrypt | conteneur à gérer, installation lourde sur les postes |

**Archive complète plutôt que miroir chiffré.** L'archive est réécrite en entier à chaque passe. C'est accepté parce que les projets concernés sont petits : 1,2 s mesurée pour `etud-liste` et `assiduite` réunis, de `ext4` vers une clé USB. Le coût ne deviendrait gênant que sur un projet de plusieurs giga-octets (voir *Points d'extension*).

**Rien en clair, jamais sur le support.** `encrypt_project` part de la source et enchaîne `tar | zstd | age` dans un tube, sans fichier intermédiaire ni sur la clé ni dans `TMP_DIR`. Passer par le miroir aurait été plus simple, mais toute copie lisible déposée sur une mémoire flash y reste récupérable après effacement : la répartition d'usure ne garantit pas la réécriture des mêmes cellules.

**Une marque sans correspondance arrête tout.** Le script privilégie d'ordinaire la continuité : un projet en échec n'empêche pas les suivants. Ici c'est l'inverse, parce que l'erreur est irréversible : avec `@~/projets/etud-lste`, le glob `~/projets/*` enverrait le vrai projet en clair sur la clé, et un simple avertissement arriverait après la fuite. `check_encrypt_patterns` s'exécute donc avant la première écriture, sur la liste complète. Le même arrêt couvre un dossier sensible situé **dans** un projet listé : le motif ne correspond à aucun projet, le problème est signalé au lieu d'être ignoré.

**Échec plutôt que dégradation.** `check_encryption` ne quitte pas : elle conserve le motif dans `CRYPT_ERROR`, et `encrypt_project` fait échouer chaque projet concerné. Les autres projets sont ainsi sauvegardés le soir où `age` manque, et les projets sensibles ne sont jamais rabattus sur le miroir.

**`-C "$src" .` plutôt que le nom du répertoire.** Archiver `./etud-liste` depuis le parent donnerait un répertoire englobant à l'extraction, mais soumettrait ce nom aux exclusions : un projet appelé `build` ou `target` produirait une archive vide, sans la moindre erreur. `rsync`, avec `src/`, a le même comportement que `-C src .`.

**Écriture dans un `.part`.** L'archive n'est renommée qu'une fois les trois commandes du tube terminées avec succès. Un échec ou un Ctrl+C laisse donc l'archive précédente intacte, alors qu'une redirection directe l'aurait tronquée dès l'ouverture.

**Le journal de `tar` reste à l'écran.** Il cite des noms de fichiers, et un nom de fichier peut être une donnée personnelle. La colonne `DÉTAIL`, recopiée en clair dans `DERNIERE-SAUVEGARDE.txt`, ne porte donc que les codes de retour.

**Rotation par tri lexicographique.** `rotate_archives` trie sur le **nom** de fichier, pas sur la date d'inode : l'horodatage `AAAAMMJJ_HHMM` se trie lexicographiquement comme chronologiquement, et les dates de fichiers d'un système FAT sont trop peu fiables (fuseau, granularité) pour arbitrer une suppression.

**Marqueur plutôt que chemin fixe.** Windows n'attribue pas toujours la même lettre à la même clé. Un chemin figé en configuration mène soit à un échec, soit — bien pire — à une écriture sur le mauvais disque. Le marqueur `.backup-projets` rend la détection indépendante de la lettre ; deux supports marqués font échouer le script en code `2` plutôt que de choisir à l'aveugle. Chaque test d'existence est borné par `timeout 3` : sous WSL, `/mnt/` expose aussi les lecteurs réseau Windows, dont un seul déconnecté suffirait à figer le script.

**Refus d'écrire sur le système de fichiers racine.** C'est le garde-fou né d'un incident réel : la clé montée sous Windows en `H:`, `backup-projets.sh --init /mnt/h`, une sauvegarde annoncée terminée — et rien sur la clé. Sous WSL, les lecteurs sont montés au démarrage de la distribution ; un support branché ensuite ne l'est pas, et `/mnt/h` reste le répertoire vide laissé par un montage précédent. Les 1,4 Go étaient partis dans le disque virtuel de WSL, invisibles depuis Windows, et `wsl` lancé depuis `H:\` répondait `Failed to translate 'H:\'` — le même symptôme vu de l'autre côté.

`check_real_medium` compare donc `stat -c %m` à `/` : si le répertoire n'est adossé à aucun montage propre, le script s'arrête en code `2` et affiche la commande de montage, déduite de la lettre. `detect_dest` applique le même filtre, pour qu'un marqueur déposé par erreur dans le disque de WSL ne fasse jamais élire cette destination. `--allow-local` lève le contrôle quand la destination locale est voulue.

Le test porte sur le montage et non sur le caractère amovible du support : sous WSL, une clé USB est vue exactement comme un disque interne (`v9fs`), et rien ne les distingue. Ce qui compte n'est pas que la destination soit une clé, mais qu'elle ne soit pas le disque virtuel de la distribution.

**Sonde de datation, pour la même raison.** `rsync` décide de recopier un fichier en comparant sa taille et sa date. Si le support refuse qu'on lui fixe une date, la destination porte celle de la copie : toujours différente de la source, donc **tout est recopié à chaque passe**. Le symptôme bruyant est une avalanche de `failed to set times … Operation not permitted` et un état `PARTIEL` ; le vrai dégât est la disparition silencieuse du caractère incrémental, précisément ce pour quoi le miroir a été choisi.

Sous WSL, la cause est presque toujours un montage drvfs manuel sans `uid=`. Les répertoires sont en 777, on peut donc y créer des fichiers — mais ils appartiennent à root, et seul le propriétaire d'un fichier peut en fixer la date. Les montages automatiques de WSL, eux, portent `uid=1000,gid=1000` : d'où un `/mnt/f` qui fonctionne et un `/mnt/h` monté à la main qui échoue, sur la même machine et avec le même type de système de fichiers. `detect_times` crée un fichier témoin, relève son propriétaire, tente un `touch -d`, et rend la main en code `2` avec la commande de remontage si l'opération est refusée. L'exFAT n'a rien à voir dans l'affaire : ce sont les options de montage.

`--no-times` bascule alors `rsync` en `--no-times --size-only`, seul critère qui reste déterministe quand les dates sont fausses. C'est une dégradation assumée, pas un mode normal : un fichier modifié sans changer de taille — une coquille corrigée dans une note — ne serait plus jamais sauvegardé.

**Liens morts : une seconde passe plutôt qu'un échec.** En mode `--copy-links` — celui qu'impose une clé exFAT — rsync veut recopier la cible de chaque lien symbolique. Si elle n'existe pas, il émet `symlink has no referent`, rend `23`, et le projet passerait en `PARTIEL`. Il fait pire : le message `IO error encountered -- skipping file deletion` signale qu'il a **abandonné la purge du miroir** pour ce projet, qui accumule dès lors les fichiers supprimés côté source sans que rien ne le dise.

Or un lien mort ne contient aucune donnée. `sync_project` relit donc les lignes `symlink has no referent` du journal, en extrait les chemins, et relance la copie une seule fois en les excluant nommément (`--exclude=/chemin/relatif`, ancré sur la racine du transfert pour ne pas écarter les homonymes ailleurs dans l'arborescence). La seconde passe rétablit du même coup la purge. Le projet ressort `OK`, avec le nombre de liens ignorés dans la colonne `DÉTAIL` et une sévérité `1` — une remarque, pas un échec.

Le coût est nul dans le cas courant : la seconde passe n'a lieu que si des liens morts existent réellement. C'est ce qui a fait préférer cette approche à un pré-scan systématique par `find -xtype l`, qui aurait doublé le temps de parcours de chaque projet — douze secondes de plus pour `gclasse` sur un montage 9p, tous les soirs, pour un cas qui ne se présente presque jamais.

Les statistiques des deux passes sont **cumulées** : la première a transféré ce qu'elle pouvait avant d'échouer, et n'afficher que le reliquat de la seconde annoncerait un trompeur « 0 fichier ».

**Interruption : deux chemins, dont un seul fonctionne vraiment.** Un Ctrl+C dans un terminal envoie SIGINT à tout le groupe de processus : le script et `rsync` le reçoivent ensemble. On attend donc du `trap on_interrupt INT` qu'il fasse le travail — et il ne le fait pas. Bash mémorise un SIGINT reçu pendant l'attente d'une commande au premier plan, mais ne le **rejoue qu'à la condition que l'enfant soit lui-même mort de ce signal** ; sinon il le jette. Vérifié sur ce script : SIGINT envoyé au seul processus bash pendant un `rsync` de douze secondes, le `rsync` va au bout, et le trap n'est jamais exécuté — code de sortie `0`, sauvegarde réputée complète.

D'où le second chemin, celui qui porte réellement l'arrêt : `rsync` rend **20** quand il a reçu SIGINT (ou `128+n` si le shell constate qu'un signal l'a tué). `sync_project` reconnaît ces codes, marque le projet `INTERROMPU` et lève `INTERRUPTED` ; la boucle principale honore le drapeau juste après avoir consigné le projet. Le trap reste utile pour les signaux qui arrivent ailleurs que pendant `rsync` — `git status` sur un gros dépôt, le `tar | zstd` d'une archive, les sondes de `prepare_dest` — et pour SIGTERM. Les deux chemins convergent vers `finish_interrupted`, qui neutralise le trap (un second Ctrl+C doit tuer sans discuter), affiche le récapitulatif partiel et sort en `130`.

**Séparateur `|` dans la configuration.** Les chemins Windows contiennent régulièrement des espaces (`/mnt/f/_Obsidian/Atomic Thinking - Obsidian Expert`), ce qui interdit de séparer chemin et nom par une espace. La barre verticale n'apparaît jamais dans un nom de fichier Windows, où elle est illégale.

**Les orphelins sont signalés, jamais supprimés.** Un miroir dont le projet a quitté la configuration est peut-être la dernière copie d'un travail effacé côté source. `warn_orphans` le nomme et laisse décider.

### Dépendances externes

| Binaire | Version minimale | Ce qui l'impose |
| ------- | ---------------- | --------------- |
| `rsync` | 3.1 | `--info=progress2` (barre de progression consolidée) et `--delete-excluded` |
| `coreutils` | — | `numfmt`, `timeout`, `df --output`, `stat -c` |
| `git` | 1.8 | `rev-parse --abbrev-ref --symbolic-full-name '@{u}'` |
| `tar` (GNU) | — | motifs `--exclude` sur le nom de base, `--ignore-failed-read` ; `--zstd` (1.31) à la restauration |
| `zstd` | 1.3 | `--long`, `-T0` |
| `age` | 1.0 | `--recipients-file`, identité protégée par passphrase ; testé en 1.1.1 |

`git`, `tar`, `zstd` et `age` ne sont requis que pour les fonctions qu'ils servent ; le script dégrade ou échoue explicitement dans `check_deps` et `check_encryption`.

### Points d'extension

**Modifier la liste des exclusions.** Elle est déclarée en tête de script et alimente à la fois `rsync` (via `--exclude-from`) et `tar` :

```bash
readonly -a DEV_EXCLUDES=(
    ".venv" "venv" "env" ".env" "__pycache__" ...
)
```

Elle est volontairement identique à celle de `pack-project.sh` : toute modification devrait être répercutée dans les deux scripts, sous peine de voir une archive et un miroir du même projet diverger.

**Plafonner les suppressions.** Pour un filet supplémentaire contre un effacement massif côté source, ajouter dans `sync_project` :

```bash
opts+=(--max-delete=500)      # rsync sort en code 25 au-delà
```

Le code 25 n'est pas traité aujourd'hui et tomberait dans la branche `ÉCHEC`, ce qui est le comportement voulu — mais un nettoyage légitime et volumineux ferait alors échouer la passe.

**Élargir la recherche de la clé.** `detect_dest` balaie `/media/$USER/*`, `/run/media/$USER/*`, `/media/*` et `/mnt/*`. Ajouter un emplacement revient à compléter cette liste, en pensant à la clause `case` qui écarte `/mnt/wsl` et `/mnt/wslg`.

**Ajouter une clé de secours.** `destinataires.txt` accepte une clé publique par ligne, et chacune pourra déchiffrer seule. Aucune modification du script n'est nécessaire, mais les archives existantes ne deviennent lisibles par la nouvelle clé qu'à la passe suivante.

**Ne pas réécrire une archive inchangée.** Utile si un projet de plusieurs giga-octets devient `@`. Il faudrait comparer une empreinte des métadonnées à celle de la passe précédente, en y incluant les clés publiques pour qu'un changement de clé force la réécriture :

```bash
empreinte="$( { find "$src" -printf '%P %s %T@\n' | sort; cat "$RECIPIENTS"; } | sha256sum )"
```

L'empreinte serait à stocker à côté de l'archive, et non sur la machine : sinon, une clé neuve serait jugée à jour alors qu'elle n'a pas d'archive.

### Notes de maintenance

- **`--dry-run` n'écrit rien**, pas même les répertoires du miroir : les `mkdir` sont conditionnés. Seule exception assumée, la sonde `detect_deref` crée puis supprime un lien à la racine du support, pour que la simulation reflète le comportement réel.
- **Le récapitulatif est rendu deux fois** par `render_table`, en mode `couleur` pour le terminal et `brut` pour le fichier déposé sur la clé — celui-ci doit rester lisible dans le Bloc-notes d'un poste Windows, où des séquences ANSI ne seraient que du bruit.
- **`pad()` compte les caractères, pas les octets.** `printf %-Ns` désaligne les colonnes dès qu'un nom de projet contient un accent. Même remarque que dans `check-git-sync.sh`.
- **La sortie de `rsync --stats` est relue** pour alimenter la colonne `DÉTAIL`, d'où le `LC_ALL=C` qui fige le format. Une évolution de `rsync` qui renommerait ces lignes ferait afficher `0 fichier(s)` sans autre symptôme : c'est le premier endroit à vérifier si le différentiel paraît toujours nul.
- **Les codes de sortie de `rsync` sont traités finement** : `24` (fichiers disparus pendant la copie, typiquement un éditeur ouvert) est bénin, `23` signale un transfert partiel — souvent un nom de fichier illégal sur exFAT (`:`, `?`, `*`) — et tout le reste est un échec. Un projet en échec n'interrompt pas la boucle : les suivants sont sauvegardés quand même.
- **Un lien symbolique dont la cible existe n'est jamais exclu** : seul `symlink has no referent`, émis par rsync, déclenche l'exclusion. C'est rsync qui juge, pas le script — inutile de dupliquer la logique de résolution des liens relatifs.
- **Les chemins exclus sont repris tels quels dans un motif `--exclude`.** Un nom de fichier contenant `*`, `?` ou `[` serait interprété comme un joker par rsync et pourrait écarter plus que prévu. Le cas ne s'est jamais présenté ; s'il survient, passer par `--exclude-from` avec un fichier temporaire ne suffirait pas non plus — rsync y applique les mêmes jokers — il faudrait échapper les métacaractères.
- **Ne pas « simplifier » la gestion de l'interruption en supprimant le test des codes 20/130/143 dans `sync_project`.** C'est lui qui arrête la sauvegarde, pas le trap : sans lui, chaque projet réclamerait son propre Ctrl+C. Le trap seul donne une fausse impression de correction — il ne se déclenche que si l'enfant meurt du signal, ce qui n'est pas garanti.
- **`CURRENT_LABEL` doit être remis à vide** dès qu'un projet est consigné dans les tableaux `R_*`, sans quoi un arrêt survenu entre deux projets annoncerait à tort un miroir incomplet.
- **Les deux sondes de `prepare_dest` écrivent réellement sur le support**, y compris en `--dry-run` : un lien symbolique pour `detect_deref`, un fichier daté pour `detect_times`, tous deux supprimés dans la foulée. C'est assumé — une simulation qui ne testerait pas le support ne simulerait rien d'utile.
- **`stat -c %m` est le seul juge du montage.** `findmnt -T` donnerait la même information mais n'est pas garanti partout ; `mountpoint` échouerait sur un sous-répertoire d'un montage légitime, comme `--dest /mnt/g/sauvegardes`. Toute évolution de ce contrôle doit continuer à accepter un sous-répertoire d'un vrai montage et à refuser un `/mnt/<lettre>` fantôme.
- **La gravité d'un projet est portée par `CUR_SEV`/`R_SEV`**, pas par le libellé de la colonne `COPIE` : deux situations peuvent afficher `VIDE` sans peser pareil sur le code de retour. Ajouter un état, c'est lui attribuer une sévérité — `2` pour « la sauvegarde de ce projet n'est pas garantie », `1` pour une remarque.
- **Deux projets homonymes** sont désambiguïsés automatiquement par le nom de leur répertoire parent, avec un avertissement. Le miroir change alors de nom, donc l'ancien apparaîtra en orphelin à la passe suivante : mieux vaut fixer un nom explicite dans la configuration.
- **Le fichier `~/.config/backup-projets/projets.conf` n'est pas versionné** dans le dépôt, seul l'exemple `.sample` l'est — même convention que `usb-mount`. Il contient des chemins propres à la machine. Il en va de même de `destinataires.txt` et `identite.age`.
- **Une ligne `@` lue par une version antérieure du script fuit en silence.** Celle-ci la prend pour un chemin inexistant, signale un projet `ABSENT`, et le glob recopie le vrai projet en clair. Déployer le script **avant** de reporter la configuration sur une autre machine.
- **`archive_project` ne doit jamais traiter un projet `@`.** Il lit le miroir : un reste de miroir en clair deviendrait une nouvelle archive en clair. C'est `main()` qui aiguille vers `snapshot_encrypted`.
- **`warn_clear_copies` est le seul signal d'un reste en clair.** `warn_orphans` ne voit pas ce miroir, puisque le projet figure dans la liste. Le script ne le supprime pas : ce serait la dernière copie si l'archive s'avérait inutilisable.
- **`--dry-run` ne valide pas les clés publiques.** Il vérifie la présence d'`age` et du fichier, mais une clé mal formée n'est détectée qu'à la vraie passe, par `age` lui-même. Le contrôle est délégué à dessein : un format `age1…` analysé par le script ignorerait les autres types de destinataires.
- **Un projet qui quitte `@` garde son archive dans `chiffre/`.** Elle n'est ni supprimée ni signalée : sans danger, mais elle ne sera plus mise à jour.
- **`tar` code 1 est bénin**, comme `rsync` code 24 : un fichier a changé pendant sa lecture, et l'archive reste valide. Les codes 130 et 143 sont testés sur **chacune** des trois commandes du tube, le signal pouvant n'atteindre que l'une d'elles.
- **Pour tester une interruption depuis un script**, activer `set -m` : sans contrôle de tâches, une tâche de fond démarre avec SIGINT ignoré, de façon héritée et non rattrapable par un `trap`. Le signal semble alors sans effet, et l'on croit à tort à un défaut du script.
