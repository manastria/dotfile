# `install-projecteur.sh` — Installation de Projecteur

Installateur de **Projecteur** ([gbin/Projecteur](https://github.com/gbin/Projecteur)), pointeur laser virtuel pour les télécommandes de présentation Logitech Spotlight.

---

## Section utilisateur

### Description

Une télécommande Spotlight déplace un vrai faisceau laser : invisible dans un partage d'écran, invisible dans un enregistrement, souvent illisible sur un vidéoprojecteur. Projecteur intercepte les mouvements du boîtier et dessine le spot **à l'écran**, donc visible partout où l'écran l'est. Il gère aussi le zoom, la cartographie des boutons et un minuteur de présentation.

Projecteur n'est pas dans les dépôts Debian/Ubuntu. Le script offre deux voies :

| | Paquet publié (défaut) | Compilation (`--from-source`) |
| --- | --- | --- |
| Ce qu'on obtient | La dernière release, **v0.10 (octobre 2023)** | L'état courant de la branche, correctifs postérieurs compris |
| Coût | ~340 Ko, quelques secondes | ~300 Mo de paquets de développement, plusieurs minutes |
| Quand la choisir | Cas normal | Besoin d'un correctif récent, ou de la réécriture Plasma 6 |

### Le paquet de 2023 fonctionne-t-il encore ?

Oui, et cela mérite d'être expliqué, car le paquet le plus récent vise **Ubuntu 23.04** alors que le système peut être bien plus récent.

Le paquet déclare `Depends: … libqt5widgets5 (>= 5.7) …`. Ce nom a disparu d'Ubuntu 24.04, renommé `libqt5widgets5t64` par la transition time_t 64 bits — on pourrait donc croire le paquet définitivement inutilisable. Il n'en est rien : `libqt5widgets5t64` déclare `Provides: libqt5widgets5 (= 5.15.18+dfsg-1ubuntu1)`, un « fournit » **versionné** qui satisfait la dépendance. Apt installe donc le paquet sans broncher.

Vérifié sur Ubuntu 26.04 : le binaire de 2023 n'a aucune bibliothèque manquante (`ldd`) et `projecteur --version` répond `Projecteur 0.10`. Qt 5.15 est toujours fourni par Ubuntu, et l'ABI de Qt est stable à l'intérieur d'une version mineure.

Le script ne se contente pas de le supposer : avant d'installer, il exécute `apt-get --simulate` sur le paquet téléchargé et, en cas d'échec, renvoie vers `--from-source` plutôt que de laisser apt échouer à moitié.

### Deux branches, deux logiciels différents

Cette section ne concerne que `--from-source`. Le dépôt amont porte deux versions incompatibles.

| | `legacy/qt5` | `develop` |
| --- | --- | --- |
| Interface | Qt 5 | Qt 6.10+, natif KDE Plasma |
| Affichage | X11 (XWayland sous Wayland) | **Wayland uniquement** |
| Bureaux | XFCE, KDE, autres | **KDE Plasma 6.7+ uniquement** |
| Autres exigences | — | KPipeWire 6.7+, LayerShellQt 6.7+, KDE Frameworks 6.7+ |
| Sur Ubuntu 26.04 | **compilable** | **non compilable** : Ubuntu fournit Plasma 6.6.6, KPipeWire 6.6.4 et LayerShellQt 6.6.4 |

C'est aussi `legacy/qt5` qui produit les releases publiées. Sur **XUbuntu**, c'est la seule option, `develop` étant réservée à KDE. Sur **KUbuntu 26.04**, c'est la seule option compilable tant qu'Ubuntu n'a pas livré Plasma 6.7.

Sans `--branch`, le script ne retient `develop` que si la session est KDE **et** Wayland **et** que les versions exigées sont réellement disponibles dans APT. Sinon il prend `legacy/qt5` en expliquant pourquoi.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `curl` | Interrogation de l'API GitHub, téléchargement du paquet | `curl --version` |
| `apt-get` / `apt-cache` | Installation, simulation, versions candidates | `apt-get --version` |
| `dpkg` / `dpkg-deb` | Comparaison de versions, vérification de l'archive | `dpkg --version` |
| `sudo` | Installation, règles udev, module `uinput` | `sudo -V` |

Pour `--from-source`, tout le reste (`git`, `cmake`, compilateur, en-têtes Qt) est installé par le script.

Matériel pris en charge par `legacy/qt5` : Logitech Spotlight (`046d:c53e` en USB, `046d:b503` en Bluetooth) et les autres présentateurs listés dans `devices.conf` du dépôt amont.

### Syntaxe

```bash
install-projecteur.sh [-f] [--from-source] [--branch REF] [--src-dir DIR] [--jobs N] [--deps-only] [-h]
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-f`, `--force` | — | désactivé | Réinstalle même si la version publiée est déjà installée |
| `--from-source` | — | paquet publié | Compile depuis les sources |
| `--branch` | référence Git | `auto` | `legacy/qt5`, `develop`, `auto`, ou tout tag. **Implique `--from-source`** |
| `--src-dir` | chemin | `~/.local/src/Projecteur` | Où cloner et conserver les sources |
| `--jobs` | entier | `nproc` | Tâches de compilation parallèles |
| `--deps-only` | — | désactivé | Installe les dépendances de compilation et s'arrête. **Implique `--from-source`** |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage du script |

### Exemples d'utilisation

```bash
# Installation rapide depuis le paquet publié
install-projecteur.sh

# Compiler la branche courante, pour les correctifs postérieurs à v0.10
install-projecteur.sh --from-source

# XUbuntu, ou KDE en session X11 : imposer la version Qt5/X11
install-projecteur.sh --branch legacy/qt5

# Préparer une machine sans compiler tout de suite
install-projecteur.sh --deps-only
```

Sortie sur KUbuntu 26.04 (session Wayland), voie par défaut :

```text
=== Installation de Projecteur ===

[INFO]      Session : KDE / wayland
[INFO]      Distribution : ubuntu 26.04
[INFO]      Dernière release : v0.10
[INFO]      Aucun paquet pour ubuntu 26.04 : repli sur celui de ubuntu 23.04.
[INFO]      Téléchargement de projecteur-0.10_ubuntu-23.04-x86_64.deb…
######################################################################## 100,0%
[INFO]      Vérification des dépendances du paquet…
[INFO]      Des droits administrateur sont nécessaires (paquet, règles udev).
[sudo] Mot de passe de jpdemory :
[INFO]      Installation du paquet…
[OK]        Paquet projecteur 0.10.0-1 installé.
[INFO]      Chargement du module uinput…
[INFO]      Chargement de uinput au démarrage : /etc/modules-load.d/projecteur.conf
[INFO]      Rechargement des règles udev…
[OK]        Projecteur installé : Projecteur 0.10
[INFO]      Binaire : /usr/local/bin/projecteur
```

Second lancement, sans nouvelle release :

```text
[INFO]      Version déjà installée : 0.10.0-1
[OK]        Projecteur 0.10.0-1 est déjà à jour. Rien à faire.
[INFO]      Utilisez --force pour réinstaller, --from-source pour compiler plus récent.
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Projecteur installé, déjà à jour, dépendances installées (`--deps-only`), ou rien à faire |
| `1` | Erreur d'exécution : lancement en root, architecture non `amd64` (voie paquet), aucun paquet publié pour la distribution, dépendances non satisfaites, paquet APT introuvable, versions insuffisantes pour la branche demandée, échec du téléchargement, du clone, de la compilation ou de l'installation |
| `2` | Erreur d'usage : option inconnue, option à valeur sans argument, `--jobs` non numérique |

### Après l'installation

- **Rebranchez le récepteur USB** (ou reconnectez le Bluetooth). Les règles udev ne s'appliquent qu'au moment de la connexion : sans rebranchement, le périphérique reste inaccessible et Projecteur ne le voit pas.
- **Diagnostic** : `projecteur -d` (`--device-scan`) liste les périphériques vus et les droits d'accès ; `projecteur --fullversion` donne la version à joindre à un rapport de bogue.
- **Piloter une instance en cours** : `projecteur -c spot=toggle` allume ou éteint le spot, `projecteur -c settings=show` ouvre les préférences, `projecteur -c quit` quitte. La première commande se prête bien à un raccourci clavier global, et fonctionne sans aucun périphérique connecté.
- **Présentateur non reconnu** : `projecteur -D vendorId:productId` (par exemple `projecteur -D 04b3:310c`) ajoute un périphérique accepté, sans recompiler.
- **Mise à jour** : relancer le script. La voie par défaut compare la version publiée à celle installée et ne fait rien si elles coïncident ; `--from-source` fait un `git pull --ff-only` et recompile.
- **Désinstallation** : `sudo apt remove projecteur`, puis `sudo rm -f /etc/modules-load.d/projecteur.conf` et, le cas échéant, `rm -rf ~/.local/src/Projecteur`.

---

## Section développeur

### Architecture interne

`main()` enchaîne `check_not_root`, `check_arch`, `check_deps`, `detect_session`, puis bifurque.

**Voie paquet publié** (défaut) : `install_release_package`, qui appelle `select_asset_url` (API GitHub, choix de l'asset), télécharge, vérifie l'archive avec `dpkg-deb -f`, compare à la version installée, simule l'installation avec `apt-get -s`, puis seulement alors `sudo_warmup` et `apt-get install`.

**Voie compilation** (`--from-source`) : `resolve_branch` → `sudo_warmup` → `install_build_deps` → (arrêt si `--deps-only`) → `fetch_sources` → `build_sources` → `package_and_install`.

Les deux voies se rejoignent sur `setup_uinput`, `reload_udev`, `verify_install`.

### Détail des choix techniques

**Le paquet publié comme voie par défaut.** La première version de ce script compilait systématiquement, au motif que le `.deb` amont serait refusé par apt sur Ubuntu ≥ 24.04. **C'était faux**, et la simulation `apt-get -s install ./projecteur-0.10_ubuntu-23.04-x86_64.deb` le montre : la dépendance `libqt5widgets5` est satisfaite par le `Provides` versionné de `libqt5widgets5t64`. Imposer 300 Mo de chaîne de compilation pour un paquet de 340 Ko qui s'installe et s'exécute n'avait donc aucune justification. La compilation reste offerte, mais comme option.

**Simulation avant installation.** `install_release_package` exécute `apt-get -s install` sur le paquet téléchargé avant l'installation réelle. Le raisonnement sur le `Provides` ci-dessus est vrai sur Ubuntu 24.04 à 26.04 ; il n'est pas garanti indéfiniment, et rien ne dit qu'un futur paquet renommé conservera son `Provides`. La simulation transforme une hypothèse en vérification, et le message d'échec oriente vers `--from-source`. C'est aussi la raison pour laquelle le script **ne réécrit pas** les dépendances du paquet : ce serait corriger un problème qui n'existe pas.

**Le mot de passe demandé en dernier.** `sudo_warmup` n'est appelé qu'après la résolution de l'asset, le téléchargement, la vérification d'intégrité et la simulation. Rien de tout cela n'exige de droits, et un échec à ces étapes ne doit pas avoir fait saisir un mot de passe pour rien. La voie compilation, elle, a besoin de sudo dès l'installation des dépendances.

**Choix de l'asset : le plus élevé qui ne dépasse pas le système.** Les releases nomment leurs paquets `projecteur-<ver>_<distro>-<rel>-x86_64.deb` et s'arrêtent à `ubuntu-23.04`. `select_asset_url` trie les URL par version de distribution croissante (`sort -V`) puis retient la dernière qui satisfait `dpkg --compare-versions "$asset_rel" le "$release"`. Si la distribution est plus ancienne que tout ce qui est publié, il retombe sur la plus basse. Comportement vérifié :

| Système | Paquet retenu |
| ------- | ------------- |
| ubuntu 26.04 | `ubuntu-23.04` (le plus récent publié) |
| ubuntu 22.04 | `ubuntu-22.04` (correspondance exacte) |
| ubuntu 16.04 | `ubuntu-18.04` (repli vers le bas) |
| debian 13 | `debian-12` |
| linuxmint 22 | échec explicite, orientation vers `--from-source` |

**`dpkg --compare-versions` pour comparer des numéros de distribution.** Il ordonne correctement `20.04 < 20.10 < 21.04 < 23.04` là où une comparaison numérique naïve placerait `20.10` avant `20.04`, et traite aussi bien les numéros Debian à un seul chiffre.

**Idempotence par comparaison de la version dpkg.** Le paquet ne pesant que ~340 Ko, il est téléchargé d'abord et sa version lue par `dpkg-deb -f "$deb" Version`, puis comparée à `dpkg-query -W`. Inutile de déduire la version du nom de fichier ou du tag : la source d'autorité est le paquet lui-même.

**Préfixe `/usr/local` en compilation.** C'est le préfixe des paquets publiés. Le conserver évite qu'une compilation et un paquet publié se disputent les mêmes chemins, et `/usr/local/share` fait partie de `XDG_DATA_DIRS`, donc le `.desktop` apparaît bien au menu.

**`dist-package` plutôt que `cmake --install`.** La cible CPack amont produit un `.deb` : le résultat d'une compilation reste connu de dpkg et se désinstalle par `apt remove`, au lieu d'éparpiller des fichiers non suivis sous `/usr/local`.

**Une seule valeur pour « paquet indisponible ».** `apt-cache policy` distingue deux échecs : nom inconnu (aucune sortie) et nom connu sans version installable (`Candidat : (aucun)`). `apt_candidate_version` ramène les deux à la chaîne vide, pour que les appelants n'aient qu'un cas à tester.

**Vérification des paquets avant `apt-get`.** `install_build_deps` interroge APT pour chaque nom avant l'appel. Un seul nom inconnu ferait échouer l'appel sur la liste entière avec un message peu exploitable ; le tri préalable nomme les manquants. Cela compte surtout pour `develop`, dont les vingt-quatre paquets Qt6/KF6 changent de nom d'une Ubuntu à l'autre.

**Clone complet, sans `--depth 1`.** `cmake/modules/GitVersion.cmake` construit le numéro de version par `git describe`. Un clone superficiel sans tags produirait une version fantaisiste, inscrite dans le paquet et retournée par `--version`. Le dépôt ne pèse que ~4 Mo.

**`uinput` rendu persistant.** Projecteur capte le périphérique puis réinjecte les événements via `/dev/uinput`. Le `postinst` amont se contente d'un `modprobe uinput`, perdu au redémarrage. Le script écrit en plus `/etc/modules-load.d/projecteur.conf`. Les règles udev, elles, utilisent `TAG+="uaccess"` : l'accès va à l'utilisateur de la session graphique, sans ajout à un groupe.

**Tier 2 plutôt que Tier 1.** Téléchargement, sources et compilation appartiennent à l'utilisateur ; seules l'installation et les règles udev exigent root. En root, les sources atterriraient dans `/root` et `detect_session` lirait un environnement graphique qui n'est pas celui de l'utilisateur.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `curl` | ≥ 7.21 | `-fsSL` sur l'API GitHub et les redirections de release |
| `apt-get` | ≥ 1.1 | `-s install <fichier.deb>` : simulation sur un paquet local |
| `apt-cache` | toute version | `policy` pour la version candidate |
| `dpkg` | ≥ 1.16 | `--compare-versions` pour les versions de distribution et de composants |
| `dpkg-deb` | ≥ 1.16 | `-f` pour lire les champs de contrôle sans extraire |
| `git` | ≥ 2.0 | `clone --branch`, `pull --ff-only` (voie compilation) |
| `cmake` | ≥ 3.20 (`develop`) / ≥ 3.6 (`legacy/qt5`) | Minimums déclarés par les `CMakeLists` amont |
| `bash` | ≥ 4 | `mapfile`, tableaux `readonly -a`, expansion `${raw^^}` |

### Points d'extension

**Une nouvelle release paraît.** Rien à modifier : `select_asset_url` lit `releases/latest` à chaque exécution et le choix de l'asset s'adapte. Le jour où des paquets `ubuntu-26.04` sont publiés, ils seront retenus automatiquement.

**Distribution dérivée (Linux Mint, Pop!\_OS…).** `select_asset_url` lit `ID` dans `/etc/os-release` et ne trouve alors aucun asset. Pour retomber sur les paquets Ubuntu, se rabattre sur `ID_LIKE` :

```bash
distro="$(. /etc/os-release && echo "${ID}")"
if ! grep -q "_${distro}-" <<< "$json"; then
    distro="$(. /etc/os-release && echo "${ID_LIKE%% *}")"
fi
```

Il faudrait aussi convertir le numéro de version de la dérivée en son équivalent Ubuntu, ce que `/etc/os-release` ne donne pas toujours — d'où le choix de ne pas le faire par défaut.

**Ubuntu livre enfin Plasma 6.7.** Rien à modifier : `develop_requirements_met` interroge APT à chaque exécution et `resolve_branch` bascule seul.

**Le CMakeLists amont relève ses exigences.** Reporter les nouveaux minimums dans `DEVELOP_MIN_VERSIONS`, qui reproduit un à un les `find_package()` de la branche `develop`.

**Ajout d'une option `--uninstall`.** Elle enchaînerait `sudo apt-get remove -y projecteur`, `sudo rm -f "$MODULES_CONF"`, `sudo udevadm control --reload-rules`, et proposerait d'effacer `--src-dir`.

### Reprise des tests

État au **20 août 2026** : le script a été exécuté jusqu'à l'appel à `sudo`, qui n'a pas pu aboutir faute de terminal interactif. Tout ce qui précède cet appel est vérifié ; la suite ne l'est pas.

La distinction qui compte pour planifier une reprise : **la majorité des tests restants ne demande pas le récepteur Spotlight.** Projecteur démarre et s'utilise sans périphérique — le dépôt amont documente d'ailleurs un mode sans appareil (*device-free use*, [`doc/USER-GUIDE.md`](https://github.com/gbin/Projecteur/blob/legacy/qt5/doc/USER-GUIDE.md)). Seule la chaîne d'accès au matériel exige le boîtier.

#### Tests réalisables sans le récepteur

| # | Test | Commande | Résultat attendu |
| - | ---- | -------- | ---------------- |
| 1 | Installation par défaut | `install-projecteur.sh` | `[OK] Paquet projecteur 0.10.0-1 installé`, puis `[OK] Projecteur installé : Projecteur 0.10` |
| 2 | Binaire en place | `command -v projecteur && projecteur --version` | `/usr/local/bin/projecteur` et `Projecteur 0.10` |
| 3 | Règles udev posées | `ls -l /lib/udev/rules.d/55-projecteur.rules` | Fichier présent, appartenant à `root` |
| 4 | `uinput` chargé et persistant | `lsmod \| grep uinput ; ls -l /dev/uinput ; cat /etc/modules-load.d/projecteur.conf` | Module listé, `/dev/uinput` présent, fichier contenant `uinput` |
| 5 | Persistance réelle | Redémarrer, puis `lsmod \| grep uinput` | Module toujours chargé — c'est le seul test du `modules-load.d` |
| 6 | Entrée de menu | `ls /usr/local/share/applications/projecteur.desktop` puis chercher « Projecteur » au menu | Fichier présent, application listée |
| 7 | Lancement sans périphérique | `projecteur &` | L'interface s'ouvre ; aucun périphérique listé, ce qui est normal sans le récepteur |
| 8 | **Rendu du spot, sans matériel** | Instance lancée, puis `projecteur -c spot=toggle` | Le spot s'affiche à l'écran. Voir l'encadré ci-dessous : c'est le test décisif du rendu sous Wayland |
| 9 | Réglages | `projecteur -c settings=show` | La fenêtre de préférences s'ouvre (taille, couleur, opacité du spot) |
| 10 | Idempotence | Relancer `install-projecteur.sh` | `[OK] Projecteur 0.10.0-1 est déjà à jour. Rien à faire.` sans téléchargement |
| 11 | Réinstallation forcée | `install-projecteur.sh --force` | Réinstalle sans poser de question |
| 12 | Désinstallation | `sudo apt remove projecteur` | Suppression propre ; `/etc/modules-load.d/projecteur.conf` **subsiste** (voir *Notes de maintenance*) |
| 13 | Voie compilation | `install-projecteur.sh --from-source` | Installe ~300 Mo de dépendances, compile, produit un `.deb` et l'installe. **Entièrement non testé** |
| 14 | Dépendances seules | `install-projecteur.sh --deps-only` | S'arrête après l'installation des paquets |

> **Le test 8 est le plus important, et il ne demande aucun matériel.**
> `-c COMMAND` envoie une commande à une instance déjà lancée : `spot=toggle`
> allume le spot sans qu'aucun périphérique soit connecté. C'est donc là que se
> tranche la seule vraie inconnue de cette installation — la branche
> `legacy/qt5` est une application **X11** tournant via XWayland sous une session
> Plasma Wayland, et rien ne garantit que son incrustation se superpose
> correctement aux fenêtres natives Wayland.
>
> Promener le spot au-dessus de plusieurs fenêtres, dont au moins une application
> Wayland native (Konsole, Dolphin), et vérifier qu'il reste visible par-dessus.
> S'il disparaît ou clignote, ouvrir une session X11 et refaire le test : si le
> spot s'y comporte correctement, la cause est XWayland et non le paquet. Le
> remède définitif serait la branche `develop`, native Wayland — non compilable
> sur Ubuntu 26.04 tant qu'Ubuntu livre Plasma 6.6.

Le test 13 est le plus incertain : configuration CMake, compilation et cible `dist-package` n'ont jamais été exécutées. En cas d'échec, `install-projecteur.sh --from-source --jobs 1` rend les messages du compilateur plus lisibles. Attention, il installe une chaîne de compilation complète : à ne lancer que sur une machine où cela ne dérange pas.

#### Tests exigeant le récepteur Spotlight

| # | Test | Commande | Résultat attendu |
| - | ---- | -------- | ---------------- |
| 15 | Détection en USB | Brancher le récepteur **après** l'installation, puis `projecteur -d` | Le Spotlight `046d:c53e` est listé, avec accès en lecture/écriture |
| 16 | Droits `uaccess` effectifs | `ls -l /dev/hidraw*` récepteur branché | Un nœud accessible à l'utilisateur de la session, sans `sudo` ni ajout de groupe |
| 17 | Détection en Bluetooth | Appairer le boîtier, puis `projecteur -d` | Le `046d:b503` est listé |
| 18 | Suivi des mouvements | Lancer Projecteur, maintenir le bouton du Spotlight | Le spot apparaît et suit les mouvements |
| 19 | Réinjection par `uinput` | Appuyer sur les boutons suivant/précédent pendant une présentation | Les diapositives défilent : preuve que la capture du périphérique **et** la réinjection via `/dev/uinput` fonctionnent |

Le test 15 est le **premier** à faire une fois le boîtier disponible, et le rebranchement **après** installation n'est pas un détail : les règles udev n'attribuent les droits qu'au moment de la connexion du périphérique. Un récepteur resté branché pendant l'installation ne sera pas accessible, ce qui ressemble à s'y méprendre à un bogue.

Le test 19 est le seul à exercer `/dev/uinput`, donc le seul à valider `setup_uinput` et le fichier `modules-load.d` autrement que par la simple présence du module.

#### Revérifier les constats sans rien installer

Les affirmations de cette page sur la compatibilité du paquet de 2023 se recontrôlent sans droits root ni installation :

```bash
# Le paquet amont est-il toujours accepté par apt ?
curl -fsSLO https://github.com/gbin/Projecteur/releases/download/v0.10/projecteur-0.10_ubuntu-23.04-x86_64.deb
apt-get -s install ./projecteur-0.10_ubuntu-23.04-x86_64.deb

# Pourquoi la dépendance libqt5widgets5 est-elle satisfaite ?
apt-cache showpkg libqt5widgets5 | sed -n '/Reverse Provides/,$p'

# Le binaire tourne-t-il sur ce système ?
dpkg-deb -x projecteur-0.10_ubuntu-23.04-x86_64.deb /tmp/proj
ldd /tmp/proj/usr/local/bin/projecteur | grep "not found" || echo "aucune bibliothèque manquante"
/tmp/proj/usr/local/bin/projecteur --version

# Les listes de dépendances de compilation se résolvent-elles encore ?
install-projecteur.sh --deps-only   # s'arrête avant sudo si l'une manque
```

### Notes de maintenance

- **Ce qui a été vérifié sur Ubuntu 26.04**, sans les droits root : le binaire v0.10 s'exécute (`ldd` sans bibliothèque manquante, `--version` → `Projecteur 0.10`) ; `apt-get -s install` accepte le paquet amont tel quel ; `apt-cache showpkg libqt5widgets5` confirme le `Provides` de `libqt5widgets5t64` ; le choix d'asset est correct sur sept couples distribution/version ; les listes `DEPS_LEGACY` (31 paquets résolus) et `DEPS_DEVELOP` (92 paquets résolus) passent `apt-get -s install` ; le clone de `legacy/qt5` aboutit avec ses tags (`v0.10-8-g812a15d`) ; la cible `dist-package` est bien définie pour `ubuntu::DEB`.
- **Ce qui n'a pas été exécuté** est détaillé en tests numérotés dans *Reprise des tests* ci-dessus : les étapes exigeant `sudo`, toute la voie `--from-source`, et les cinq tests qui demandent le récepteur Spotlight.
- **La désinstallation est incomplète par construction.** `apt remove projecteur` retire le paquet et ses règles udev, mais pas `/etc/modules-load.d/projecteur.conf`, écrit par le script hors de tout paquet. `uinput` continuera donc d'être chargé au démarrage. C'est sans conséquence — le module est minuscule et utilisé par d'autres logiciels — mais c'est une trace laissée derrière, à supprimer à la main.
- **La branche `develop` reste non testée.** Sa liste `DEPS_DEVELOP` est déduite des `find_package()` du `CMakeLists` amont, pas d'un fichier officiel — le projet ne documente les noms de paquets que pour Arch Linux (`Justfile`). Les noms existent dans APT ; rien ne prouve qu'ils suffisent à compiler.
- **`find … -maxdepth 2 -name '*.deb'`** : CPack n'ayant pas de `CPACK_PACKAGE_DIRECTORY` défini en amont, le paquet tombe dans `build/`. Si une version future change cet emplacement, c'est cette ligne qu'il faut ajuster.
- **Le dépôt amont a changé de mainteneur en 2026** (Jahn Fuchs → Guillaume Binet) et `develop` est une réécriture. Si `legacy/qt5` disparaissait, se rabattre sur le tag `v0.10`, que le script accepte via `--branch v0.10`.
