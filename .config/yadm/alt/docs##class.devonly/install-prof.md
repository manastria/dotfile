# `install-prof.sh` — Compte « prof » de dépannage sur une VM étudiant

> Script : [`.local/bin/install-prof.sh`](../.local/bin/install-prof.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-prof.sh` crée sur la VM d'un étudiant un compte local **`prof`**, membre des groupes `adm` et `sudo`, avec un mot de passe connu et une clé publique SSH déjà autorisée, puis y déploie les dotfiles du dépôt avec yadm. Il s'installe en une commande depuis la session de l'étudiant — `curl -fsSL <url> | bash` — et détecte tout seul le proxy de l'établissement en testant le port 3128. Il ne configure **pas** le compte courant : contrairement aux autres installateurs du dépôt, il travaille dans un compte séparé, dédié au dépannage. Le home du compte prof est réaligné de force sur le dépôt à chaque exécution (`yadm checkout -f`) : c'est un environnement jetable et reproductible, pas un compte de travail où conserver des modifications. La seule option utile au quotidien est `--branch`, pour déployer une branche de test plutôt que `main` : script et dotfiles étant dans le même dépôt, le script se retélécharge et se relance tout seul si nécessaire pour que les deux proviennent bien de la branche demandée.

---

## Section utilisateur

### Description

Le script sert à **dépanner le poste d'un étudiant sans utiliser sa session** : plutôt que de travailler dans un environnement inconnu, on bascule sur un compte `prof` dont la configuration est celle du dépôt dotfiles.

Il se déroule en deux phases, dans deux contextes de privilèges différents :

| Phase | Exécutée sous | Opérations | Privilèges |
| ----- | ------------- | ---------- | ---------- |
| 1 | le compte de l'étudiant | création du compte prof, mot de passe, appartenance aux groupes `adm`/`sudo`, clé SSH autorisée, installation du paquet `yadm` | `sudo` de l'étudiant |
| 2 | le compte prof | `yadm clone` / `fetch`, `checkout -f -B`, submodules | `sudo` de prof (non utilisé par le script) |

Cette séparation est structurante : **toutes** les opérations qui exigent le `sudo` de l'étudiant sont regroupées en phase 1, avant que le compte prof n'existe et donc avant qu'il ne puisse rien installer lui-même.

**`--branch` et la version du script.** Script et dotfiles vivent dans le même dépôt. Sans précaution, `--branch dev1` ne change que la branche des dotfiles déployés : la *logique* exécutée reste celle de l'URL passée à `curl`, indépendamment de `--branch`. C'est le piège classique du `curl | bash` — rien ne relie l'un à l'autre par défaut. Le script s'en prémunit : s'il détecte qu'il tourne via `curl | bash` (et non depuis un fichier local) et que `--branch` diffère de `main`, il se retélécharge depuis la bonne branche et se relance une fois avant de continuer, avec les mêmes arguments. Code et dotfiles proviennent donc toujours de la même branche, sans discipline particulière à respecter au moment de construire la commande.

À distinguer des autres installateurs du dépôt :

| Script | Cible |
| ------ | ----- |
| `install-prof.sh` | un **autre** compte (`prof`), créé pour l'occasion sur une machine tierce |
| `install-paquets.sh`, `install-*.sh` | la machine et le compte **courants** |

### Sécurité : un compte de dépannage à privilèges complets

Le compte prof est créé membre des groupes **`adm`** (lecture de `/var/log`) et **`sudo`** (élévation de privilèges) : c'est un compte de dépannage, il doit pouvoir diagnostiquer et corriger n'importe quel problème sur la machine.

Le mot de passe par défaut (`netlab123`) est **public** — il figure dans les supports de cours. C'est un choix assumé : la VM est un poste de travaux pratiques, isolé du reste, pas une machine exposée sur un réseau non maîtrisé. Ne pas réutiliser ce mot de passe hors de ce contexte.

La variable `PROF_PASSWORD` permet de choisir un autre mot de passe si le contexte de déploiement l'exige.

Le script autorise en outre une clé publique SSH fixe (`PROF_SSH_PUBKEY`, embarquée par défaut) dans `~prof/.ssh/authorized_keys`, pour permettre une connexion à distance sans ressaisir le mot de passe. Poser `PROF_SSH_PUBKEY=""` désactive cette étape sans toucher à un fichier existant.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4.4 | Tableaux vides sous `set -u` (`"${PROXY_ENV[@]}"`) | `bash --version` |
| `sudo` | Phase 1 : création du compte, APT | `sudo -v` |
| `apt-get` | Installation du paquet `yadm` | `apt-get --version` |
| `curl` | Récupération du script (usage `curl \| bash`), et re-récupération si `--branch` diffère de `main` | `curl --version` |
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
| `--branch` | nom de branche | `main` | Branche à déployer — dotfiles **et** script lui-même (relance automatique si besoin, en usage `curl \| bash`) |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage du script |

| Variable | Défaut | Rôle |
| -------- | ------ | ---- |
| `PROF_PASSWORD` | `netlab123` | Mot de passe du compte prof |
| `PROF_SSH_PUBKEY` | clé ed25519 embarquée | Clé publique autorisée en SSH ; vide pour ne pas y toucher |
| `http_proxy` / `https_proxy` | détection auto | Proxy à utiliser ; s'ils sont définis, la détection est court-circuitée |

En usage `curl … | bash`, les options se passent après `-s --` :

```bash
curl -fsSL <url-du-script> | bash -s -- --branch dev1
```

---

### Exemples d'utilisation

```bash
# Usage courant, depuis la session de l'étudiant
URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/${BRANCH:-main}/.local/bin/install-prof.sh
curl -fsSL "$URL" | bash -s

# Tester une branche de développement : un seul BRANCH à changer, script
# ET dotfiles suivent (le script se relance seul si l'URL ne suivait pas)
BRANCH=dev1
URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/${BRANCH:-main}/.local/bin/install-prof.sh
curl -fsSL "$URL" | bash -s -- --branch "$BRANCH"

# Mot de passe différent de celui des supports de cours
PROF_PASSWORD='...' bash install-prof.sh

# Forcer un proxy que la sonde TCP ne trouve pas
export http_proxy=http://172.16.0.1:3128
URL=https://raw.githubusercontent.com/manastria/dotfile/refs/heads/${BRANCH:-main}/.local/bin/install-prof.sh
curl -fsSL "$URL" | bash -s
```

**`BRANCH` doit toujours être définie avant la ligne `URL=...` qui s'en sert.** Le shell substitue `${BRANCH:-main}` au moment de *cette* affectation, pas plus tard quand `$URL` est utilisée — ce n'est pas une référence différée. Concrètement : redéfinir `BRANCH` après avoir construit `URL` ne change plus rien à l'URL déjà figée, et il n'est donc pas possible de factoriser une seule définition de `URL` pour plusieurs valeurs de `BRANCH` — chaque exemple ci-dessus redéfinit sa propre `URL`, dans cet ordre.

Chaque exemple utilise en outre `${BRANCH:-main}` (valeur par défaut si `BRANCH` n'est pas définie) plutôt qu'un `BRANCH=main` explicite dans le premier cas : la variable n'a besoin d'exister que lorsqu'elle diffère de `main`, l'usage courant s'en passe.

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

Avec une URL sur `main` et `--branch dev1`, une ligne supplémentaire apparaît tout au début, avant même la bannière : le script se retélécharge et se relance depuis `dev1`.

```text
[INFO]      Version de la branche dev1 demandée : relance depuis https://raw.githubusercontent.com/manastria/dotfile/refs/heads/dev1/.local/bin/install-prof.sh...

=== Environnement prof — installation ===
…
```

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Compte prof et dotfiles en place |
| 1 | Erreur d'exécution : sudo refusé, échec de `useradd`, d'APT, de yadm, ou de la relance depuis une autre branche (`curl` en échec, branche inexistante) |
| 2 | Erreur d'usage : option inconnue, ou `--branch` sans argument |

L'échec de la synchronisation des submodules est le seul cas **non bloquant** : il produit un avertissement et le script se termine en 0, le compte restant utilisable avec un zsh dégradé.

---

## Section développeur

### Architecture interne

```text
main()
├── parse_args()                     # --branch, -h
├── relaunch_from_branch_if_needed() # curl | bash + branche ≠ main → re-fetch + exec, sinon no-op
│
├── detect_proxy()          # normalise HTTP_PROXY → http_proxy, sonde le port 3128,
│   └── proxy_is_reachable()#   remplit le tableau PROXY_ENV
│
├── [ id -un = prof ] ──────► setup_dotfiles()      # phase 2 seule
│
└── sinon
    ├── request_sudo()          # sudo -v + keep-alive en tâche de fond
    ├── ensure_prof_account()   # useradd / chpasswd / usermod -aG adm,sudo
    ├── ensure_prof_ssh_key()   # ~prof/.ssh/authorized_keys (idempotent)
    ├── install_yadm()          # apt-get update && install, proxy réinjecté
    └── run_dotfiles_as_prof()  # sérialise et exécute setup_dotfiles sous prof
        └── setup_dotfiles()    # clone/fetch + checkout forcé + submodules
```

`relaunch_from_branch_if_needed()` s'exécute avant tout le reste, y compris la bannière : si elle relance le script, l'exécution actuelle s'arrête net (`exec`) et tout ce qui suit dans `main()` n'a jamais lieu pour cette instance-là — c'est la version relancée qui affiche la bannière et poursuit.

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

**L'auto-relance sur `--branch`.** Le problème de départ : `curl -fsSL "$URL" | bash -s -- --branch dev1` exécute le contenu déjà téléchargé par `curl` — celui de l'URL, pas celui de `--branch`. `--branch` n'était consulté qu'une fois le script en train de tourner, bien après que son propre code source avait été figé par le tube. Résultat, silencieux et trompeur : les *dotfiles* basculaient sur `dev1`, mais la *logique* qui les déployait restait celle de `main`. `relaunch_from_branch_if_needed()` referme cette faille en quatre temps :

```bash
relaunch_from_branch_if_needed() {
    [ -f "$0" ] && return 0
    [ -n "${_INSTALL_PROF_RELAUNCHED:-}" ] && return 0
    [ "$DOTFILES_BRANCH" = "$DEFAULT_DOTFILES_BRANCH" ] && return 0
    …
    script_content="$(curl -fsSL "$url")" || die "..."
    exec env _INSTALL_PROF_RELAUNCHED=1 bash -c "$script_content" bash "$@"
}
```

- **`[ -f "$0" ]` distingue `curl | bash` d'une exécution locale.** En `curl | bash`, bash lit le script sur son entrée standard : `$0` vaut littéralement `bash`, et aucun fichier de ce nom n'existe en pratique — le test échoue, la fonction continue. Lancé localement (`bash install-prof.sh`, `./install-prof.sh`), `$0` pointe vers un vrai fichier : le test réussit, la fonction s'arrête aussitôt. C'est ce qui permet de développer et tester des modifications non encore poussées sans qu'elles soient écrasées par un re-téléchargement — vérifié empiriquement (`echo '[ -f "$0" ]...' | bash -s --` renvoie bien « pas un fichier »).
- **`_INSTALL_PROF_RELAUNCHED` est le garde-fou anti-boucle.** Sans lui, la version relancée verrait à son tour `DOTFILES_BRANCH = dev1 ≠ main` et tenterait de se relancer indéfiniment. La variable est exportée vers le `bash` relancé par `env`, donc déjà présente à son prochain passage dans la fonction.
- **La comparaison se fait contre `DEFAULT_DOTFILES_BRANCH` (`main`), jamais contre « la branche en cours ».** Le script n'a aucun moyen de savoir de quelle branche il a été récupéré — rien dans un flux `curl | bash` ne le lui dit. L'hypothèse posée est que l'URL utilisée par défaut pointe sur `main` (c'est ce qu'enseignent les EXAMPLES) ; relancer seulement quand `--branch` s'en écarte évite un aller-retour réseau superflu dans le cas courant.
- **Le contenu téléchargé est vérifié avant le `exec`.** `script_content="$(curl -fsSL "$url")" || die ...` capture l'échec de `curl` (branche inexistante, réseau coupé) ; un test `[ -n "$script_content" ]` couvre en plus le cas d'une réponse HTTP 200 mais vide. Sans ces deux gardes, un `curl` défaillant produirait une chaîne vide passée telle quelle à `bash -c` — un `bash -c ""` démarre et se termine avec succès sans rien faire, et l'échec passerait totalement inaperçu.

Le mécanisme a été validé par test direct de la fonction (sans passer par un vrai réseau, `curl` étant simulé) : exécution locale → aucune relance ; `curl \| bash` sur la branche par défaut → aucune relance ; `curl \| bash` avec `--branch dev1` → relance avec les arguments transmis et la variable de garde exportée ; relance déjà faite → pas de seconde tentative ; `curl` en échec → message d'erreur explicite et sortie en 1 (pas un `bash -c ""` silencieux).

**`ensure_prof_ssh_key()` résout le home et le groupe de prof dynamiquement**, via `getent passwd` et `id -gn`, plutôt que de supposer `/home/prof` et un groupe `prof`. Un `useradd` avec un home ou un schéma de groupe personnalisé (`adduser.conf`, LDAP, etc.) reste ainsi pris en compte.

**Idempotence par `grep -qxF`, pas par écrasement du fichier.** `authorized_keys` peut contenir d'autres clés ajoutées manuellement (portable personnel d'un enseignant, par exemple) : le script ajoute la sienne si elle est absente, sans jamais rien retirer. `-x` compare la ligne entière (évite qu'une clé soit vue comme « déjà présente » parce qu'elle est sous-chaîne d'une autre), `-F` traite le motif comme du texte brut et non une expression régulière — une clé base64 contient des caractères (`+`, `/`) qui ont un sens spécial en regex.

**`chown`/`chmod` sont réappliqués même quand la clé existait déjà.** `sshd` applique `StrictModes` par défaut : un `authorized_keys` ou un `.ssh` aux permissions trop larges est silencieusement ignoré, sans message d'erreur exploitable côté client. Un fichier créé ou modifié par une autre main (root en édition manuelle, par exemple) retrouve donc des permissions correctes à chaque exécution.

---

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 4.4 | `"${PROXY_ENV[@]}"` sur tableau vide sous `set -u` |
| `sudo` | — | Phase 1 ; `-u`, `-H`, `-n`, `-v` |
| `apt-get` | — | Installation de `yadm` (Debian ≥ 10, Ubuntu ≥ 20.04 fournissent le paquet) |
| `yadm` | 2.5 | `clone`, `fetch`, `checkout`, `submodule` (aucune option propre à la 3.x) |
| `coreutils` | — | `timeout`, `id`, `env` |
| `libc-bin` (`getent`) | — | Résolution du home de prof dans `ensure_prof_ssh_key()` |

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

**Autoriser plusieurs clés SSH** — `PROF_SSH_PUBKEY` n'accepte qu'une seule ligne. Pour plusieurs clés, remplacer la variable scalaire par un tableau et boucler dessus dans `ensure_prof_ssh_key()` en conservant le même test `grep -qxF` par clé, pour rester idempotent.

---

### Notes de maintenance

- **Le mot de passe par défaut est public**, et le compte a délibérément accès à `sudo` : ce script ne doit être diffusé que pour des VM de travaux pratiques isolées, jamais pour une machine exposée à un réseau non maîtrisé.
- **La clé SSH par défaut est, elle aussi, embarquée dans le script** et donc publique au même titre que le mot de passe. Révoquer l'accès qu'elle donne suppose de retirer la ligne correspondante de `~prof/.ssh/authorized_keys` sur chaque VM déjà provisionnée : changer `PROF_SSH_PUBKEY` dans le script n'affecte que les futures exécutions, il n'existe pas de mécanisme de rotation.
- **Le `checkout -f` est destructeur** pour le home de prof. C'est le comportement voulu, mais il interdit d'utiliser prof comme compte de travail : les fichiers suivis par le dépôt y sont écrasés à chaque exécution.
- **Le payload sérialisé est le point fragile.** Une fonction de phase 2 oubliée dans la liste `declare -f` ne se voit qu'à l'exécution, sous forme de `command not found` dans la session prof. Le payload se teste sans droits particuliers en remplaçant `sudo -u prof -H env … bash -s` par `cat`.
- **`SCRIPT_RAW_URL_BASE`/`SCRIPT_RAW_PATH` dupliquent le chemin du script**, utilisé par `relaunch_from_branch_if_needed()` pour se retélécharger. Un renommage du dépôt, du script, ou son déplacement dans `.local/bin/` doit être répercuté ici — sans quoi l'auto-relance échoue avec un message `curl` explicite (404), sans effet silencieux.
- **L'auto-relance ajoute un aller-retour réseau à chaque usage de `--branch dev1`**, y compris quand l'URL de départ pointait déjà sur `dev1` — la vérification `[ -f "$0" ]` ne sait pas d'où vient le contenu déjà chargé, seulement s'il vient d'un fichier local. Construire l'URL de `curl` avec la même variable que `--branch` (voir les exemples) évite ce coût dans le cas où l'on connaît déjà la branche cible.
- **`raw.githubusercontent.com` est mis en cache 5 minutes** (`max-age=300`, CDN Fastly) : après un push, la commande `curl … | bash` peut encore servir la version précédente. Un paramètre `?v=…` ne contourne rien, la clé de cache ignore la *query string*.
