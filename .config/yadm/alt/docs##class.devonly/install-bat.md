# `install-bat.sh` — cat/more avec coloration syntaxique

> Script : [`.local/bin/install-bat.sh`](../.local/bin/install-bat.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-bat.sh` installe **bat**, un remplaçant de `cat`/`more` : coloration syntaxique, numérotation des lignes, et marquage des lignes modifiées par rapport au dépôt Git. Il télécharge le binaire officiel depuis les releases GitHub du projet et l'installe dans `~/.local/bin`, sans droits root et sans passer par les paquets APT. Point important : sur Debian/Ubuntu, le paquet APT `bat` installe le binaire sous le nom **`batcat`** (conflit avec un autre paquet déjà nommé `bat`) — ce script installe le vrai nom `bat` et crée en plus un lien `batcat`, pour rester compatible avec la configuration fzf déjà présente dans ce dépôt sans y toucher. Il ne configure rien d'autre : pas d'alias `cat=bat`, laissé au choix de l'utilisateur. Relancé, il met simplement à jour vers la dernière version disponible.

---

## Section utilisateur

### Description

`bat` affiche le contenu d'un fichier comme `cat`, mais avec coloration syntaxique (des dizaines de langages reconnus), numérotation des lignes, et un indicateur des lignes ajoutées/modifiées par rapport à l'état suivi par Git. Utilisé aussi comme aperçu dans fzf (déjà configuré dans ce dépôt via `FZF_PREVIEW_ARGS`, voir [`.shellrc/zshrc.d/04_fzf.zsh`](../.shellrc/zshrc.d/04_fzf.zsh)) ou comme `MANPAGER` pour des pages de manuel colorées.

Ne fait qu'installer le binaire : contrairement à `install-delta.sh`, il n'y a ici aucune configuration Git ou shell à proposer — `bat` fonctionne dès qu'il est dans le `PATH`.

### Le piège `bat` / `batcat`

Le paquet APT `bat` de Debian/Ubuntu installe son binaire sous le nom `batcat`, car un autre paquet préexistant s'appelait déjà `bat`. C'est pour cette raison que la configuration fzf de ce dépôt appelle `batcat` et non `bat`. Ce script contourne le problème en amont : il installe le binaire sous son vrai nom (`bat`), puis crée un lien symbolique `batcat` à côté — la configuration existante continue de fonctionner sans modification, quelle que soit la méthode d'installation utilisée (ce script ou APT).

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `curl` | Interrogation de l'API GitHub et téléchargement de l'archive | `curl --version` |
| `tar` | Extraction de l'archive `.tar.gz` | `tar --version` |

Aucun droit administrateur n'est requis : le script refuse même de s'exécuter en root (installation dans `$HOME/.local/bin`).

---

### Syntaxe

```
install-bat.sh [-h]
```

| Option | Description |
| ------ | ----------- |
| `-h`, `--help` | Affiche l'en-tête manpage du script |

---

### Exemples d'utilisation

```bash
bash install-bat.sh
```

Sortie d'une première installation :

```text
=== Installation de bat ===

[INFO]      Recherche de la dernière version de bat...
[INFO]      Téléchargement de bat v0.26.1 (x86_64-unknown-linux-musl)...
[OK]        bat v0.26.1 installé dans /home/utilisateur/.local/bin/bat (lien batcat créé pour compatibilité fzf).
[OK]        Installation vérifiée : bat 0.26.1 (979ba22)

Terminé. Essayer avec : bat <fichier>
```

À la relance, une ligne supplémentaire apparaît avant la recherche de version : `bat déjà présent : ... Mise à jour vers la dernière version...`.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | bat installé (ou déjà à jour) |
| 1 | Erreur d'exécution : téléchargement, extraction, architecture non supportée, binaire introuvable après installation |
| 2 | Erreur d'usage : option inconnue |

---

## Section développeur

### Architecture interne

```text
main()
├── parse_args()          # -h uniquement
├── check_not_root()
├── check_dependencies()  # curl, tar
├── [ bat déjà présent ] ─► info (mise à jour quand même, pas de blocage)
├── detect_arch()         # uname -m → ARCH_TAG
├── fetch_latest_tag()    # API GitHub → LATEST_TAG
├── install_binary()      # téléchargement + extraction + install + lien batcat
└── verify_install()      # bat --version
```

---

### Détail des choix techniques

**`grep` sans `-m1` pour lire la réponse de l'API GitHub.** `LATEST_TAG` est capturé par `curl ... | grep '"tag_name"' | sed ...`. Un `grep -m1` semblait naturel (une seule valeur voulue), mais il s'arrête dès la première correspondance trouvée et **ferme le pipe** avant que `curl` ait fini d'écrire toute la réponse — ce qui produit une erreur d'écriture (`curl: (23) Failure writing output to destination`), transformée par `pipefail` en échec de toute l'affectation, alors même que la donnée recherchée avait déjà été récupérée correctement :

```bash
$ bash -c 'set -euo pipefail; x=$(curl -fsSL "$URL" | grep -m1 "tag_name" | sed "..."); echo "$x"'
curl: (23) Failure writing output to destination
```

Reproduit et corrigé pendant le développement de ce script (la même faute existait dans la première version d'`install-delta.sh`). Sans `-m1`, `grep` lit jusqu'à l'EOF de `curl` avant de rendre la main ; l'API `/releases/latest` ne renvoie de toute façon qu'un seul `tag_name`, donc le résultat est identique — seul le comportement du pipe change.

**`TMP_DIR` n'est pas `local`.** Il est déclaré dans `install_binary()` mais sans `local`, exprès : le `trap 'rm -rf "$TMP_DIR"' EXIT` posé juste après reste actif pour tout le reste du script, y compris si `verify_install()` échoue plus tard. Une variable `local` aurait quitté sa portée au retour de `install_binary()`, et le trap aurait référencé une variable non définie au moment de se déclencher — `unbound variable` sous `set -u`, repéré en testant volontairement un échec de `verify_install()` pendant le développement.

**Pas de prompt avant réinstallation.** Contrairement aux scripts qui modifient un fichier de configuration (voir `install-ghostty.sh`), remplacer le binaire `bat` par sa dernière version n'a pas d'effet de bord à confirmer : le script informe simplement que `bat` est déjà présent, puis procède à la mise à jour sans bloquer — le même choix que `install-zoxide.sh`.

**Le lien `batcat` est relatif (`ln -sf bat …`), pas absolu.** Il reste valide quel que soit l'emplacement réel de `$HOME/.local/bin` (utile si `$HOME` est monté à un autre chemin, par exemple dans un conteneur ou pendant un test avec `HOME` surchargé).

---

### Dépendances externes

| Binaire | Rôle |
| ------- | ---- |
| `curl` | API GitHub (`releases/latest`) et téléchargement de l'archive |
| `tar` | Extraction de l'archive `.tar.gz` |
| `install` (coreutils) | Copie du binaire avec le mode `0755` |

---

### Points d'extension

**Ajouter une architecture** — compléter le `case` de `detect_arch()`. Vérifier au préalable, dans les assets de la dernière release GitHub (`https://api.github.com/repos/sharkdp/bat/releases/latest`), qu'un build `musl` existe pour cette architecture ; à défaut, utiliser la variante `gnu` correspondante (voir `install-delta.sh`, qui n'a pas de build `musl` pour `aarch64`/`arm`).

**Installer aussi la page de manuel ou les complétions.** L'archive de bat contient `bat.1` (page de manuel) et un dossier `autocomplete/` (bash/zsh/fish) — non installés ici pour rester au même niveau de simplicité que les autres installateurs `~/.local/bin` du dépôt (`install-zoxide.sh`, `install-atuin.sh`). Les ajouter suppose de copier `bat.1` dans un répertoire présent dans `MANPATH` (ex. `~/.local/share/man/man1/`) et le fichier de complétion adapté dans le répertoire lu par le shell.

---

### Notes de maintenance

- **Le format du tag change selon le projet.** bat préfixe ses tags avec `v` (`v0.26.1`), repris tel quel dans le nom de l'archive et l'URL de téléchargement — contrairement à `delta`, qui n'a pas ce préfixe (voir `install-delta.sh`). Ne pas essayer d'unifier les deux scripts sur une hypothèse commune de format de tag.
- **La structure de l'archive est supposée stable** (`bat-${TAG}-${ARCH_TAG}/bat`) : un changement de nommage côté projet (rare, mais déjà vu sur d'autres outils Rust) casserait `install_binary()` avec un message explicite (`Binaire bat introuvable dans l'archive téléchargée`), jamais silencieusement.
