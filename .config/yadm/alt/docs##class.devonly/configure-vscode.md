# `configure-vscode.sh` — Configuration de VS Code par profil (classe, maison…)

> Script : [`.local/bin/configure-vscode.sh`](../.local/bin/configure-vscode.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`configure-vscode.sh` applique à VS Code une configuration décrite par des fichiers versionnés dans `~/.config/vscode-profils/` : réglages (`settings.json`), raccourcis (`keybindings.json`) et extensions, thèmes compris. Il remplace la synchronisation intégrée de VS Code quand la configuration diffère selon la machine : un profil `base` commun est toujours appliqué, puis le profil choisi avec `-p classe` ou `-p maison`. Il **ne remplace pas** les fichiers locaux : les clés des profils sont imposées, mais tout le reste de `settings.json` et les raccourcis personnels sont conservés, et aucune extension n'est jamais désinstallée. Il ne s'occupe **pas** de l'installation de VS Code lui-même, qui reste le rôle de `install-vscode.sh`. À utiliser en pratique : `-n` pour voir les changements sans rien écrire, `-p NOM` pour choisir le profil, `-E` pour ne pas toucher aux extensions.

---

## Section utilisateur

### Description

`configure-vscode.sh` rend la configuration de VS Code **reproductible et dépendante du contexte**. La synchronisation intégrée de VS Code (Settings Sync) applique la même configuration partout ; ici, chaque machine choisit son profil au moment de l'exécution : projecteur et grosses polices en classe, confort personnel à la maison.

Les profils vivent dans le dépôt dotfile, sous `.config/vscode-profils/` (déployé dans `~/.config/vscode-profils/` par yadm) :

```
~/.config/vscode-profils/
├── base/                   ← toujours appliqué, en premier
│   ├── settings.json
│   ├── keybindings.json
│   └── extensions.txt
├── classe/                 ← -p classe
│   └── …
└── maison/                 ← -p maison
    └── …
```

Chaque fichier est facultatif dans un profil. Pour créer un nouveau profil, créer un sous-répertoire : il apparaît aussitôt dans `--list`.

**Ce que fait chaque fichier**

| Fichier            | Règle de fusion                                                                                      |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `settings.json`    | Chaque clé du profil est **imposée** (ajoutée ou écrasée). Les autres clés du fichier local sont conservées. |
| `keybindings.json` | Les raccourcis absents sont **ajoutés**. Les raccourcis déjà présents, y compris les personnels, sont conservés. |
| `extensions.txt`   | Les extensions absentes sont **installées**. Rien n'est jamais désinstallé.                          |

Quand plusieurs couches définissent la même clé, **la dernière l'emporte** (`base` puis `-p`, dans l'ordre de la ligne de commande). Dans `base`, `editor.minimap.enabled` vaut `false` ; le profil `maison` le repasse à `true`.

Le thème actif se choisit avec `workbench.colorTheme` dans `settings.json`. Les thèmes eux-mêmes sont des extensions : les lister dans `extensions.txt`.

---

### Prérequis

| Outil          | Rôle                                                   | Vérification                |
| -------------- | ------------------------------------------------------ | --------------------------- |
| `bash` ≥ 4     | Interpréteur (`mapfile`, `${var,,}`)                   | `bash --version`            |
| `python3`      | Fusion des JSON, lecture des commentaires et virgules finales | `python3 --version`  |
| `code`         | Installation des extensions (`--install-extension`)    | `code --version`            |

`code` n'est pas nécessaire avec `--no-extensions`. Avec `--insiders`, c'est `code-insiders` qui est requis. Aucun droit administrateur n'est demandé ; **le script refuse de tourner en root** pour ne pas créer de fichiers root dans `~/.config`.

---

### Syntaxe

```
configure-vscode.sh [-p PROFIL]... [-n] [-E] [-i] [-d DIR] [-l] [-h]
```

| Option                | Argument | Défaut                         | Description                                                           |
| --------------------- | -------- | ------------------------------ | --------------------------------------------------------------------- |
| `-p`, `--profil`      | nom      | — (seulement `base`)           | Profil appliqué après `base`. **Répétable.**                          |
| `-n`, `--dry-run`     | —        | désactivé                      | Affiche les changements sans rien écrire ni installer                 |
| `-E`, `--no-extensions` | —      | extensions traitées            | Ne touche pas aux extensions                                          |
| `-i`, `--insiders`    | —        | VS Code stable                 | Cible `code-insiders` et `~/.config/Code - Insiders/User`             |
| `-d`, `--config-dir`  | chemin   | `~/.config/vscode-profils`     | Répertoire des profils (utile depuis une copie de travail du dépôt)   |
| `-l`, `--list`        | —        | —                              | Liste les profils disponibles et quitte                               |
| `-h`, `--help`        | —        | —                              | Affiche l'en-tête manpage du script                                   |

---

### Exemples d'utilisation

```bash
# Voir ce que ferait le profil « classe », sans rien modifier
configure-vscode.sh -p classe -n

# Appliquer le profil « maison »
configure-vscode.sh -p maison

# Seulement la configuration commune (base)
configure-vscode.sh

# Réglages et raccourcis seulement, sans installer d'extension
configure-vscode.sh -p classe -E

# Depuis une copie de travail du dépôt, sans passer par ~/.config
configure-vscode.sh -d ~/projets/dotfile/.config/vscode-profils -p classe -n

# Lister les profils
configure-vscode.sh --list
```

**Exemple de sortie** (`configure-vscode.sh -p classe`) :

```
=== Configuration de VS Code ===

[INFO]      Profils    : base classe
[INFO]      Cible      : /home/user/.config/Code/User

    + telemetry.telemetryLevel = "off"
    + editor.tabSize = 4
    …
    ~ editor.fontSize : 12 -> 18
    + breadcrumbs.enabled = false
[OK]        Réglages   : 23 modification(s) — /home/user/.config/Code/User/settings.json
    + ctrl+alt+= -> workbench.action.zoomIn
    + ctrl+alt+- -> workbench.action.zoomOut
[OK]        Raccourcis : 2 modification(s) — /home/user/.config/Code/User/keybindings.json
    + vscode-icons-team.vscode-icons
    + catppuccin.catppuccin-vsc
[OK]        Extensions : 2 installée(s), 1 déjà présente(s).
```

Légende : `+` ajouté, `~` valeur remplacée (ancienne `->` nouvelle). Une seconde exécution affiche `déjà conforme` pour les réglages et les raccourcis.

**Sauvegardes** : avant toute modification, `settings.json` et `keybindings.json` sont copiés en `settings.json.bak-AAAAMMJJ_HHMMSS` dans le même répertoire.

---

### Codes de retour

| Code | Signification                                                                                           |
| ---- | ------------------------------------------------------------------------------------------------------- |
| `0`  | Configuration appliquée, ou déjà conforme                                                               |
| `1`  | Erreur d'exécution : lancé en root, `python3` ou `code` absent, JSON local illisible, échec d'installation d'une extension |
| `2`  | Erreur d'usage : option inconnue, option sans valeur, profil introuvable                                |

---

## Section développeur

### Architecture interne

```
parse_args         →  options (boucle while, value_of pour les valeurs manquantes)
list_profiles      →  --list : sous-répertoires de CONFIG_DIR, puis sortie
check_not_root     →  Tier 3 : refus d'une exécution root
check_prereqs      →  python3, code / code-insiders, chemin du répertoire utilisateur VS Code
resolve_layers     →  ordre d'application : base + profils demandés (validés)
apply_json         →  settings.json puis keybindings.json, via merge_json
  └─ merge_json    →  Python embarqué : lecture JSONC, fusion, sauvegarde, écriture atomique
install_extensions →  extensions.txt des couches, comparaison avec `code --list-extensions`
```

---

### Détail des choix techniques

**Fusion plutôt que remplacement**
Les profils ne décrivent que ce qui est *imposé*. Écraser `settings.json` détruirait les réglages que VS Code ou d'autres extensions y écrivent (`claudeCode.*`, `github.copilot.*`…). Le fichier local garde donc toutes les clés que le profil ne mentionne pas.

**Python embarqué pour la fusion**
VS Code écrit `settings.json` et `keybindings.json` en **JSONC** (commentaires, virgules finales) : `jq` les rejette. Le script embarque un petit lecteur qui retire commentaires et virgules finales **en respectant les chaînes** (un `//` dans une URL comme `"http://…"` n'est pas un commentaire). Lancé en `python3 -I` : ni variables d'environnement `PYTHON*`, ni répertoire courant dans `sys.path`.

**Un fichier déjà conforme n'est pas réécrit**
La réécriture se fait en JSON standard et **supprime les commentaires** du fichier local. Pour ne pas les perdre inutilement, le fichier n'est réécrit que s'il y a au moins un changement (le code retour interne `3` signifie « rien à faire »). Dans le cas contraire, la copie `.bak-…` conserve la version commentée.

**JSON local illisible : on s'arrête**
Un `settings.json` invalide n'est jamais « réparé » ni écrasé : le script s'arrête sur l'erreur (code 1) en indiquant la position du problème.

**Écriture atomique**
Le résultat est écrit dans `settings.json.tmp` puis renommé (`os.replace`). Un plantage ou un Ctrl-C ne laisse jamais un fichier tronqué.

**Raccourcis : comparaison par signature**
Un raccourci est identifié par son contenu JSON complet (clés triées). Un raccourci identique est ignoré ; sinon il est ajouté. Deux raccourcis distincts sur la même touche coexistent : VS Code applique le dernier du fichier, donc le profil le plus spécifique (ajouté en dernier) gagne. Pour retirer un raccourci par défaut, utiliser la forme `-commande` de VS Code dans `keybindings.json`.

**Extensions : comparaison insensible à la casse**
Les identifiants d'extension sont insensibles à la casse, et `code --list-extensions` peut les restituer avec une casse différente de celle saisie. Les deux listes sont donc comparées en minuscules, ce qui évite de réinstaller indéfiniment `GitHub.github-vscode-theme` parce qu'il a été saisi `github.github-vscode-theme`.

**Aucune désinstallation**
Le script ne connaît que ce qu'on lui demande d'ajouter : une extension absente de la liste peut avoir été installée volontairement. Supprimer une extension reste un geste manuel (`code --uninstall-extension`).

---

### Dépendances externes

```
bash ≥ 4     →  mapfile, ${var,,}
python3 ≥ 3.6 →  json, os, shutil ; f-strings, dict ordonné (fusion de settings)
code         →  --list-extensions, --install-extension
coreutils    →  find (-printf), sort, date
sed, awk, grep
```

---

### Points d'extension

**Nouveau profil** : créer le répertoire, il est pris en compte sans modifier le script.

```bash
mkdir ~/.config/vscode-profils/demo
$EDITOR ~/.config/vscode-profils/demo/settings.json
configure-vscode.sh -p demo -n
```

**Autre fichier géré** (ex. snippets, `tasks.json`) : ajouter un appel dans `main()` et, si la règle « fusion par clé » ou « ajout si absent » convient, réutiliser `merge_json` avec un nouveau mode :

```bash
apply_json "Snippets" snippets "$USER_DIR/snippets/global.code-snippets" "snippets.json"
```

Le mode `snippets` serait à ajouter à la branche `if mode == "settings"` du Python (même logique que les réglages : objet JSON, fusion par clé).

**Autre éditeur** (VSCodium) : ajouter une option comme `--insiders`, qui fixe `CODE_BIN` (`codium`) et `USER_DIR` (`~/.config/VSCodium/User`) dans `check_prereqs`.

---

### Notes de maintenance

- **Commentaires perdus dans `settings.json`** après une fusion qui change quelque chose : limite assumée (voir plus haut). Un lecteur/écrivain JSONC qui préserve les commentaires demanderait une dépendance externe.
- **Pas de suppression de clé** : un profil ne peut pas retirer un réglage du fichier local (une valeur `null` serait écrite telle quelle, et `null` a un sens pour certains réglages VS Code).
- **Profils intégrés de VS Code** (menu « Profils ») : le script cible les réglages **globaux** de l'utilisateur (`User/settings.json`), pas les profils VS Code créés dans l'interface (`User/profiles/<id>/`).
- **Réglages machine-spécifiques** : certains réglages (`terminal.integrated.defaultProfile.linux`, polices) dépendent de la machine ; les placer dans le profil qui correspond plutôt que dans `base`.
- **Extensions et réseau** : l'installation exige un accès au Marketplace. Sans réseau, chaque extension échoue et le script se termine avec le code 1 après avoir traité les réglages et les raccourcis.
- **Identifiants d'extension** : `base/extensions.txt` contient des thèmes d'exemple (`GitHub.github-vscode-theme`, `zhuangtongfa.material-theme`, `catppuccin.catppuccin-vsc`). Vérifier l'identifiant exact dans l'onglet « Détails » de l'extension (`code --list-extensions` après installation manuelle).
