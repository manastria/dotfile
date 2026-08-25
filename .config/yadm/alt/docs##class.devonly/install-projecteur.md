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
| Affichage | X11, et Wayland **à condition de forcer XWayland** (voir ci-dessous) | **Wayland uniquement** |
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
[INFO]      uinput est intégré au noyau : aucun chargement à prévoir au démarrage.
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
- **Sur session Wayland, lancez Projecteur depuis le menu**, pas par un `projecteur` nu en terminal. Le script installe un lanceur qui force XWayland ; sans lui, le spot fige la souris (voir *Le piège Wayland*). En terminal : `QT_QPA_PLATFORM=xcb projecteur`.
- **Le spot s'allume au mouvement, pas sur un bouton.** C'est le point le moins intuitif, et il n'est écrit nulle part dans l'interface. Projecteur ne guette pas un bouton précis : il surveille les **événements de déplacement souris** émis par le présentateur. Sur le Logitech Spotlight, c'est le **bouton pointeur** — celui du haut, marqué de deux cercles concentriques — qui met le boîtier en mode pointeur : il envoie alors des mouvements, le curseur se déplace, et le spot apparaît. Relâcher l'éteint. Les boutons *Next* et *Back*, eux, n'envoient que des flèches clavier et n'allument jamais le spot.
- **La télécommande s'endort.** Le journal affiche `HID++ device … went offline` après quelques secondes d'inactivité, puis `came online` au réveil. C'est normal, c'est l'économie de batterie du boîtier. Conséquence pratique : le **premier appui réveille** le périphérique sans déclencher d'action. Un second appui est nécessaire. Un boîtier endormi qui « ne répond pas » n'est donc pas un dysfonctionnement.
- **Mapper les boutons** : onglet *Input Mapper* de la fenêtre de préférences (`projecteur -c settings=show`). Un appui bref et un appui long se mappent en les exécutant simplement sur le boîtier. Le troisième geste — *maintenir et bouger* — se mappe par un clic droit dans la colonne *Input Sequence*, le périphérique devant être réveillé au préalable. Ne pas mapper à la fois l'appui long et le maintien-mouvement sur le même bouton : les deux actions se déclencheraient ensemble.
- **L'action *Volume Control* ne fonctionne pas** en v0.10, et aucun réglage n'y changera rien : c'est un défaut amont. Voir *Notes de maintenance*.
- **Le défilement exige un mouvement vertical franc, et le bon axe.** *Scroll Vertical* ne lit que la composante **verticale** du mouvement (octet 7 du message HID++) ; *Scroll Horizontal* lit l'octet 5. Un geste latéral déclenche donc bien l'action — la trace `execAction, type = Type::ScrollVertical` apparaît en journal — mais avec un paramètre nul, et **rien n'est émis**. Incliner le boîtier **de haut en bas**, pas de côté.
- **Et un mouvement assez vif.** Le seuil porte sur la *vitesse*, pas sur la distance : en dessous de 5 (sur une échelle de -128 à 127), la composante est ramenée à zéro. Un geste lent n'émet jamais rien.
- **Le défilement atterrit sous le curseur, pas sous le focus.** Il est émis en `REL_WHEEL` par la souris virtuelle : il agit sur la fenêtre **survolée par le pointeur**, comme une molette. Or maintenir *Next* ne déplace pas le curseur — seul le bouton pointeur le fait. Placer d'abord le curseur sur la zone à faire défiler.
- **Diagnostic** : `projecteur -d` (`--device-scan`) liste les périphériques vus et les droits d'accès ; `projecteur --fullversion` donne la version à joindre à un rapport de bogue.
- **Piloter une instance en cours** : `projecteur -c spot=toggle` allume ou éteint le spot, `projecteur -c settings=show` ouvre les préférences, `projecteur -c quit` quitte. La première commande se prête bien à un raccourci clavier global, et fonctionne sans aucun périphérique connecté.
- **Présentateur non reconnu** : `projecteur -D vendorId:productId` (par exemple `projecteur -D 04b3:310c`) ajoute un périphérique accepté, sans recompiler.
- **Messages de journal sans gravité**, qu'il est inutile de chercher à faire disparaître :

| Message | Sens |
| ------- | ---- |
| `Settings file '…/Projecteur.conf' not readable` / `not writable` | Premier lancement, avant création du fichier. Il apparaît une seule fois ; vérifier ensuite que `~/.config/Projecteur/Projecteur.conf` existe et contient les réglages |
| `HID++ device '/dev/hidrawN' went offline` puis `came online` | Mise en veille et réveil du boîtier |
| `Wayland does not support QWindow::requestActivate()` | Émis à chaque affichage du spot sous XWayland. Sans effet sur le rendu |
- **Mise à jour** : relancer le script. La voie par défaut compare la version publiée à celle installée et ne fait rien si elles coïncident ; `--from-source` fait un `git pull --ff-only` et recompile.
- **Désinstallation** : `sudo apt remove projecteur`, puis `rm -f ~/.local/share/applications/projecteur.desktop`, `sudo rm -f /etc/modules-load.d/projecteur.conf` s'il existe, et, le cas échéant, `rm -rf ~/.local/src/Projecteur`.

---

## Section développeur

### Architecture interne

`main()` enchaîne `check_not_root`, `check_arch`, `check_deps`, `detect_session`, puis bifurque.

**Voie paquet publié** (défaut) : `install_release_package`, qui appelle `select_asset_url` (API GitHub, choix de l'asset), télécharge, vérifie l'archive avec `dpkg-deb -f`, compare à la version installée, simule l'installation avec `apt-get -s`, puis seulement alors `sudo_warmup` et `apt-get install`.

**Voie compilation** (`--from-source`) : `resolve_branch` → `sudo_warmup` → `install_build_deps` → (arrêt si `--deps-only`) → `fetch_sources` → `build_sources` → `package_and_install`.

Les deux voies se rejoignent sur `setup_uinput` et `reload_udev` — **uniquement si quelque chose a été installé**, ces étapes exigeant `sudo` et n'ayant rien à faire sinon — puis sur `setup_wayland_launcher` et `verify_install`, qui s'exécutent toujours. C'est par là qu'une machine installée avant l'ajout du lanceur Wayland le reçoit, par simple relance du script et sans mot de passe.

### Détail des choix techniques

**Le paquet publié comme voie par défaut.** La première version de ce script compilait systématiquement, au motif que le `.deb` amont serait refusé par apt sur Ubuntu ≥ 24.04. **C'était faux**, et la simulation `apt-get -s install ./projecteur-0.10_ubuntu-23.04-x86_64.deb` le montre : la dépendance `libqt5widgets5` est satisfaite par le `Provides` versionné de `libqt5widgets5t64`. Imposer 300 Mo de chaîne de compilation pour un paquet de 340 Ko qui s'installe et s'exécute n'avait donc aucune justification. La compilation reste offerte, mais comme option.

**Simulation avant installation.** `install_release_package` exécute `apt-get -s install` sur le paquet téléchargé avant l'installation réelle. Le raisonnement sur le `Provides` ci-dessus est vrai sur Ubuntu 24.04 à 26.04 ; il n'est pas garanti indéfiniment, et rien ne dit qu'un futur paquet renommé conservera son `Provides`. La simulation transforme une hypothèse en vérification, et le message d'échec oriente vers `--from-source`. C'est aussi la raison pour laquelle le script **ne réécrit pas** les dépendances du paquet : ce serait corriger un problème qui n'existe pas.

**Le mot de passe demandé en dernier.** `sudo_warmup` n'est appelé qu'après la résolution de l'asset, le téléchargement, la vérification d'intégrité et la simulation. Rien de tout cela n'exige de droits, et un échec à ces étapes ne doit pas avoir fait saisir un mot de passe pour rien. La voie compilation, elle, a besoin de sudo dès l'installation des dépendances.

**Le piège Wayland : forcer XWayland.** C'est le défaut le plus grave rencontré à l'usage, et il rend Projecteur inutilisable sans correctif. Sous une session Wayland, Qt5 sélectionne tout seul son plugin `wayland`. Or Projecteur rend son incrustation plein écran traversable par `Qt::WindowTransparentForInput`, drapeau que le plugin Wayland de Qt5 **n'implémente pas**. La fenêtre avale alors tous les clics : le spot s'affiche, puis la souris reste prisonnière jusqu'à ce que l'application soit tuée.

L'amont connaît le problème, mais ne le traite que pour la plateforme `xcb` (`src/projecteurapp.cc`) :

```cpp
// Workaround for 'xcb' on Wayland session (default on Ubuntu)
// .. the window in that case is not transparent for inputs and cannot be clicked through.
// --> hide the window, although animations will not be visible
if (m_xcbOnWayland) { window->hide(); }
```

Le contournement — masquer la fenêtre quand le spot s'éteint — est conditionné à `platformName() == "xcb" && isWayland()`. Sur le plugin Wayland natif, il ne se déclenche donc **jamais**. Le commentaire « default on Ubuntu » date d'une époque où Qt retombait sur `xcb` ; ce n'est plus le cas.

D'où `setup_wayland_launcher`, qui écrit un lanceur personnel dans `~/.local/share/applications/projecteur.desktop` préfixant la commande par `env QT_QPA_PLATFORM=xcb`. Ce fichier masque celui du paquet, `XDG_DATA_HOME` primant sur `XDG_DATA_DIRS`, et n'est posé que sur une session Wayland. Il est régénéré à chaque exécution depuis le fichier du paquet, pour suivre un changement amont, et porte `X-Generated-By=install-projecteur.sh` : un lanceur personnel dépourvu de cette marque est conservé, jamais écrasé.

Deux limites assumées. Le lanceur ne couvre pas un démarrage depuis un terminal — `verify_install` rappelle alors d'utiliser `QT_QPA_PLATFORM=xcb projecteur`. Et la branche `develop`, nativement Wayland, en est exclue : lui imposer XWayland serait une régression.

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

**`uinput` : trois états, pas deux.** Projecteur capte le périphérique puis réinjecte les événements via `/dev/uinput`, et le `postinst` amont se contente d'un `modprobe uinput` perdu au redémarrage. Une première version de `setup_uinput` écrivait donc systématiquement `/etc/modules-load.d/projecteur.conf` — ce qui est inutile sur les noyaux Ubuntu récents, où `CONFIG_INPUT_UINPUT=y` intègre uinput au noyau : il n'y a alors aucun module à charger, et le fichier n'est qu'un résidu.

La fonction distingue maintenant les trois cas, en s'appuyant sur `/sys/module/uinput`, seul moyen fiable de séparer *module chargé* de *intégré au noyau* — `lsmod` ne liste jamais le second :

| `/dev/uinput` | `/sys/module/uinput` | Situation | Action |
| --- | --- | --- | --- |
| absent | — | module non chargé | `modprobe`, puis réévaluation |
| présent | absent | intégré au noyau | rien, et surtout pas de `modules-load.d` |
| présent | présent | module chargé | écrire `modules-load.d` pour le prochain démarrage |

Les règles udev, elles, utilisent `TAG+="uaccess"` : l'accès à `/dev/uinput` et au récepteur passe par une ACL posée sur l'utilisateur de la session graphique, sans ajout à un groupe.

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

État au **25 août 2026**. La voie par défaut est **entièrement validée sur matériel réel**, du téléchargement jusqu'à la réinjection des touches : tests 1 à 4, 6, 8, 10, 15, 16 et 19 confirmés. Le test 17 est sans objet (boîtier sans Bluetooth).

Un seul défaut bloquant a été trouvé à l'usage, et il est corrigé : sur session Wayland, le spot figeait la souris. Voir *Le piège Wayland* dans la section développeur — c'est le correctif le plus important de ce script.

Restent ouverts : le test 5 (persistance après redémarrage), les tests 11 à 14, et **toute la voie `--from-source`, jamais exécutée**.

La distinction qui compte pour planifier une reprise : **la majorité des tests restants ne demande pas le récepteur Spotlight.** Projecteur démarre et s'utilise sans périphérique — le dépôt amont documente d'ailleurs un mode sans appareil (*device-free use*, [`doc/USER-GUIDE.md`](https://github.com/gbin/Projecteur/blob/legacy/qt5/doc/USER-GUIDE.md)). Seule la chaîne d'accès au matériel exige le boîtier.

#### Tests réalisables sans le récepteur

| # | Test | Commande | Résultat attendu |
| - | ---- | -------- | ---------------- |
| 1 | Installation par défaut | `install-projecteur.sh` | ✅ **Validé** : paquet `0.10.0-1` installé |
| 2 | Binaire en place | `command -v projecteur && projecteur --version` | ✅ **Validé** : `/usr/local/bin/projecteur`, `Projecteur 0.10` |
| 3 | Règles udev posées | `ls -l /lib/udev/rules.d/55-projecteur.rules` | ✅ **Validé** : présent, `root:root`, 2054 octets |
| 4 | `uinput` disponible | `ls -l /dev/uinput ; ls -d /sys/module/uinput` | ✅ **Validé** : `/dev/uinput` présent avec une ACL `user:<vous>:rw-` posée par `uaccess`. `/sys/module/uinput` **absent** = uinput intégré au noyau (`CONFIG_INPUT_UINPUT=y`), donc aucun `modules-load.d` à écrire |
| 5 | Persistance après redémarrage | Redémarrer, puis `ls -l /dev/uinput` | `/dev/uinput` présent. **Ne pas tester avec `lsmod`** : uinput étant intégré, il n'apparaît jamais dans la liste des modules |
| 6 | Entrée de menu | `ls /usr/local/share/applications/projecteur.desktop` puis chercher « Projecteur » au menu | ✅ **Validé** : fichier présent. Sur session Wayland, c'est le lanceur personnel qui le masque (voir *Le piège Wayland*) |
| 7 | Lancement sans périphérique | `projecteur &` | L'interface s'ouvre ; aucun périphérique listé, ce qui est normal sans le récepteur |
| 8 | **Rendu du spot, sans matériel** | Instance lancée, puis `projecteur -c spot=toggle` | Le spot s'affiche à l'écran. Voir l'encadré ci-dessous : c'est le test décisif du rendu sous Wayland |
| 9 | Réglages | `projecteur -c settings=show` | La fenêtre de préférences s'ouvre (taille, couleur, opacité du spot) |
| 10 | Idempotence | Relancer `install-projecteur.sh` | ✅ **Validé** : `Projecteur 0.10.0-1 est déjà à jour : rien à installer`, sans `sudo`. Le `.deb` est bien retéléchargé (340 Ko) — c'est lui qui fournit la version de référence |
| 11 | Réinstallation forcée | `install-projecteur.sh --force` | Réinstalle sans poser de question |
| 12 | Désinstallation | `sudo apt remove projecteur` | Suppression propre. `/etc/modules-load.d/projecteur.conf` **subsiste** s'il a été écrit — il ne l'est plus sur un noyau où uinput est intégré |
| 13 | Voie compilation | `install-projecteur.sh --from-source` | Installe ~300 Mo de dépendances, compile, produit un `.deb` et l'installe. **Entièrement non testé** |
| 14 | Dépendances seules | `install-projecteur.sh --deps-only` | S'arrête après l'installation des paquets |

> **Le test 8 est le plus important, et il ne demande aucun matériel.**
> `-c COMMAND` envoie une commande à une instance déjà lancée : `spot=toggle`
> allume le spot sans qu'aucun périphérique soit connecté. ✅ **Validé le
> 25/08/2026**, mais seulement après le correctif décrit dans *Le piège Wayland*
> ci-dessous : sans lui, le spot s'affiche et **la souris reste prisonnière**.
>
> Promener le spot au-dessus de plusieurs fenêtres, dont au moins une application
> Wayland native, et vérifier qu'il reste visible par-dessus **et** que la souris
> se libère quand le spot s'éteint. Ce second point est le vrai test.

Le test 13 est le plus incertain : configuration CMake, compilation et cible `dist-package` n'ont jamais été exécutées. En cas d'échec, `install-projecteur.sh --from-source --jobs 1` rend les messages du compilateur plus lisibles. Attention, il installe une chaîne de compilation complète : à ne lancer que sur une machine où cela ne dérange pas.

#### Tests exigeant le récepteur Spotlight

| # | Test | Commande | Résultat attendu |
| - | ---- | -------- | ---------------- |
| 15 | Détection en USB | Brancher le récepteur **après** l'installation, puis `projecteur -d` | ✅ **Validé le 25/08/2026** : `Found 1 supported devices. (1 readable, 1 writable)`, `Logitech Spotlight (USB)` `046d:c53e` sur `/dev/hidraw6` |
| 16 | Droits `uaccess` effectifs | Récepteur branché : `ls -l /dev/hidraw*` | ✅ **Validé** par le `readable: true` / `writable: true` du test 15, sans `sudo` ni ajout à un groupe |
| 17 | Détection en Bluetooth | Appairer le boîtier, puis `projecteur -d` | ⏭️ **Sans objet** sur le matériel disponible : le boîtier de test n'a pas de Bluetooth. À reprendre sur un Spotlight qui en dispose (`046d:b503`), les règles Bluetooth étant plus fragiles que celles de l'USB — trois règles distinctes (`input`, `hid`) côté amont |
| 18 | Suivi des mouvements | Instance lancée, **maintenir le bouton pointeur** (celui du haut, deux cercles concentriques) et déplacer le boîtier | ✅ **Validé le 25/08/2026** : le spot apparaît et le curseur suit les mouvements |
| 19 | Réinjection par `uinput` | Ouvrir un éditeur de texte, réveiller le boîtier, appuyer sur suivant/précédent | ✅ **Validé le 25/08/2026**. La boucle complète — `EVIOCGRAB`, recherche de correspondance, réémission par `uinput` — fonctionne. Voir l'explication ci-dessous |

Le test 15 est le **premier** à faire une fois le boîtier disponible, et le rebranchement **après** installation n'est pas un détail : les règles udev n'attribuent les droits qu'au moment de la connexion du périphérique. Un récepteur resté branché pendant l'installation ne sera pas accessible, ce qui ressemble à s'y méprendre à un bogue.

#### Ce que vérifie le test 19

C'est le seul test qui exerce `/dev/uinput`, et le seul dont l'échec est silencieux et déroutant. Il faut comprendre ce que fait Projecteur pour savoir ce qu'on observe.

Projecteur ne se contente pas de lire le présentateur : il le **confisque**. Il appelle `EVIOCGRAB` sur les nœuds d'événements du récepteur, ce qui interrompt leur acheminement normal vers les applications. Il crée en parallèle deux périphériques virtuels via `/dev/uinput`, puis leur réémet les événements interceptés — inchangés s'il n'existe aucune correspondance dans l'*Input Mapper*, remplacés par l'action mappée sinon.

Sur la machine de test, Projecteur étant lancé, la chaîne est directement observable :

```console
$ ls -l /proc/$(pgrep projecteur)/fd | grep -E 'event|hidraw|uinput'
-> /dev/uinput          # les deux périphériques virtuels
-> /dev/uinput
-> /dev/hidraw6         # canal HID++ : veille, batterie, événements « hold »
-> /dev/input/event19   # les quatre nœuds du récepteur, confisqués
-> /dev/input/event20
-> /dev/input/event21
-> /dev/input/event22

$ grep -A1 Projecteur /proc/bus/input/devices
N: Name="Projecteur_virtual_mouse"
N: Name="Projecteur_virtual_keyboard"
```

D'où l'intérêt du test : **appuyer sur « suivant » exerce la boucle entière** — capture par `EVIOCGRAB`, recherche d'une correspondance, réémission par `uinput`, prise en compte par l'application. Aucun autre test ne la parcourt : l'affichage du spot n'a besoin ni de la confiscation ni de `uinput`.

Le mode de défaillance justifie à lui seul le test. Si `/dev/uinput` est inaccessible, la confiscation peut malgré tout réussir : les événements physiques sont alors interceptés puis **jetés faute de destination**. Les boutons du présentateur deviennent inertes — y compris ceux qu'on n'a jamais configurés — alors que le spot continue de s'afficher normalement, et rien dans l'interface ne le signale. Le remède est `projecteur --disable-uinput` : la confiscation est abandonnée, les boutons retrouvent leur comportement natif, et seule la cartographie des boutons est perdue.

Un mot sur l'accès à `/dev/uinput` : le nœud appartient à `root:root` en `crw-rw----`, mais porte une ACL `user:<vous>:rw-` posée par la règle `KERNEL=="uinput", …, TAG+="uaccess"` de `55-projecteur.rules`. C'est ce mécanisme, et non une appartenance de groupe, qui donne l'accès à l'utilisateur de la session.

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
- **Ce qui reste à exécuter** est détaillé en tests numérotés dans *Reprise des tests* ci-dessus. L'essentiel : **la voie `--from-source` n'a jamais été lancée**, ni configuration CMake, ni compilation, ni cible `dist-package`.
- **Le seul défaut bloquant trouvé à l'usage était le piège Wayland**, pas une erreur d'installation. Les vérifications hors matériel — résolution d'asset, dépendances, droits — étaient toutes justes ; ce qui manquait ne pouvait se voir qu'en utilisant l'application. À garder en tête pour le prochain installateur d'application graphique : une installation vérifiée n'est pas une application utilisable.
- **La désinstallation est incomplète par construction.** `apt remove projecteur` retire le paquet et ses règles udev, mais pas `/etc/modules-load.d/projecteur.conf` quand le script l'a écrit, ce fichier vivant hors de tout paquet. Sans conséquence — uinput est minuscule et sert à d'autres logiciels — mais c'est une trace à supprimer à la main.
- **Un `projecteur.conf` peut subsister d'une version antérieure du script**, qui écrivait ce fichier sans vérifier si uinput était intégré au noyau. Sur une machine installée avant le 25 août 2026, `sudo rm -f /etc/modules-load.d/projecteur.conf` est sans risque dès lors que `/sys/module/uinput` n'existe pas.
- **La branche `develop` reste non testée.** Sa liste `DEPS_DEVELOP` est déduite des `find_package()` du `CMakeLists` amont, pas d'un fichier officiel — le projet ne documente les noms de paquets que pour Arch Linux (`Justfile`). Les noms existent dans APT ; rien ne prouve qu'ils suffisent à compiler.
- **`find … -maxdepth 2 -name '*.deb'`** : CPack n'ayant pas de `CPACK_PACKAGE_DIRECTORY` défini en amont, le paquet tombe dans `build/`. Si une version future change cet emplacement, c'est cette ligne qu'il faut ajuster.
- **Défaut amont : l'action *Volume Control* ne peut pas fonctionner en v0.10.** `spotlight.cc` émet `KEY_VOLUMEUP` / `KEY_VOLUMEDOWN` (codes 115 et 114) via `m_virtualMouseDevice`. Or `virtualdevice.cc` ne déclare, pour la souris virtuelle, que les codes de `BTN_MISC` (256) à `KEY_OK` (352) : les touches de volume, en dessous de 256, n'y figurent pas, et le noyau écarte silencieusement tout événement dont le code n'est pas déclaré. Vérifié sur la machine de test en décodant `B: KEY=` dans `/proc/bus/input/devices` : `KEY_VOLUMEUP` est absent de `Projecteur_virtual_mouse` et présent sur `Projecteur_virtual_keyboard`. Le correctif amont tiendrait en un mot — émettre par `m_virtualKeyboardDevice` — mais il impose de recompiler (`--from-source`).

  Piège de méthode : les mots de `B: KEY=` valent 64 bits chacun, poids fort en tête, **zéros de tête supprimés à l'affichage**. Les concaténer selon leur longueur de chaîne décale tout le masque et produit des résultats absurdes — `BTN_LEFT` non déclaré sur une souris, par exemple. Il faut décaler par position : `valeur |= mot << (64 * (n - 1 - i))`.

- **La trace `execAction` ne prouve pas qu'un événement a été émis.** Elle est journalisée dans `deviceinput.cc:630`, en amont du gestionnaire de `spotlight.cc`, lequel se termine par `if (param)`. Une action peut donc être répartie avec un paramètre nul et ne rien produire. Le calcul, dans `spotlight.cc` autour de la ligne 505 : `x = msg[5]`, `y = msg[7]`, chacun réduit par `getReducedParam` qui renvoie 0 sous le seuil de 5, puis `return` anticipé **seulement si les deux axes sont nuls**. D'où le cas déroutant : un mouvement purement latéral passe le `return` grâce à `x`, journalise `ScrollVertical`, et n'émet rien puisque `scrollVAction->param = adjustedY` vaut 0. Diagnostiquer par la seule présence de la trace mène donc à une fausse piste.

- **L'*Input Mapper* « hold move » n'a pas pu être fait fonctionner** sur la v0.10, malgré une configuration correcte (`NextHoldMove` → `ScrollVertical` bien enregistré) et des actions effectivement réparties — la trace `execAction` apparaît à chaque geste. Le défilement n'a jamais produit d'effet, et *Volume Control* ne le peut pas par construction (voir ci-dessus). Piste non explorée : instrumenter `msg[5]` et `msg[7]` dans `spotlight.cc` pour voir les valeurs réellement reçues, ce qui impose de recompiler.

- **Recompiler ne corrigerait rien**, et c'est vérifié plutôt que supposé. La branche `legacy/qt5` n'a pas bougé depuis le **24 novembre 2024**, et ses huit commits postérieurs à la v0.10 sont de la plomberie CI, une option pour masquer l'icône de zone de notification, et la prise en charge du Kensington PowerPointer. Rien ne touche au « hold move », au défilement ni au volume. Inutile donc d'engager les ~300 Mo de `--from-source` en espérant un correctif.

- **Le projet reste actif, mais ailleurs.** Dernier commit sur `develop` : **2 août 2026**. Tout l'effort porte sur la réécriture Plasma 6 / Qt 6 / Wayland, que le README amont oppose explicitement à `legacy/qt5`, maintenue pour les seuls « correctifs critiques ». Attendre une mise à jour de la ligne Qt5 a donc peu de chances d'aboutir ; le débouché réaliste est qu'Ubuntu livre Plasma 6.7+, rendant la branche `develop` compilable — son traitement des entrées étant de toute façon réécrit. Côté suivi amont, l'issue #85 (*Scroll on button hold*) est close et aucune issue ouverte ne signale cette panne : un rapport serait à créer, pas à suivre.

- **Le dépôt amont a changé de mainteneur en 2026** (Jahn Fuchs → Guillaume Binet) et `develop` est une réécriture. Si `legacy/qt5` disparaissait, se rabattre sur le tag `v0.10`, que le script accepte via `--branch v0.10`.
