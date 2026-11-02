# `uninstall-starship.sh` — Désinstallation de Starship

> Script : [`.local/bin/uninstall-starship.sh`](../.local/bin/uninstall-starship.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`uninstall-starship.sh` retire le prompt **Starship** : le binaire, où qu'il soit (`/usr/local/bin`, `~/.local/bin`, `~/.cargo/bin`), et le cache `~/.cache/starship`. Il ne modifie aucun fichier shellrc : sans le binaire, `10_prompt.bash` bascule seul sur le prompt Bash coloré de secours. Les profils `~/.config/starship`, suivis par yadm, sont conservés. Il ne supprime pas à la main un binaire installé par `apt`, `snap` ou Homebrew : il indique la commande adaptée. `sudo` n'est demandé que si le binaire est dans un répertoire système ; l'option utile est `-y` (aucune question), et le script refuse de tourner en root.

---

## Section utilisateur

### Description

Pendant de [`install-starship.sh`](../.local/bin/install-starship.sh). L'installeur officiel dépose le binaire dans `/usr/local/bin` (droits administrateur), alors que `install-starship.sh` l'installe selon ce que l'installeur décide ; le script cherche donc dans tous les emplacements usuels.

| Élément                      | Traitement                          |
| ---------------------------- | ----------------------------------- |
| Binaire `starship`           | supprimé (sudo si répertoire système) |
| `~/.cache/starship`          | supprimé                            |
| `~/.config/starship/*.toml`, `current_profile` | conservés (yadm)   |
| `.shellrc/bashrc.d/10_prompt.bash` | inchangé : bascule sur le fallback |

---

### Prérequis

| Outil   | Rôle                                           | Vérification      |
| ------- | ---------------------------------------------- | ----------------- |
| `bash`  | Interpréteur                                   | `bash --version`  |
| `sudo`  | Suppression d'un binaire système (si besoin)   | `sudo -v`         |
| `dpkg`  | Détecte un binaire fourni par un paquet (optionnel) | `dpkg --version` |

---

### Syntaxe

```
uninstall-starship.sh [-y] [-h]
```

| Option         | Argument | Défaut | Description                  |
| -------------- | -------- | ------ | ---------------------------- |
| `-y`, `--yes`  | —        | non    | Aucune confirmation          |
| `-h`, `--help` | —        | —      | Affiche l'en-tête du script  |

---

### Exemples d'utilisation

```bash
# Avec confirmation
uninstall-starship.sh

# Non interactif
uninstall-starship.sh -y

# Recharger le prompt ensuite
exec $SHELL
```

**Exemple de sortie :**

```
=== Désinstallation de Starship ===

[INFO]      Suppression du binaire : /home/user/.local/bin/starship
[OK]        Binaire supprimé.
[OK]        Cache supprimé : /home/user/.cache/starship
[INFO]      Profils conservés (gérés par yadm) : /home/user/.config/starship
[INFO]      Le prompt Bash de secours sera utilisé à la prochaine ouverture de shell.
[OK]        Désinstallation terminée. Lancez « exec $SHELL » pour recharger le prompt.
```

---

### Codes de retour

| Code | Signification                                                              |
| ---- | -------------------------------------------------------------------------- |
| 0    | Désinstallation terminée, ou Starship n'était pas installé                 |
| 1    | Option inconnue, root, binaire géré par apt/snap/Homebrew, annulation      |

---

## Section développeur

### Architecture interne

`main()` : `parse_args` → `check_not_root` → sortie anticipée si rien à retirer → `confirm` → `remove_binaries` (vérifie tout, puis `sudo -v` si besoin, puis supprime) → `remove_cache` → `report_leftovers`.

### Détail des choix techniques

- **Tier 2 (sudo ponctuel)** : le binaire installé par l'installeur officiel est root-owned, un binaire dans `~/.local/bin` ne l'est pas. Le test `-w` sur le répertoire décide, et `sudo -v` n'est lancé qu'une fois, avant toute suppression.
- **Vérification avant suppression** : `check_not_packaged` est appliqué à tous les binaires avant de supprimer le premier, pour ne pas laisser une désinstallation à moitié faite.
- **Pas de modification de `10_prompt.bash`** : le fallback est déjà prévu quand `starship` est introuvable.
- **Profils conservés** : versionnés par yadm, leur suppression créerait des modifications non commitées.

### Dépendances externes

`bash` ≥ 4 (tableaux), `readlink`, `sort`, `sudo` (cas système), `dpkg` (optionnel).

### Points d'extension

```bash
readonly BIN_CANDIDATES=(
    "/usr/local/bin/starship"
    "/opt/starship/bin/starship"   # nouvel emplacement
)
```

### Notes de maintenance

- Un binaire trouvé uniquement via le `PATH` dans un emplacement atypique est aussi supprimé (après les contrôles paquet).
- L'`eval "$(starship init bash)"` d'un shell déjà ouvert reste actif jusqu'à `exec $SHELL`.
