# backup-projets.sh

> Script : [`.local/bin/backup-projets.sh`](../.local/bin/backup-projets.sh)
> Configuration : [`.config/backup-projets/projets.conf.sample`](../.config/backup-projets/projets.conf.sample)
> Scripts voisins : [pack_project.md](pack_project.md), [pack-bundle.md](pack-bundle.md), [usb-mount.md](usb-mount.md)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`backup-projets.sh` recopie sur une clé USB tous les projets listés dans `~/.config/backup-projets/projets.conf` — c'est le dernier geste avant d'éteindre : si un commit n'a pas été poussé, ou pas même fait, le travail est malgré tout sur la clé pour le cours du lendemain. La copie est un **miroir incrémental** : seuls les fichiers modifiés depuis la veille sont transférés, les `.git` sont conservés et les `node_modules`, `.venv`, `target` et consorts sont écartés comme le fait `pack-project.sh`. Contrairement à ce dernier, le résultat n'est pas une archive mais une arborescence directement ouvrable depuis n'importe quel poste de la salle, et clonable par un `git clone` depuis la clé. Chaque projet est aussi inspecté côté Git, **sans accès réseau**, pour signaler dans le récapitulatif ce qui n'a pas été publié. La clé est reconnue à un fichier marqueur déposé une fois pour toutes par `--init`, ce qui la rend insensible à la lettre de lecteur attribuée par Windows ; le script refuse par ailleurs d'écrire sur un `/mnt/<lettre>` que WSL n'a pas monté, ou monté sans `uid=`, deux pièges classiques qui, l'un, remplit le disque virtuel sans rien déposer sur la clé, l'autre, fait tout recopier à chaque passe. Au quotidien, deux options suffisent : `--dry-run` pour vérifier avant, et `--archive` pour ajouter un instantané `.tar.zst` horodaté quand on veut pouvoir revenir en arrière.

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
    ├── archives/                          seulement avec --archive
    │   └── gclasse_20260829_1830.tar.zst
    └── DERNIERE-SAUVEGARDE.txt            récapitulatif de la dernière passe
```

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `rsync` | copie incrémentale (3.1 minimum pour `--info=progress2`) | `rsync --version` |
| `numfmt` | volumes lisibles dans le récapitulatif (coreutils) | `numfmt --version` |
| `git` | colonne d'état de publication ; facultatif, `-G` s'en passe | `git --version` |
| `tar`, `zstd` | uniquement pour `--archive` | `zstd --version` |
| une clé **montée** | sous WSL, un lecteur branché après le démarrage ne l'est pas | `stat -c %m /mnt/h` doit rendre `/mnt/h`, pas `/` |
| montée avec **votre identité** | sans `uid=`, les fichiers appartiennent à root et leur date est verrouillée | `ls -lna /mnt/h` doit montrer votre UID, pas `0` |
| une clé préparée | fichier marqueur `.backup-projets` à sa racine | `backup-projets.sh --init /mnt/e` |
| le fichier de liste | projets à sauvegarder | `ls ~/.config/backup-projets/projets.conf` |

Le script **refuse de s'exécuter en root** : le miroir doit appartenir à l'utilisateur, et une clé montée dans sa session n'est de toute façon pas visible depuis l'environnement de `sudo`.

### Syntaxe

```bash
backup-projets.sh [-c FICHIER] [-d DIR] [-o MOTIF] [-a] [-k N] [-n] [-G] [-L] [-q] [-h]
backup-projets.sh --init POINT_DE_MONTAGE
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-c`, `--config` | `FICHIER` | `~/.config/backup-projets/projets.conf` | Liste des projets. Variable `BACKUP_PROJETS_CONF` équivalente. |
| `-d`, `--dest` | `DIR` | détection par marqueur | Destination explicite. Variable `BACKUP_PROJETS_DEST` équivalente. |
| `-o`, `--only` | `MOTIF` | tous | Ne traiter que les projets dont le nom sur la clé correspond au motif glob. Répétable. |
| `-a`, `--archive` | — | non | Créer aussi une archive `.tar.zst` horodatée par projet. |
| `-k`, `--keep` | `N` | `3` | Archives conservées par projet. Sans effet sans `-a`. |
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

Le `~` de tête est développé ; rien d'autre ne l'est, le fichier n'étant jamais évalué par le shell. Les lignes nommées sont traitées avant les globs, si bien qu'un nom explicite l'emporte sur le nom déduit du glob qui ramènerait le même répertoire.

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

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Tous les projets ont été sauvegardés. |
| `1` | Sauvegarde non garantie : au moins un projet en échec, absent, partiellement copié ou dont la source a disparu, ou un prérequis manquant (`rsync` absent, support non inscriptible). |
| `2` | Erreur d'usage : option inconnue, configuration illisible ou vide, support de destination introuvable, ambigu, non monté, ou incapable de dater les fichiers. |
| `130` | Interrompu au clavier (Ctrl+C). Récapitulatif partiel affiché, aucun rapport écrit sur le support. |

L'état Git n'entre **pas** dans le code de retour : un projet non publié est une sauvegarde réussie, c'est même la raison d'être du script. Pour un code de retour qui réagit à l'état de publication, enchaîner avec [`check-git-sync.sh`](../.local/bin/check-git-sync.sh).

---

## Section développeur

### Architecture interne

`main()` déroule six étapes :

1. `parse_args` puis `check_not_root` — le refus de root vient avant tout le reste, y compris `--init`.
2. `init_dest` et sortie immédiate si `--init` a été demandé.
3. `check_deps` — `rsync` et `numfmt` sont obligatoires ; l'absence de `git` dégrade silencieusement vers `-G`, celle de `zstd` n'est fatale qu'avec `-a`.
4. `load_config` → `resolve_projects` — lecture du fichier vers `SPEC_PATH`/`SPEC_LABEL`/`EXCLUDE_PATTERNS`, puis résolution des globs et des collisions de noms vers `PROJ_PATH`/`PROJ_LABEL`.
5. `prepare_dest` → `setup_workdir` — détection ou validation de la destination, sonde de liens symboliques, contrôle d'espace, répertoire temporaire avec `trap`.
6. Boucle sur les projets : `git_state`, `sync_project`, `archive_project`, accumulation dans les tableaux `R_*` ; puis `render_table`, `write_report`, `warn_orphans` et calcul du code de sortie.

Les fonctions d'analyse communiquent par variables globales (`CUR_STATE`, `CUR_DETAIL`, `GIT_LABEL`, `GIT_SEV`) : une fonction bash ne rend qu'un entier, et sérialiser un tuple à travers `stdout` obligerait à re-parser une chaîne à chaque appel. C'est la convention déjà retenue par [`check-git-sync.sh`](../.local/bin/check-git-sync.sh).

### Détail des choix techniques

**Miroir plutôt qu'archive.** Une archive `.tar.zst` de la liste complète relit l'intégralité des sources à chaque lancement. Mesuré sur cette machine, un projet sur `/mnt/f` se lit à ~19 Mo/s (montage 9p) contre ~97 Mo/s sur `ext4` : quelques giga-octets de cours coûtent alors plusieurs minutes, chaque soir, même sans avoir rien modifié. Le miroir ramène les passes suivantes au différentiel — deux secondes en pratique. Accessoirement, sur le poste de la classe, une arborescence s'ouvre sans rien décompresser.

**`--delete-excluded` avec un garde-fou.** Le miroir est un vrai miroir : ce qui disparaît de la source disparaît de la clé, sans quoi il accumulerait indéfiniment des fichiers renommés. D'où un risque précis : un disque Windows non monté laisse un point de montage **vide**, et `rsync --delete` effacerait alors la sauvegarde du projet — exactement au moment où elle est le plus utile. `sync_project` refuse donc toute source dont `ls -A` ne rend rien, et laisse le miroir intact.

Encore faut-il ne pas crier au loup : un glob `~/projets/*` finit toujours par ramener un répertoire réellement vide. Le script tranche en comparant à l'état du miroir — source vide **et** miroir peuplé signale un disque disparu (rouge, code `1`) ; source vide et miroir vide ou inexistant n'est qu'une remarque (jaune, sans effet sur le code de retour). C'est le rôle de `CUR_SEV` : l'état affiché et la gravité réelle sont deux choses distinctes, et seule la seconde est comptée à la fin.

**`--modify-window=2`.** Les horodatages FAT et exFAT ont une granularité de deux secondes. Sans cette tolérance, `rsync` considère chaque fichier comme modifié et retransfère tout, à chaque passe : le caractère incrémental disparaît sans le moindre message d'erreur.

**Liens symboliques : sonde plutôt que déduction.** Le type de montage ne dit rien de la question. Sous WSL, une clé exFAT est vue comme du `v9fs`, exactement comme un disque NTFS qui, lui, accepte les liens. `detect_deref` crée donc un lien symbolique de test à la racine du support et le supprime aussitôt : si l'appel échoue, `--copy-links` est activé et les liens sont remplacés par leur cible. Le dépôt `dotfile` lui-même contient un lien (`docs` → `.config/yadm/alt/docs##class.devonly/`), le cas n'est pas théorique.

**Aucun accès réseau.** `git_state` compare `HEAD` à `@{u}` sans `fetch`. La sauvegarde doit fonctionner sur un réseau capricieux ou absent, et le script ne cherche pas à savoir si le distant a bougé : uniquement si des commits locaux risquent de n'exister nulle part ailleurs. Un `fetch` bloquant sur une authentification expirée, un soir de départ, serait le pire des comportements. Le diagnostic complet reste le rôle de `check-git-sync.sh`.

**Archives construites depuis le miroir.** `archive_project` lit `MIRROR_ROOT`, jamais la source. Le miroir est déjà expurgé des artefacts de développement, et il est local au support : relire un giga-octet à travers un montage 9p une seconde fois coûterait une minute pour un résultat identique.

**Rotation par tri lexicographique.** `rotate_archives` trie sur le **nom** de fichier, pas sur la date d'inode : l'horodatage `AAAAMMJJ_HHMM` se trie lexicographiquement comme chronologiquement, et les dates de fichiers d'un système FAT sont trop peu fiables (fuseau, granularité) pour arbitrer une suppression.

**Marqueur plutôt que chemin fixe.** Windows n'attribue pas toujours la même lettre à la même clé. Un chemin figé en configuration mène soit à un échec, soit — bien pire — à une écriture sur le mauvais disque. Le marqueur `.backup-projets` rend la détection indépendante de la lettre ; deux supports marqués font échouer le script en code `2` plutôt que de choisir à l'aveugle. Chaque test d'existence est borné par `timeout 3` : sous WSL, `/mnt/` expose aussi les lecteurs réseau Windows, dont un seul déconnecté suffirait à figer le script.

**Refus d'écrire sur le système de fichiers racine.** C'est le garde-fou né d'un incident réel : la clé montée sous Windows en `H:`, `backup-projets.sh --init /mnt/h`, une sauvegarde annoncée terminée — et rien sur la clé. Sous WSL, les lecteurs sont montés au démarrage de la distribution ; un support branché ensuite ne l'est pas, et `/mnt/h` reste le répertoire vide laissé par un montage précédent. Les 1,4 Go étaient partis dans le disque virtuel de WSL, invisibles depuis Windows, et `wsl` lancé depuis `H:\` répondait `Failed to translate 'H:\'` — le même symptôme vu de l'autre côté.

`check_real_medium` compare donc `stat -c %m` à `/` : si le répertoire n'est adossé à aucun montage propre, le script s'arrête en code `2` et affiche la commande de montage, déduite de la lettre. `detect_dest` applique le même filtre, pour qu'un marqueur déposé par erreur dans le disque de WSL ne fasse jamais élire cette destination. `--allow-local` lève le contrôle quand la destination locale est voulue.

Le test porte sur le montage et non sur le caractère amovible du support : sous WSL, une clé USB est vue exactement comme un disque interne (`v9fs`), et rien ne les distingue. Ce qui compte n'est pas que la destination soit une clé, mais qu'elle ne soit pas le disque virtuel de la distribution.

**Sonde de datation, pour la même raison.** `rsync` décide de recopier un fichier en comparant sa taille et sa date. Si le support refuse qu'on lui fixe une date, la destination porte celle de la copie : toujours différente de la source, donc **tout est recopié à chaque passe**. Le symptôme bruyant est une avalanche de `failed to set times … Operation not permitted` et un état `PARTIEL` ; le vrai dégât est la disparition silencieuse du caractère incrémental, précisément ce pour quoi le miroir a été choisi.

Sous WSL, la cause est presque toujours un montage drvfs manuel sans `uid=`. Les répertoires sont en 777, on peut donc y créer des fichiers — mais ils appartiennent à root, et seul le propriétaire d'un fichier peut en fixer la date. Les montages automatiques de WSL, eux, portent `uid=1000,gid=1000` : d'où un `/mnt/f` qui fonctionne et un `/mnt/h` monté à la main qui échoue, sur la même machine et avec le même type de système de fichiers. `detect_times` crée un fichier témoin, relève son propriétaire, tente un `touch -d`, et rend la main en code `2` avec la commande de remontage si l'opération est refusée. L'exFAT n'a rien à voir dans l'affaire : ce sont les options de montage.

`--no-times` bascule alors `rsync` en `--no-times --size-only`, seul critère qui reste déterministe quand les dates sont fausses. C'est une dégradation assumée, pas un mode normal : un fichier modifié sans changer de taille — une coquille corrigée dans une note — ne serait plus jamais sauvegardé.

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
| `tar` (GNU) | — | motifs `--exclude` sur le nom de base, `--ignore-failed-read` |
| `zstd` | 1.3 | `--long`, `-T0` |

`git`, `tar` et `zstd` ne sont requis que pour les fonctions qu'ils servent ; le script dégrade ou échoue explicitement dans `check_deps`.

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

### Notes de maintenance

- **`--dry-run` n'écrit rien**, pas même les répertoires du miroir : les `mkdir` sont conditionnés. Seule exception assumée, la sonde `detect_deref` crée puis supprime un lien à la racine du support, pour que la simulation reflète le comportement réel.
- **Le récapitulatif est rendu deux fois** par `render_table`, en mode `couleur` pour le terminal et `brut` pour le fichier déposé sur la clé — celui-ci doit rester lisible dans le Bloc-notes d'un poste Windows, où des séquences ANSI ne seraient que du bruit.
- **`pad()` compte les caractères, pas les octets.** `printf %-Ns` désaligne les colonnes dès qu'un nom de projet contient un accent. Même remarque que dans `check-git-sync.sh`.
- **La sortie de `rsync --stats` est relue** pour alimenter la colonne `DÉTAIL`, d'où le `LC_ALL=C` qui fige le format. Une évolution de `rsync` qui renommerait ces lignes ferait afficher `0 fichier(s)` sans autre symptôme : c'est le premier endroit à vérifier si le différentiel paraît toujours nul.
- **Les codes de sortie de `rsync` sont traités finement** : `24` (fichiers disparus pendant la copie, typiquement un éditeur ouvert) est bénin, `23` signale un transfert partiel — souvent un nom de fichier illégal sur exFAT (`:`, `?`, `*`) — et tout le reste est un échec. Un projet en échec n'interrompt pas la boucle : les suivants sont sauvegardés quand même.
- **Ne pas « simplifier » la gestion de l'interruption en supprimant le test des codes 20/130/143 dans `sync_project`.** C'est lui qui arrête la sauvegarde, pas le trap : sans lui, chaque projet réclamerait son propre Ctrl+C. Le trap seul donne une fausse impression de correction — il ne se déclenche que si l'enfant meurt du signal, ce qui n'est pas garanti.
- **`CURRENT_LABEL` doit être remis à vide** dès qu'un projet est consigné dans les tableaux `R_*`, sans quoi un arrêt survenu entre deux projets annoncerait à tort un miroir incomplet.
- **Les deux sondes de `prepare_dest` écrivent réellement sur le support**, y compris en `--dry-run` : un lien symbolique pour `detect_deref`, un fichier daté pour `detect_times`, tous deux supprimés dans la foulée. C'est assumé — une simulation qui ne testerait pas le support ne simulerait rien d'utile.
- **`stat -c %m` est le seul juge du montage.** `findmnt -T` donnerait la même information mais n'est pas garanti partout ; `mountpoint` échouerait sur un sous-répertoire d'un montage légitime, comme `--dest /mnt/g/sauvegardes`. Toute évolution de ce contrôle doit continuer à accepter un sous-répertoire d'un vrai montage et à refuser un `/mnt/<lettre>` fantôme.
- **La gravité d'un projet est portée par `CUR_SEV`/`R_SEV`**, pas par le libellé de la colonne `COPIE` : deux situations peuvent afficher `VIDE` sans peser pareil sur le code de retour. Ajouter un état, c'est lui attribuer une sévérité — `2` pour « la sauvegarde de ce projet n'est pas garantie », `1` pour une remarque.
- **Deux projets homonymes** sont désambiguïsés automatiquement par le nom de leur répertoire parent, avec un avertissement. Le miroir change alors de nom, donc l'ancien apparaîtra en orphelin à la passe suivante : mieux vaut fixer un nom explicite dans la configuration.
- **Le fichier `~/.config/backup-projets/projets.conf` n'est pas versionné** dans le dépôt, seul l'exemple `.sample` l'est — même convention que `usb-mount`. Il contient des chemins propres à la machine.
