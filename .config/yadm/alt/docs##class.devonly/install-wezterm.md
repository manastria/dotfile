# install-wezterm.sh

> Script : [`.local/bin/install-wezterm.sh`](../.local/bin/install-wezterm.sh)
> Configuration associée : [`.wezterm.lua`](../.wezterm.lua), [`99-wezterm.sh`](../.shellrc/rc.d/99-wezterm.sh), [`99-wezterm.zsh`](../.shellrc/zshrc.d/99-wezterm.zsh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-wezterm.sh` installe l'émulateur de terminal WezTerm sur Debian/Ubuntu : il déclare le dépôt APT officiel (`apt.fury.io/wez`), installe le paquet `wezterm`, puis compile l'entrée terminfo `wezterm` dans `~/.terminfo/`. Il ne déploie **pas** la configuration : `~/.wezterm.lua` vient du dépôt dotfiles via yadm. Il ne prépare pas non plus les machines distantes, ce que fait `wezterm-terminfo-deploy.sh`. Il se relance seul avec `sudo` et peut être rejoué sans risque ; seule option, `-h`. Après l'installation, ouvrir un nouveau WezTerm pour que le terminfo et la config soient pris en compte.

---

## Section utilisateur

### Description

Installe WezTerm depuis le dépôt APT du projet (hébergé sur fury.io) plutôt que depuis un `.deb` téléchargé à la main : les mises à jour passent ensuite par `apt upgrade`. Le script enchaîne trois étapes :

1. clé GPG et fichier de dépôt (`/etc/apt/sources.list.d/wezterm.list`) ;
2. `apt-get install wezterm` ;
3. compilation du **terminfo** `wezterm` dans le `~/.terminfo/` de l'utilisateur réel (pas celui de root).

Le terminfo permet à `TERM=wezterm` d'être reconnu par les programmes en terminal (tmux, vim…) : couleurs 24 bits, soulignements stylés, etc. Sans lui, `.wezterm.lua` retombe sur `xterm-256color` (voir *Notes de maintenance*).

Le script ne s'occupe ni de la configuration, ni des machines distantes. Pour ces dernières, c'est `wezterm-terminfo-deploy.sh user@machine` qui pousse le terminfo en SSH.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `sudo` | élévation de privilèges (relance automatique) | `sudo -v` |
| `curl` | clé GPG et fichier terminfo | `curl --version` |
| `gpg` | conversion de la clé au format keyring | `gpg --version` |
| `tic` (paquet `ncurses-bin`) | compilation du terminfo | `command -v tic` |
| accès réseau | `apt.fury.io`, `raw.githubusercontent.com` | `curl -fsI https://apt.fury.io/wez/gpg.key` |

### Syntaxe

```bash
install-wezterm.sh [-h|--help]
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-h`, `--help` | — | — | Affiche l'en-tête du script et quitte, sans demander `sudo` |

Aucune variable d'environnement n'est lue.

### Exemples d'utilisation

```bash
# Installation (le script demande sudo lui-même)
install-wezterm.sh

# Vérifications ensuite
wezterm --version
infocmp wezterm | head -3     # terminfo bien installé ?
```

Exemple de sortie (la version affichée dépend du dépôt) :

```
=== Installation de WezTerm ===

[INFO]      Ajout de la clé GPG WezTerm…
[INFO]      Ajout du dépôt APT WezTerm…
[INFO]      Mise à jour des dépôts…
[INFO]      Installation de WezTerm…
[OK]        WezTerm installé : wezterm 20240203-110809-5046fc22
[INFO]      Installation du terminfo wezterm pour jpdemory…
[OK]        Terminfo installé dans /home/jpdemory/.terminfo/

[INFO]      Configuration : ~/.wezterm.lua (fournie par le dépôt dotfiles).
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | WezTerm installé et terminfo en place (ou `--help`) |
| 1 | Erreur : téléchargement, `apt`, `tic`, ou option inconnue |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — `-h`/`--help`, option inconnue → `die`. Exécuté **avant** l'élévation de privilèges, pour que l'aide ne demande pas de mot de passe.
2. `ensure_root` — relance `sudo "$(readlink -f "$0")" "$@"` si UID ≠ 0.
3. `add_repository` — clé GPG (`gpg --dearmor`) et `wezterm.list`.
4. `install_package` — `apt-get update` puis `apt-get install -y wezterm`.
5. `install_terminfo` — télécharge `wezterm.terminfo`, le compile avec `tic -x -o ~/.terminfo`.

### Détail des choix techniques

**Pas de `wezterm tcl`.** La première version faisait `wezterm tcl | tic -x -` et échouait avec `error: unrecognized subcommand 'tcl'` : cette sous-commande n'existe pas. WezTerm ne sait pas exporter son terminfo ; la méthode documentée par le projet est de récupérer `termwiz/data/wezterm.terminfo` dans le dépôt Git et de le compiler avec `tic`. Le fichier est lu sur la branche `main` : il suit donc le dépôt, pas la version installée (voir *Notes de maintenance*).

**Home de l'utilisateur résolu avec `getent`.** Le script tourne en root (Tier 1). `sudo -u user tic` peut conserver `HOME=/root` selon la configuration de sudo, et le terminfo atterrirait alors dans `/root/.terminfo` — invisible pour l'utilisateur. D'où `-o "${real_home}/.terminfo"` explicite, avec `real_home` lu dans `passwd`.

**`tic` lancé en tant qu'utilisateur réel.** Pour que `~/.terminfo/` et son contenu appartiennent à l'utilisateur et non à root.

**Sélecteur de dépôt `* *`.** Le dépôt fury.io publie un seul jeu de paquets valable pour toutes les versions de Debian/Ubuntu ; la ligne `deb … https://apt.fury.io/wez/ * *` évite de dépendre du nom de code de la distribution (utile sur une version récente comme XUbuntu 25.10, absente des listes officielles).

**Fichier de dépôt écrit par redirection (`>`).** Il remplace le fichier à chaque exécution, ce qui rend le script idempotent (l'ancienne version utilisait `tee`, équivalent mais bruyant). `gpg --yes` joue le même rôle pour la clé.

**Tier 1 sans `-E`.** Conforme à la convention du dépôt : `exec sudo "$(readlink -f "$0")"`, car `~/.local/bin` n'est pas dans le `secure_path` de sudo.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 4 | `[[ ]]`, `set -o pipefail` |
| `gpg` | 2.x | `--dearmor` |
| `tic` | ncurses 6.x | `-x` (capacités étendues, nécessaires au terminfo wezterm) et `-o` |
| `getent`, `mktemp`, `curl` | — | résolution du home, fichier temporaire, téléchargements |

### Points d'extension

**Installer une version précise** — `apt-cache policy wezterm` liste les versions disponibles dans le dépôt, puis :

```bash
apt-get install -y wezterm=20240203-110809-5046fc22
```

**Figer le terminfo sur une version** — remplacer `main` par un tag dans `TERMINFO_URL` :

```bash
readonly TERMINFO_URL="https://raw.githubusercontent.com/wezterm/wezterm/20240203-110809-5046fc22/termwiz/data/wezterm.terminfo"
```

### Notes de maintenance

- **`.wezterm.lua` teste `infocmp wezterm`** (section 5) pour choisir `TERM`. Si le terminfo n'est pas installé, WezTerm démarre quand même, en `xterm-256color` : l'absence de l'étape 5 est donc silencieuse. En cas de doute, `echo $TERM` dans WezTerm doit répondre `wezterm`.
- **Même logique côté shell** : `99-wezterm.sh` / `99-wezterm.zsh` repassent `TERM` à `xterm-256color` sur une machine distante sans terminfo ; `.tmux.conf` n'active `Tc` pour `wezterm` que si `infocmp wezterm` réussit.
- **Terminfo lu sur `main`** : si le projet change le format du fichier, `tic` peut refuser une capacité inconnue d'un `ncurses` ancien. Épingler un tag (voir *Points d'extension*).
- **Le script ne désinstalle rien.** Pour retirer WezTerm : `sudo apt remove wezterm`, puis supprimer `/etc/apt/sources.list.d/wezterm.list`, `/usr/share/keyrings/wezterm-fury.gpg` et `~/.terminfo/w/wezterm`.
- **`wezterm-terminfo-deploy.sh`** (poussée du terminfo vers une machine distante) utilise la même source ; si l'URL change ici, la changer là aussi.
