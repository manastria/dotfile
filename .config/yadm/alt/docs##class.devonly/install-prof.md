# `install-prof.sh` — Compte « prof » de dépannage sur une VM étudiant

> Script : [`.local/bin/install-prof.sh`](../.local/bin/install-prof.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-prof.sh` crée sur la VM d'un étudiant un compte local **`prof`**, membre des groupes `adm` et `sudo`, avec un mot de passe connu, puis y déploie les dotfiles du dépôt avec yadm. Il s'installe en une commande depuis la session de l'étudiant — `curl -fsSL <url> | bash` — et détecte tout seul le proxy de l'établissement en testant le port 3128. Il ne configure **pas** le compte courant : contrairement aux autres installateurs du dépôt, il travaille dans un compte séparé, dédié au dépannage. Le home du compte prof est réaligné de force sur le dépôt à chaque exécution (`yadm checkout -f`) : c'est un environnement jetable et reproductible, pas un compte de travail où conserver des modifications. La seule option utile au quotidien est `--branch`, pour déployer une branche de test plutôt que `main`.

---

## Section utilisateur

### Description

Le script sert à **dépanner le poste d'un étudiant sans utiliser sa session** : plutôt que de travailler dans un environnement inconnu, on bascule sur un compte `prof` dont la configuration est celle du dépôt dotfiles.

Il se déroule en deux phases, dans deux contextes de privilèges différents :

| Phase | Exécutée sous | Opérations | Privilèges |
| ----- | ------------- | ---------- | ---------- |
| 1 | le compte de l'étudiant | création du compte prof, mot de passe, appartenance aux groupes `adm`/`sudo`, installation du paquet `yadm` | `sudo` de l'étudiant |
| 2 | le compte prof | `yadm clone` / `fetch`, `checkout -f -B`, submodules | `sudo` de prof (non utilisé par le script) |

Cette séparation est structurante : **toutes** les opérations qui exigent le `sudo` de l'étudiant sont regroupées en phase 1, avant que le compte prof n'existe et donc avant qu'il ne puisse rien installer lui-même.

À distinguer des autres installateurs du dépôt :

| Script | Cible |
| ------ | ----- |
| `install-prof.sh` | un **autre** compte (`prof`), créé pour l'occasion sur une machine tierce |
| `install-paquets.sh`, `install-*.sh` | la machine et le compte **courants** |

### Sécurité : un compte de dépannage à privilèges complets

Le compte prof est créé membre des groupes **`adm`** (lecture de `/var/log`) et **`sudo`** (élévation de privilèges) : c'est un compte de dépannage, il doit pouvoir diagnostiquer et corriger n'importe quel problème sur la machine.

Le mot de passe par défaut (`netlab123`) est **public** — il figure dans les supports de cours. C'est un choix assumé : la VM est un poste de travaux pratiques, isolé du reste, pas une machine exposée sur un réseau non maîtrisé. Ne pas réutiliser ce mot de passe hors de ce contexte.

La variable `PROF_PASSWORD` permet de choisir un autre mot de passe si le contexte de déploiement l'exige.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4.4 | Tableaux vides sous `set -u` (`"${PROXY_ENV[@]}"`) | `bash --version` |
| `sudo` | Phase 1 : création du compte, APT | `sudo -v` |
| `apt-get` | Installation du paquet `yadm` | `apt-get --version` |
| `curl` | Récupération du script (usage `curl \| bash`) | `curl --version` |
| `timeout` | Sonde TCP du proxy, bornée à 1 s | `timeout --version` |
| `git` | Tiré par `yadm` | `git --version` |

Le compte lançant le script doit pouvoir utiliser `sudo` (cas standard sur une VM étudiant). Le script fonctionne aussi lancé directement en root.

---

### Syntaxe

```
install-prof.sh [--branch BRANCHE] [-h]
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `--branch` | nom de branche | `main` | Branche des dotfiles à déployer |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage du script |

| Variable | Défaut | Rôle |
| -------- | ------ | ---- |
| `PROF_PASSWORD` | `netlab123` | Mot de passe du compte prof |
| `http_proxy` / `https_proxy` | détection auto | Proxy à utiliser ; s'ils sont définis, la détection est court-circuitée |

En usage `curl … | bash`, les options se passent après `-s --` :

```bash
curl -fsSL <url-du-script> | bash -s -- --branch dev1
```

---

### Exemples d'utilisation

```bash
# Usage courant, depuis la session de l'étudiant
curl -fsSL https://raw.githubusercontent.com/manastria/dotfile/refs/heads/main/.local/bin/install-prof.sh | bash

# Tester une branche de développement
curl -fsSL <url-du-script> | bash -s -- --branch dev1

# Mot de passe différent de celui des supports de cours
PROF_PASSWORD='...' bash install-prof.sh

# Forcer un proxy que la sonde TCP ne trouve pas
export http_proxy=http://172.16.0.1:3128
curl -fsSL <url-du-script> | bash
```

Sortie d'une première installation, hors établissement (pas de proxy) :

```text
=== Environnement prof — installation ===

[INFO]      Aucun proxy détecté : connexion directe.
[INFO]      Des droits administrateur sont nécessaires (compte prof, paquet yadm).
[sudo] Mot de passe de etudiant :
[INFO]      Création du compte prof...
[OK]        Compte prof créé.
[INFO]      Installation de yadm (paquet APT)...
[OK]        yadm installé.
[INFO]      Bascule vers le compte prof...
[INFO]      Clonage des dotfiles depuis https://github.com/manastria/dotfile.git...
[INFO]      Bascule du home sur main (modifications locales écrasées)...
[INFO]      Synchronisation des submodules zsh...
[OK]        Dotfiles déployés dans /home/prof.

[OK]        Environnement prof prêt.
[INFO]      Ouvrir une session prof : su - prof
```

Le script **ne bascule pas** dans une session prof : il rend la main sur la session de l'étudiant. Ouvrir la session prof est une étape manuelle (`su - prof`), volontairement laissée à l'utilisateur.

À la relance, la sortie diffère sur trois lignes : compte déjà présent, mot de passe réinitialisé, et `yadm fetch` au lieu de `yadm clone`.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Compte prof et dotfiles en place |
| 1 | Erreur d'exécution : sudo refusé, échec de `useradd`, d'APT ou de yadm |
| 2 | Erreur d'usage : option inconnue, ou `--branch` sans argument |

L'échec de la synchronisation des submodules est le seul cas **non bloquant** : il produit un avertissement et le script se termine en 0, le compte restant utilisable avec un zsh dégradé.

---

## Section développeur

### Architecture interne

```text
main()
├── parse_args()            # --branch, -h
├── detect_proxy()          # normalise HTTP_PROXY → http_proxy, sonde le port 3128,
│   └── proxy_is_reachable()#   remplit le tableau PROXY_ENV
│
├── [ id -un = prof ] ──────► setup_dotfiles()      # phase 2 seule
│
└── sinon
    ├── request_sudo()          # sudo -v + keep-alive en tâche de fond
    ├── ensure_prof_account()   # useradd / chpasswd / usermod -aG adm,sudo
    ├── install_yadm()          # apt-get update && install, proxy réinjecté
    └── run_dotfiles_as_prof()  # sérialise et exécute setup_dotfiles sous prof
        └── setup_dotfiles()    # clone/fetch + checkout forcé + submodules
```

`setup_dotfiles()` est appelée depuis deux contextes : directement si le script est lancé depuis une session prof, sinon transportée dans la session prof par `run_dotfiles_as_prof()`.

---

### Détail des choix techniques

**Les opérations privilégiées sont toutes en phase 1.** La version précédente installait `yadm` *après* la bascule vers prof, donc dans un compte sans `sudo`. Le symptôme était trompeur :

```text
sudo: I'm sorry prof. I'm afraid I can't do that
✓ yadm installé
bash: ligne 64: yadm: commande introuvable
```

Le message d'insulte vient de `sudo` (option `insults` activée sur l'image) : prof n'est pas dans `sudoers`. Le `✓ yadm installé` affiché juste après relevait d'un second défaut, décrit ci-dessous.

**`set -e` ne rattrape pas l'échec d'un `A && B`.** `errexit` ne s'applique qu'au dernier maillon d'une liste ET/OU : dans `apt-get update && apt-get install`, l'échec du premier maillon n'interrompt pas le script, qui poursuit comme si tout allait bien.

```bash
$ bash -c 'set -e; false && echo jamais; echo "on continue"'
on continue
```

Les commandes sont donc séparées, chacune suivie de `|| die`. C'est la raison pour laquelle un échec d'APT était signalé, puis suivi d'un « ✓ » mensonger.

**Le script n'est pas retéléchargé pour la phase 2.** La version précédente relançait `curl … | bash` depuis la session prof. `run_dotfiles_as_prof()` sérialise à la place les fonctions nécessaires avec `declare` et les injecte dans un `bash -s` :

```bash
sudo -u "$PROF_USER" -H env "${PROXY_ENV[@]}" bash -s <<PAYLOAD
set -euo pipefail
$(declare -p RED GREEN YELLOW CYAN BOLD RESET)
$(declare -p DOTFILES_REPO DOTFILES_BRANCH)
$(declare -f info success warn error die setup_dotfiles)
setup_dotfiles
PAYLOAD
```

Trois bénéfices : un seul aller-retour réseau (précieux derrière un proxy scolaire), les deux phases exécutent la **même** version du code, et les options de la ligne de commande (`--branch`) sont transmises sans avoir à être re-parsées. Le heredoc n'est délibérément **pas** quoté, pour que les `$(declare …)` soient évalués par le shell appelant ; le corps du payload ne contient donc aucun `$` littéral.

**`sudo -H` plutôt que `sudo -i` ou `su -`.** `-H` fixe `HOME=/home/prof` sans lancer de shell de login, donc sans sourcer les `.profile` / `.bashrc` que le script vient précisément de remplacer. `setup_dotfiles()` commence par `cd "$HOME"` : le répertoire courant hérité est celui de l'étudiant, souvent illisible pour prof.

**Sonde TCP plutôt que `ping`.** Un `ping` ne prouve que la présence de la machine : le port 3128 peut être fermé alors que l'ICMP répond, ou l'ICMP filtré alors que le proxy fonctionne. `timeout 1 bash -c "exec 3<>/dev/tcp/HOST/PORT"` teste le service lui-même, sans dépendre de `nc` (absent de certaines images).

**Le proxy est réinjecté explicitement dans `sudo`.** `sudo` réinitialise l'environnement, `http_proxy` compris — un `apt-get update` lancé via `sudo` perd donc le proxy. `sudo -E` est proscrit par les conventions du dépôt (il propage tout l'environnement, `LD_PRELOAD` compris) : les variables utiles sont passées une à une via `env`, d'où le tableau `PROXY_ENV`.

**`echo … | sudo chpasswd`, et non `sudo sh -c 'echo … | chpasswd'`.** `echo` est un builtin : le mot de passe ne devient jamais l'argument d'un processus, donc reste invisible dans `ps`. Le groupement dans un unique `sudo` — motivé à l'origine par le souhait de ne demander le mot de passe qu'une fois — n'est plus nécessaire, le jeton sudo étant préchauffé par `request_sudo()`.

**`yadm fetch` + `checkout -f -B`, et non `yadm pull`.** Le compte prof est un environnement jetable : on impose l'état distant au lieu de fusionner, ce qu'un `pull` ne peut pas faire en présence de modifications locales. Le forçage est également nécessaire après un **premier** clonage : `yadm clone` ne remplace pas les fichiers déjà présents dans le home (`.bashrc`, `.profile` créés par `useradd`), et sans `-f` le dépôt serait cloné sans que la configuration soit appliquée. Le `-B` (re)positionne au passage la branche locale, ce qui permet de passer de `main` à une branche de test d'une exécution à l'autre.

**Le clonage se fait sans `-b`.** yadm ne connaît pas cette option : la version 3.x la transmet à `git clone` parmi les arguments qu'elle ne reconnaît pas, mais la 2.5 livrée par Ubuntu 20.04 ne le fait pas. Comme `git clone` récupère de toute façon **toutes** les branches, la sélection est déléguée au `checkout -f -B` qui suit — ce qui rend le script indépendant de la version de yadm présente sur la VM.

Pour la même raison, `--recurse-submodules` n'est pas passé au clone : `clone()` l'ignore explicitement dans le code de yadm 3.2. Les submodules sont donc synchronisés par un appel séparé à `yadm submodule update --init --recursive`.

**`id -un` plutôt que `$USER`** pour détecter la session prof : `$USER` n'est pas définie dans un shell non interactif, et peut être héritée du compte appelant.

---

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 4.4 | `"${PROXY_ENV[@]}"` sur tableau vide sous `set -u` |
| `sudo` | — | Phase 1 ; `-u`, `-H`, `-n`, `-v` |
| `apt-get` | — | Installation de `yadm` (Debian ≥ 10, Ubuntu ≥ 20.04 fournissent le paquet) |
| `yadm` | 2.5 | `clone`, `fetch`, `checkout`, `submodule` (aucune option propre à la 3.x) |
| `coreutils` | — | `timeout`, `id`, `env` |

---

### Points d'extension

**Changer le compte cible** — une seule constante :

```bash
readonly PROF_USER="prof"
```

`PROF_USER` est utilisée pour `useradd`, `chpasswd`, la détection de session et `sudo -u`. Le message final (`su - prof`) suit automatiquement.

**Changer la branche déployée par défaut** — `DEFAULT_DOTFILES_BRANCH`, en tête de fichier avec les autres constantes. `--branch` reste prioritaire à l'exécution ; ne modifier cette constante que pour un déploiement durable sur une autre branche (par exemple lors des tests sur `dev1`, avant fusion vers `main`).

**Ajouter une étape à la phase 2** — écrire la fonction, puis l'ajouter à la liste sérialisée, sinon elle sera introuvable dans la session prof :

```bash
$(declare -f info success warn error die setup_dotfiles ma_nouvelle_fonction)
```

**Installer d'autres paquets sur la VM** — les ajouter à `install_yadm()` (phase 1, seul endroit disposant de `sudo`), ou créer une fonction voisine appelée depuis la même branche de `main()`.

---

### Notes de maintenance

- **Le mot de passe par défaut est public**, et le compte a délibérément accès à `sudo` : ce script ne doit être diffusé que pour des VM de travaux pratiques isolées, jamais pour une machine exposée à un réseau non maîtrisé.
- **Le `checkout -f` est destructeur** pour le home de prof. C'est le comportement voulu, mais il interdit d'utiliser prof comme compte de travail : les fichiers suivis par le dépôt y sont écrasés à chaque exécution.
- **Le payload sérialisé est le point fragile.** Une fonction de phase 2 oubliée dans la liste `declare -f` ne se voit qu'à l'exécution, sous forme de `command not found` dans la session prof. Le payload se teste sans droits particuliers en remplaçant `sudo -u prof -H env … bash -s` par `cat`.
- **La branche par défaut est `main`**, alors que le script lui-même est souvent servi depuis `dev1` pendant les phases de test. Vérifier la cohérence de l'URL et de `--branch` avant de diffuser une commande aux étudiants.
- **`raw.githubusercontent.com` est mis en cache 5 minutes** (`max-age=300`, CDN Fastly) : après un push, la commande `curl … | bash` peut encore servir la version précédente. Un paramètre `?v=…` ne contourne rien, la clé de cache ignore la *query string*.
