# `install-xmind.sh` — Installation de Xmind sur KUbuntu / XUbuntu

Installateur du logiciel de cartes heuristiques **Xmind**, à partir du paquet `.deb` officiel, avec les réglages spécifiques aux bureaux KDE et XFCE.

---

## Section utilisateur

### Description

Xmind n'est présent ni dans les dépôts Ubuntu, ni dans un dépôt APT tiers : l'éditeur ne publie qu'un fichier `.deb` autonome de ~230 Mo, derrière une redirection sur son site. Il n'y a donc **aucune mise à jour automatique** — relancer le script est la façon de mettre à jour.

Le script fait trois choses qu'un simple `apt install ./Xmind….deb` ne fait pas :

| Problème | Ce que fait le script |
| -------- | --------------------- |
| Téléchargement inutile de 230 Mo quand la version installée est déjà la bonne | Compare l'horodatage de build **avant** de télécharger, et sort si c'est identique |
| Xmind (Electron) refuse de démarrer sur Ubuntu ≥ 24.04 | Installe un profil AppArmor qui autorise les espaces de noms utilisateur pour ce seul binaire |
| Xmind oublie la connexion au compte à chaque lancement sur KDE/XFCE | Vérifie la présence d'un trousseau *Secret Service* et indique le paquet manquant selon le bureau |

Il se distingue des autres installateurs du dépôt sur un point : il n'existe **pas de variante arm64** chez l'éditeur, le script refuse donc toute architecture autre qu'`amd64`.

Le script relève du **Tier 2** de la politique sudo du dépôt (voir [CLAUDE.md](../CLAUDE.md)) : il se lance en utilisateur normal et refuse d'être lancé en root. C'est délibéré — la détection du trousseau de clés interroge le bus D-Bus **de session**, qui n'existe pas sous root.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `curl` | Résolution de la redirection et téléchargement | `curl --version` |
| `dpkg` / `dpkg-deb` | Architecture, version installée, vérification de l'archive | `dpkg --version` |
| `apt-get` | Installation du `.deb` et de ses dépendances | `apt-get --version` |
| `sudo` | Installation système et écriture du profil AppArmor | `sudo -V` |
| `apparmor_parser` | Chargement du profil AppArmor (facultatif) | `apparmor_parser --version` |
| `gdbus` | Détection du trousseau de clés (facultatif, paquet `libglib2.0-bin`) | `gdbus --version` |

Les deux derniers outils sont facultatifs : leur absence produit un avertissement, pas un échec.

### Syntaxe

```bash
install-xmind.sh [-f] [--file FICHIER.deb] [--keep-deb DIR] [--no-apparmor] [-h]
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-f`, `--force` | — | désactivé | Réinstalle même si la build en ligne est déjà installée, et ne pose aucune question |
| `--file` | chemin | téléchargement | Installe ce `.deb` local au lieu de télécharger (hors ligne, ou rejeu d'une version) |
| `--keep-deb` | répertoire | fichier supprimé | Copie le `.deb` téléchargé dans ce répertoire avant nettoyage |
| `--no-apparmor` | — | profil installé | N'installe pas le profil AppArmor |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage du script |

### Exemples d'utilisation

```bash
# Installation, ou mise à jour si une nouvelle build est publiée
install-xmind.sh

# Mise à jour forcée, en conservant le .deb pour l'installer sur un autre poste
install-xmind.sh --force --keep-deb ~/Téléchargements

# Installation sur un poste hors ligne, depuis le .deb récupéré plus tôt
install-xmind.sh --file ~/Téléchargements/Xmind-for-Linux-amd64bit-26.05.01106-202608091931.deb

# Installation sans toucher à AppArmor (poste où le profil est géré autrement)
install-xmind.sh --no-apparmor
```

Sortie sur une première installation sous KUbuntu :

```text
=== Installation de Xmind ===

[INFO]      Bureau détecté : KDE (traité comme « kde »)
[INFO]      Résolution de la version publiée…
[INFO]      Build publiée : 202608091931
[INFO]      Des droits administrateur sont nécessaires pour installer le paquet.
[sudo] Mot de passe de jpdemory :
[INFO]      Téléchargement de Xmind-for-Linux-amd64bit-26.05.01106-202608091931.deb (environ 230 Mo)…
######################################################################## 100,0%
[INFO]      Paquet vérifié : xmind-vana 26.5.1106-202608091931
[INFO]      Installation du paquet (apt résout les dépendances)…
[OK]        Paquet xmind-vana installé.
[INFO]      Installation du profil AppArmor pour /opt/Xmind/Xmind…
[OK]        Profil AppArmor chargé : /etc/apparmor.d/xmind
[OK]        Trousseau de clés disponible (org.freedesktop.secrets).
[OK]        Xmind 26.5.1106-202608091931 installé.
[INFO]      Binaire : /opt/Xmind/Xmind
[INFO]      Lancement : depuis le menu des applications, ou « xmind » si le lien est dans le PATH.
[INFO]      Mise à jour : relancez ce script (Xmind n'a pas de dépôt APT).
```

Sur un second lancement sans nouvelle version :

```text
[INFO]      Version déjà installée : 26.5.1106-202608091931
[INFO]      Résolution de la version publiée…
[INFO]      Build publiée : 202608091931
[OK]        Xmind 26.5.1106-202608091931 est déjà à jour. Rien à faire.
[INFO]      Utilisez --force pour réinstaller malgré tout.
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Xmind installé, déjà à jour, ou installation annulée par l'utilisateur |
| `1` | Erreur d'exécution : lancement en root, architecture non `amd64`, dépendance absente, URL résolue qui n'est pas un `.deb`, archive corrompue ou paquet inattendu, échec du téléchargement ou de l'installation |
| `2` | Erreur d'usage : option inconnue, option à valeur sans argument, fichier ou répertoire introuvable |

### Après l'installation

- **Mises à jour** : manuelles. Relancer `install-xmind.sh` ; sans nouvelle build, le script sort en quelques secondes sans rien télécharger.
- **Désinstallation** : `sudo apt remove xmind-vana` puis `sudo rm -f /etc/apparmor.d/xmind` (le profil n'est pas retiré automatiquement).
- **Trousseau de clés** : si le script a averti de son absence, installer `kwalletmanager kwallet-pam` (KDE) ou `gnome-keyring seahorse` (XFCE), puis **rouvrir la session** — le service ne s'enregistre sur le bus qu'au démarrage de celle-ci.

---

## Section développeur

### Architecture interne

Enchaînement de `main()` :

1. `parse_args` — analyse des options, normalisation de `--file` en chemin absolu, validation des chemins.
2. `check_not_root` — refuse root (Tier 2, cf. *Détail des choix techniques*).
3. `check_arch` — `dpkg --print-architecture` doit valoir `amd64`.
4. `check_deps` — `curl`, `dpkg`, `dpkg-deb`, `apt-get`, `sudo`.
5. `detect_desktop` — classe `$XDG_CURRENT_DESKTOP` en `kde` / `xfce` / `autre`, pour personnaliser les conseils de fin.
6. `installed_version` — version dpkg de `xmind-vana`, chaîne vide si absent.
7. Branche `--file` : `sudo_warmup` puis `verify_deb` sur le fichier fourni.
   Branche par défaut : `resolve_remote_url` → `build_id_of_string` sur les deux versions → sortie anticipée si identiques → confirmation → `sudo_warmup` → `download_deb` → `verify_deb` → `keep_deb`.
8. `install_deb` — `apt-get install -y` sur le chemin du `.deb`.
9. `configure_apparmor` — conditionnée au sysctl et à la présence d'`apparmor_parser`.
10. `check_secret_service` — sondage D-Bus, avertissement ciblé par bureau.
11. `refresh_desktop_db` — `update-desktop-database` et `gtk-update-icon-cache`.
12. `verify_install` — relit la version dpkg et affiche le chemin du binaire.

### Détail des choix techniques

**Comparaison par horodatage de build.** Le nom du fichier publié et la version dpkg ne se déduisent pas l'un de l'autre : `Xmind-for-Linux-amd64bit-26.05.01106-202608091931.deb` s'installe en version `26.5.1106-202608091931`, les zéros de tête ayant disparu. Écrire la conversion serait fragile. En revanche l'horodatage final à 12 chiffres est identique dans les deux, et `build_id_of_string` l'extrait de l'un comme de l'autre. C'est ce qui permet de décider **avant** de télécharger 230 Mo.

**Garde-fou sur l'URL résolue.** `https://www.xmind.app/zen/download/linux_deb/` renvoie une 302 vers le `.deb` courant. Mais le site répond **200 à n'importe quel chemin** sous `/zen/download/` et sert alors un vieil exécutable Windows (`XMind-for-Windows-32bit-11.1.2-….exe`). Un changement de nomenclature côté éditeur ferait donc installer silencieusement un fichier arbitraire. `resolve_remote_url` exige que l'URL finale se termine par `.deb`, et `verify_deb` confirme ensuite que l'archive contient bien le paquet `xmind-vana`. L'éditeur ne publiant aucune somme de contrôle, c'est la seule vérification d'intégrité possible.

**Tier 2 plutôt que Tier 1.** L'essentiel du travail est système, ce qui plaiderait pour l'auto-relance en root. Mais `check_secret_service` interroge `DBUS_SESSION_BUS_ADDRESS`, propre à la session graphique de l'utilisateur : sous root, la réponse serait systématiquement « pas de trousseau », c'est-à-dire un faux avertissement. Le script tourne donc en utilisateur, avec préchauffage `sudo -v` et un rafraîchisseur en tâche de fond — le téléchargement de 230 Mo dépasse facilement les 5 minutes sur une liaison lente et ferait expirer le jeton en plein milieu.

**Deux listes D-Bus interrogées.** `check_secret_service` teste `ListNames` **puis** `ListActivatableNames`. Une seule ne suffit pas : gnome-keyring déclare un service activable à la demande (visible uniquement dans `ListActivatableNames`), tandis que KWallet occupe le nom `org.freedesktop.secrets` au vol via `org.kde.secretservicecompat`, sans fichier de service — il n'apparaît donc que dans `ListNames`. Ne tester que la liste des activables produisait un faux négatif sur KUbuntu.

**Profil AppArmor plutôt que `--no-sandbox`.** Depuis Ubuntu 24.04, `kernel.apparmor_restrict_unprivileged_userns=1` empêche Chromium — donc toute application Electron installée hors dépôts — de créer les espaces de noms de son bac à sable. Trois réponses possibles : passer le sysctl à 0 (affaiblit tout le système), lancer avec `--no-sandbox` (désactive le bac à sable de Xmind), ou déclarer un profil `flags=(unconfined)` n'accordant que `userns`. C'est cette troisième voie, celle qu'Ubuntu emploie elle-même pour les navigateurs empaquetés — le profil produit est calqué sur `/etc/apparmor.d/obsidian` fourni par la distribution. Le profil n'est écrit que si le sysctl vaut effectivement `1`.

**Chemin du binaire découvert, pas codé en dur.** `xmind_binary` lit `dpkg -L xmind-vana` : l'éditeur a déjà changé la casse du répertoire d'installation (`/opt/XMind` puis `/opt/Xmind`) d'une version à l'autre, et le profil AppArmor doit désigner le chemin exact.

**Permissions du répertoire temporaire.** `mktemp -d` crée en `0700`. `apt-get install` abandonne ses privilèges vers l'utilisateur `_apt` pour lire le fichier et émettrait alors l'avertissement *« Download is performed unsandboxed as root »*. `download_deb` passe donc le répertoire en `755` et le `.deb` en `644`.

**`apt-get` plutôt que `dpkg -i`.** Le paquet dépend de `libgtk-3-0`, `libnotify4`, `libnss3`, `libxss1`, `libxtst6`, `xdg-utils`, `libatspi2.0-0`, `libuuid1` et `libsecret-1-0`. `dpkg -i` laisserait le paquet mal configuré si l'une manque ; `apt-get install` les installe dans la foulée.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `curl` | ≥ 7.21 | `-w '%{url_effective}'` avec `-I -L` pour résoudre la redirection sans télécharger |
| `dpkg-deb` | toute version Debian | `-f FICHIER Package` pour vérifier l'archive sans l'extraire |
| `apt-get` | ≥ 1.1 | Installation directe d'un `.deb` par chemin de fichier |
| `apparmor_parser` | ≥ 4.0 (Ubuntu 24.04) | Règle `userns,` et `abi <abi/4.0>` du profil |
| `gdbus` | glib ≥ 2.30 | `ListNames` / `ListActivatableNames` sur le bus de session |
| `bash` | ≥ 4 | `[[ =~ ]]` avec `BASH_REMATCH`, expansion `${raw^^}` |

### Points d'extension

**Publication d'une build arm64 par l'éditeur.** À ce jour, aucun chemin `linux_deb_arm64` ou équivalent n'existe : toute variante testée retombe sur l'exécutable Windows. Le jour où l'éditeur en publie une, il suffit de rendre l'URL et l'architecture solidaires :

```bash
local arch url_path
arch="$(dpkg --print-architecture)"
case "$arch" in
    amd64) url_path="linux_deb" ;;
    arm64) url_path="linux_deb_arm64" ;;   # à confirmer chez l'éditeur
    *)     die "Architecture $arch non supportée." ;;
esac
readonly DOWNLOAD_URL="https://www.xmind.app/zen/download/${url_path}/"
```

**Installation automatique du trousseau manquant.** `check_secret_service` se contente d'avertir. Pour l'installer, remplacer le `case` final par :

```bash
case "$DESKTOP" in
    kde)  sudo apt-get install -y kwalletmanager kwallet-pam ;;
    xfce) sudo apt-get install -y gnome-keyring seahorse ;;
esac
warn "Rouvrez votre session pour que le trousseau s'enregistre sur le bus."
```

Ce n'est volontairement pas le comportement par défaut : le script installerait des paquets que l'utilisateur n'a pas demandés, et le service ne serait utilisable qu'après réouverture de session.

**Suppression du profil AppArmor à la désinstallation.** Le script ne gère que l'installation. Un `--uninstall` cohérent ferait `sudo apt-get remove -y xmind-vana`, `sudo rm -f /etc/apparmor.d/xmind` puis `sudo apparmor_parser -R /etc/apparmor.d/xmind` **avant** la suppression du fichier.

### Notes de maintenance

- **Le chemin `/opt/Xmind/Xmind` n'est pas vérifié à l'écriture de cette page.** `xmind_binary` le découvre par `dpkg -L` et le motif `^/opt/[^/]+/[A-Za-z]*[Xx]mind$`. Si l'éditeur déplace le binaire hors de `/opt` ou le renomme, le motif ne matche plus : le script avertit et poursuit sans installer le profil AppArmor — Xmind refusera alors de démarrer sur Ubuntu ≥ 24.04, avec une erreur Chromium sur les espaces de noms. C'est le premier endroit à regarder en cas de régression.
- **Le nom de paquet `xmind-vana` est codé en dur** dans `PACKAGE`. Un renommage côté éditeur ferait échouer `verify_deb` avec un message explicite (« Paquet inattendu dans l'archive »), pas silencieusement.
- **`libappindicator3-1` est en `Recommends`** et vit dans le composant `universe`. Sur un système où `universe` est désactivé, apt ignore la recommandation en émettant un avertissement ; l'installation aboutit et l'icône de zone de notification peut manquer.
- **Aucune signature ni somme de contrôle** n'est publiée par l'éditeur. La confiance repose entièrement sur TLS et sur la vérification du nom de paquet.
- **`--force` n'est pas un `--reinstall`** : le script réinstalle le `.deb` par-dessus, ce qui suffit pour Xmind mais ne recrée pas les fichiers de configuration supprimés à la main.
