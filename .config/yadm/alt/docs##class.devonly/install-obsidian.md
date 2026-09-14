# `install-obsidian.sh` — Installation d'Obsidian via `.deb` depuis GitHub Releases

> Script : [`.local/bin/install-obsidian.sh`](../.local/bin/install-obsidian.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-obsidian.sh` installe Obsidian sur Debian/Ubuntu en téléchargeant le `.deb` officiel publié sur GitHub Releases (`obsidianmd/obsidian-releases`), sans passer par Flatpak ni Snap. Sans argument, il ne se contente pas de la toute dernière release : certaines ne publient pas de `.deb` pour toutes les architectures (release mobile-only, `.deb` arm64 jamais publié), donc le script recule automatiquement jusqu'à trouver la version la plus récente qui en fournit un, et le signale en `[ATTENTION]`. Un numéro de version peut être passé en argument (`install-obsidian.sh 1.13.6`) pour installer une version précise ; le script échoue alors proprement si cette version n'a pas de `.deb` pour l'architecture détectée, plutôt que de tenter un téléchargement voué à l'échec. Il détecte automatiquement `amd64`/`arm64`, refuse de s'exécuter en root, ne demande le mot de passe sudo qu'une fois, et propose de réinstaller si Obsidian est déjà présent. Ce script ne gère ni les mises à jour automatiques ni les canaux beta/insider d'Obsidian — seulement les releases stables publiées sur GitHub.

---

## Section utilisateur

### Description

`install-obsidian.sh` installe ou met à jour Obsidian via le paquet `.deb` officiel, téléchargé depuis les releases GitHub du dépôt `obsidianmd/obsidian-releases`. C'est une alternative à Flatpak ou au Snap communautaire : le `.deb` s'intègre à `dpkg`/`apt` comme n'importe quel paquet système, et les mises à jour se font en relançant le script.

Sa particularité, par rapport à un simple `curl .../releases/latest`, est de ne jamais supposer que la dernière release publiée contient un `.deb` pour l'architecture de la machine — voir *Détail des choix techniques* pour la raison.

### Prérequis

| Outil        | Rôle                                          | Vérification       |
| ------------ | ---------------------------------------------- | ------------------- |
| `bash` ≥ 4   | Interpréteur                                   | `bash --version`    |
| `curl`       | Appels à l'API GitHub, téléchargement du `.deb` | `curl --version`    |
| `jq`         | Extraction JSON (releases, assets)             | `jq --version`      |
| `dpkg`       | Architecture, état du paquet installé          | `dpkg --version`    |
| `apt-get`    | Installation du `.deb` et de ses dépendances   | `apt-get --version` |
| `sudo`       | Élévation de privilèges pour l'installation    | `sudo -v`           |

Architecture supportée : `amd64` ou `arm64` (`dpkg --print-architecture`). En pratique, Obsidian n'a jamais publié de `.deb` arm64 (voir *Notes de maintenance*) : sur cette architecture, le script se terminera en erreur faute de `.deb` disponible.

### Syntaxe

```bash
install-obsidian.sh [VERSION]
```

| Argument  | Défaut                                              | Description                                                        |
| --------- | ---------------------------------------------------- | -------------------------------------------------------------------- |
| `VERSION` | dernière version disposant d'un `.deb` pour l'arch. | Numéro de version explicite, sans `v` (ex. `1.13.6`), à installer  |

Pas d'option `-h`/`--help` : le script n'accepte que cet unique argument positionnel.

### Exemples d'utilisation

```bash
# Installe la dernière version disposant d'un .deb pour l'architecture détectée
bash install-obsidian.sh

# Installe une version précise
bash install-obsidian.sh 1.13.6
```

**Exemple de sortie** (la dernière release publiée n'a pas de `.deb` amd64, le script recule d'une version) :

```
=== Installation d'Obsidian ===

[INFO]      Architecture détectée : amd64
[INFO]      Des droits administrateur sont nécessaires pour l'installation.
[INFO]      Recherche de la dernière version disposant d'un .deb pour amd64...
[ATTENTION] La dernière version (1.13.8) ne fournit pas de .deb pour amd64 ; utilisation de 1.13.7 à la place.
[OK]        Version retenue : 1.13.7
[INFO]      Téléchargement : https://github.com/obsidianmd/obsidian-releases/releases/download/v1.13.7/obsidian_1.13.7_amd64.deb
[OK]        Téléchargement terminé.
[INFO]      Installation du paquet...
[OK]        Obsidian installé avec succès : 1.13.7

Terminé. Lance Obsidian depuis le menu des applications ou avec : obsidian
```

### Codes de retour

| Code | Signification                                                                                                    |
| ---- | ------------------------------------------------------------------------------------------------------------------ |
| `0`  | Installation réussie                                                                                               |
| `1`  | Root détecté, dépendance manquante, architecture non supportée, version/`.deb` introuvable, échec de téléchargement ou d'installation `apt-get` |

Le script n'utilise pas de code d'erreur distinct pour les erreurs d'usage : toute condition anormale passe par `die` (code 1).

---

## Section développeur

### Architecture interne

`main()` enchaîne :

```
check_not_root         →  refuse l'exécution en root
check_dependencies     →  curl, jq, dpkg, apt-get présents
check_architecture     →  dpkg --print-architecture, restreint à amd64/arm64
check_already_installed →  propose de réinstaller si le paquet est déjà présent
sudo -v                →  préchauffage : un seul mot de passe pour toute la suite
resolve_release        →  détermine TARGET_VERSION, DEB_NAME, DEB_URL
download_and_install   →  téléchargement dans un répertoire temporaire, apt-get install
verify_install          →  contrôle dpkg -s après installation
```

`resolve_release` est la fonction centrale : elle prend en argument la version demandée (vide par défaut) et se branche sur deux chemins.

### Détail des choix techniques

**Pourquoi ne jamais utiliser `/releases/latest` tel quel.**
Obsidian publie parfois une release dont les seuls artefacts sont mobiles (`.apk`) ou dont le `.deb` d'une architecture manque. `/releases/latest` pointe alors vers une release inexploitable pour ce script, et une URL construite à la main (`obsidian_${VERSION}_${ARCH}.deb`) échoue au téléchargement avec un message peu clair. `resolve_release`, sans argument, récupère `${GITHUB_API_BASE}/releases?per_page=${RELEASES_LOOKBACK}` (les `RELEASES_LOOKBACK` releases les plus récentes, `RELEASES_LOOKBACK=20`), écarte drafts et prereleases, et prend la première qui possède effectivement un asset `obsidian_*_${ARCH}.deb`. Si ce n'est pas la toute dernière release du dépôt, un `warn` explicite le signale (version demandée vs version retenue).

**`any(.assets[]?; .name | test($pat))` plutôt qu'un filtre `select` direct sur `.assets[]`.**
`select(.assets[] | .name | test(...))` produirait une sortie dupliquée par asset correspondant lorsqu'il y en a plusieurs, et échouerait (`null (null) has no keys`) si `.assets` est vide sans le `?`. `any(...)` réduit le test à un booléen unique par release, compatible avec `map(select(...))`.

**`browser_download_url` de l'API plutôt qu'une URL reconstruite.**
Une fois la release identifiée, le nom exact de l'asset et son URL de téléchargement viennent directement du JSON de l'API, pas d'une concaténation `https://github.com/.../releases/download/v${VERSION}/obsidian_${VERSION}_${ARCH}.deb`. Ça élimine tout risque de désynchronisation si le gabarit de nommage change un jour (préfixe, casse, tiret vs underscore).

**Version explicite vérifiée, pas supposée valide.**
Avec un argument, le script interroge `${GITHUB_API_BASE}/releases/tags/v${VERSION}` (une release précise, pas une liste) et cherche l'asset `.deb` correspondant à l'architecture. Si le tag n'existe pas, `curl -f` échoue et remonte un `die` explicite ; si le tag existe mais sans `.deb` pour cette architecture, un second `die` le précise — plutôt que de laisser `apt-get install` échouer sur un fichier jamais téléchargé.

**`RELEASES_LOOKBACK=20`.**
Profondeur arbitraire, choisie pour couvrir largement le cas observé (une seule release sur les 30 dernières sans `.deb` amd64 au moment de l'écriture). Si Obsidian enchaînait plus de 20 releases sans `.deb` pour une architecture donnée, le script échouerait avec un message explicite plutôt que de chercher indéfiniment — cas jugé improbable et, le cas échéant, plus vite diagnostiqué par une erreur claire que par une recherche silencieuse sans borne.

**`check_already_installed` ne connaît pas encore la version cible.**
Elle s'exécute avant `resolve_release` et compare uniquement « déjà installé ou non », pas les numéros de version. Une réinstallation de la même version déjà en place déclenchera donc la question de confirmation comme une mise à jour.

### Dépendances externes

| Binaire   | Version minimale | Fonctionnalité qui l'impose                                  |
| --------- | ----------------- | -------------------------------------------------------------- |
| `curl`    | —                  | `-f` (échec sur 4xx/5xx), appels API GitHub et téléchargement |
| `jq`      | 1.6                | `test()` (regex), `any()`, `--arg`                             |
| `dpkg`    | —                  | `--print-architecture`, `-s`                                   |
| `apt-get` | —                  | Installation d'un `.deb` local avec résolution des dépendances |

API GitHub publique, non authentifiée : `https://api.github.com/repos/obsidianmd/obsidian-releases` — soumise à la limite de 60 requêtes/heure par IP. Le script en fait une à deux par exécution (une pour la liste des releases ou le tag précis, une implicite via `curl` pour le `.deb`), donc peu exposé sauf IP partagée (CI, NAT commun).

### Points d'extension

**Lister les versions disponibles avec `.deb`** — utile pour choisir un argument `VERSION` sans deviner :

```bash
curl -fsSL "${GITHUB_API_BASE}/releases?per_page=${RELEASES_LOOKBACK}" \
  | jq -r --arg pat "^obsidian_.*_${ARCH}\\.deb\$" \
      '.[] | select(any(.assets[]?; .name | test($pat))) | .tag_name'
```

**Rendre `RELEASES_LOOKBACK` configurable** — remplacer la constante `readonly` par une valeur par défaut surchargeable :

```bash
readonly RELEASES_LOOKBACK="${RELEASES_LOOKBACK:-20}"
```

### Notes de maintenance

- **`.deb` arm64 jamais publié.** Vérifié sur les 30 dernières releases du dépôt `obsidianmd/obsidian-releases` (2026-09-14) : aucune ne propose de `.deb` `arm64`, seulement `.AppImage`/`.tar.gz`. Sur cette architecture, le script se terminera systématiquement par `Aucune des 20 dernières releases ne propose de .deb pour arm64`, ce qui est le comportement attendu et non une régression du fallback.
- **Fallback silencieux impossible à distinguer d'une erreur réseau transitoire dans les logs sans le message `[ATTENTION]`.** Si ce message disparaît un jour (refactor), un utilisateur pourrait installer une version plus ancienne qu'attendu sans le remarquer.
- **Pas de vérification de signature/checksum** du `.deb` téléchargé : la confiance repose sur HTTPS + GitHub. Cohérent avec les autres installateurs `.deb` du dépôt (`install-gitkraken.sh`, `firefox-snap-vers-apt.sh`), à revoir globalement si le besoin apparaît.
