# `uninstall-atuin.sh` — Désinstallation d'Atuin

> Script : [`.local/bin/uninstall-atuin.sh`](../.local/bin/uninstall-atuin.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`uninstall-atuin.sh` retire **Atuin** installé par `install-atuin.sh` : le binaire (`~/.atuin/bin`, `~/.cargo/bin` ou `~/.local/bin`) et le reçu d'installation. Il ne touche ni à `~/.config/atuin/config.toml`, suivi par yadm, ni aux fichiers `.shellrc`, dont l'intégration devient inerte sans le binaire. Par défaut l'**historique local est conservé**, de sorte qu'une réinstallation le retrouve ; `--purge-data` le supprime aussi (irréversible, avec confirmation). Il ne supprime pas le compte de synchronisation côté serveur : pour cela, lancer `atuin delete` avant la désinstallation. Les options utiles sont `--purge-data` et `-y` (aucune question) ; le script refuse de tourner en root.

---

## Section utilisateur

### Description

Pendant du script [`install-atuin.sh`](install-atuin.md) (installeur officiel `setup.atuin.sh`). Il supprime ce que cet installeur a déposé et rien d'autre : la configuration versionnée par yadm et l'intégration shell du dépôt sont laissées en place.

| Élément                         | Par défaut | Avec `--purge-data` |
| ------------------------------- | ---------- | ------------------- |
| Binaire `atuin`                 | supprimé   | supprimé            |
| `~/.config/atuin/atuin-receipt.json` | supprimé | supprimé          |
| `~/.config/atuin/config.toml`   | conservé   | conservé            |
| `~/.local/share/atuin` (historique, clé, session) | conservé | supprimé |
| `~/.atuin` (ancien emplacement) | conservé   | supprimé            |

---

### Prérequis

| Outil  | Rôle                                         | Vérification      |
| ------ | -------------------------------------------- | ----------------- |
| `bash` | Interpréteur                                 | `bash --version`  |
| `dpkg` | Détecte un binaire fourni par un paquet      | `dpkg --version`  |

Aucun droit administrateur n'est requis ; lancé en root, le script s'arrête.

---

### Syntaxe

```
uninstall-atuin.sh [--purge-data] [-y] [-h]
```

| Option         | Argument | Défaut | Description                                              |
| -------------- | -------- | ------ | -------------------------------------------------------- |
| `--purge-data` | —        | non    | Supprime aussi l'historique et les clés locales          |
| `-y`, `--yes`  | —        | non    | Aucune confirmation                                      |
| `-h`, `--help` | —        | —      | Affiche l'en-tête du script                              |

---

### Exemples d'utilisation

```bash
# Retire le programme, garde l'historique
uninstall-atuin.sh

# Retire tout, après confirmation
uninstall-atuin.sh --purge-data

# Non interactif
uninstall-atuin.sh --purge-data -y
```

**Exemple de sortie :**

```
=== Désinstallation d'Atuin ===

[INFO]      Suppression du binaire : /home/user/.atuin/bin/atuin
[OK]        Binaire supprimé.
[INFO]      Historique conservé : /home/user/.local/share/atuin (--purge-data pour le supprimer).
[INFO]      Configuration conservée (gérée par yadm) : /home/user/.config/atuin/config.toml
[OK]        Désinstallation terminée. Ouvrez un nouveau shell pour recharger l'environnement.
```

---

### Codes de retour

| Code | Signification                                                          |
| ---- | ---------------------------------------------------------------------- |
| 0    | Désinstallation terminée, ou Atuin n'était pas installé                |
| 1    | Option inconnue, exécution en root, binaire fourni par un paquet, annulation |

---

## Section développeur

### Architecture interne

`main()` : `parse_args` → `check_not_root` → sortie anticipée si rien à retirer → `confirm` → `remove_binaries` → `remove_receipt` → `purge_data` (si demandé) → `report_leftovers`.

### Détail des choix techniques

- **Historique conservé par défaut** : la base SQLite est la seule partie non reproductible ; sa suppression doit être un choix explicite.
- **`config.toml` jamais supprimé** : il est versionné par yadm (`.config/atuin/`) ; l'effacer créerait une modification non commitée.
- **Shell non modifié** : `.shellrc/bashrc.d/99_atuin.bash` est gardé par `command -v atuin`, inutile de le défaire.
- **`dpkg -S` avant `rm`** : un binaire de paquet doit être retiré par `apt` pour ne pas désynchroniser dpkg ; le script s'arrête avec la commande à lancer.
- **`readlink -f` + `sort -u`** : le binaire trouvé par `PATH` et par les emplacements connus est souvent le même fichier.

### Dépendances externes

`bash` ≥ 4 (tableaux), `dpkg`, `readlink`, `sort` (coreutils).

### Points d'extension

Ajouter un emplacement de binaire :

```bash
readonly BIN_CANDIDATES=(
    "$HOME/.atuin/bin/atuin"
    "$HOME/.local/opt/atuin/atuin"   # nouvel emplacement
)
```

### Notes de maintenance

- Le script ne se déconnecte pas du serveur de synchronisation : `atuin logout` / `atuin delete` doivent être lancés **avant** la désinstallation, tant que le binaire existe.
- Le nom du reçu (`atuin-receipt.json`) est celui produit par l'installeur cargo-dist ; à revérifier si l'installeur change.
