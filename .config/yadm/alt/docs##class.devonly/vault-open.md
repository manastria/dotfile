# vault-open.sh / vault-close.sh / vault-status.sh

> Scripts : [`.local/bin/vault-open.sh`](../.local/bin/vault-open.sh), [`.local/bin/vault-close.sh`](../.local/bin/vault-close.sh), [`.local/bin/vault-status.sh`](../.local/bin/vault-status.sh)
> Script associé : [`vault-create.sh`](../.local/bin/vault-create.sh) — création initiale du conteneur, à part

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`vault-open.sh`, `vault-close.sh` et `vault-status.sh` gèrent le cycle de vie quotidien du coffre chiffré LUKS de la machine prof, une fois celui-ci créé par `vault-create.sh`. `vault-open.sh` déverrouille le conteneur LUKS, monte le volume et met en place les bind mounts qui redirigent les profils de navigateurs (Vivaldi, Brave, Firefox) vers le vault ; `vault-close.sh` fait l'inverse — ferme les navigateurs, démonte les binds puis le volume, referme LUKS. `vault-status.sh` n'agit sur rien : il affiche l'état courant (LUKS ouvert ou non, volume monté ou non, chaque bind actif ou non) pour vérifier avant de faire confiance au vault. Les trois scripts sont rejouables sans risque : ils sautent toute étape déjà faite plutôt que d'échouer. Aucun des trois ne crée le conteneur lui-même — c'est le rôle, distinct et à usage unique, de `vault-create.sh`.

---

## Section utilisateur

### Description

Trois façades sur le même coffre LUKS (`~/vault.img`, mapper `vault_prof`, monté sur `~/Vault`) :

- **`vault-open.sh`** — ouvre LUKS si nécessaire, monte le volume, pose les bind mounts des profils navigateur. Interactif : demande la passphrase LUKS si le volume n'est pas déjà ouvert.
- **`vault-close.sh`** — ferme les navigateurs concernés, démonte les binds puis le volume, referme LUKS. Ne demande rien.
- **`vault-status.sh`** — lecture seule : affiche l'état de LUKS, du volume et de chaque bind, sans rien monter ni démonter.

Ne pas confondre avec [`vault-create.sh`](../.local/bin/vault-create.sh), qui crée le conteneur (une seule fois par machine) — voir [vault-create.md](vault-create.md).

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `sudo` | Ouverture/fermeture LUKS, montage, chown | `sudo -v` |
| `cryptsetup` | Ouverture/fermeture du conteneur LUKS | `cryptsetup --version` |
| `mount` / `umount` / `mountpoint` (util-linux) | Montage du volume et des binds | `mount --version` |
| `findmnt` (util-linux) | Lecture de la source réelle d'un montage | `findmnt --version` |
| `pkill` (procps) | Fermeture des navigateurs avant démontage (`vault-close.sh`) | `pkill --version` |
| conteneur existant | `~/vault.img`, créé par `vault-create.sh` | `[[ -f ~/vault.img ]]` |

`vault-status.sh` ne fait aucun appel `sudo` : il ne fait que lire l'état (`/dev/mapper`, `mountpoint`, `findmnt`), sans rien modifier.

### Syntaxe

```bash
vault-open.sh
vault-close.sh
vault-status.sh
```

Aucune option, aucun argument : les trois scripts s'utilisent tels quels.

### Exemples d'utilisation

```bash
# Ouverture (premier lancement, LUKS pas encore ouvert)
vault-open.sh
```

```
Enter passphrase for /home/jpd/vault.img:    (prompt natif de cryptsetup, non traduit)
Bind OK: /home/jpd/Vault/browser/vivaldi-prof -> /home/jpd/.config/vivaldi
Bind OK: /home/jpd/Vault/browser/brave-prof -> /home/jpd/.config/BraveSoftware/Brave-Browser
Bind OK: /home/jpd/Vault/browser/firefox/mozilla-firefox -> /home/jpd/snap/firefox/common/.mozilla/firefox
Bind OK: /home/jpd/Vault/browser/firefox/cache-firefox -> /home/jpd/snap/firefox/common/.cache/mozilla/firefox
OK: Vault ouvert, monté sur /home/jpd/Vault, binds en place.
```

```bash
# Vérifier l'état avant de faire confiance au vault
vault-status.sh
```

```
vault-status
------------------------------------------------------------
LUKS : OUVERT  (/dev/mapper/vault_prof)
Vault : MONTE  (/home/jpd/Vault)
/dev/mapper/vault_prof ext4 rw,relatime
------------------------------------------------------------
Binds :
------------------------------------------------------------
- /home/jpd/.config/vivaldi : MONTE (source -> /dev/mapper/vault_prof[/browser/vivaldi-prof])
- /home/jpd/.config/BraveSoftware/Brave-Browser : DEMONTE (attendu -> /home/jpd/Vault/browser/brave-prof)
------------------------------------------------------------
```

Cette sortie ne mentionne jamais Firefox : `vault-status.sh` ne le vérifie pas (voir *Notes de maintenance*).

```bash
# Fermeture en fin de cours
vault-close.sh
```

```
Fermeture des navigateurs...
Démontage des binds...
Bind démonté: /home/jpd/snap/firefox/common/.cache/mozilla/firefox
Bind démonté: /home/jpd/snap/firefox/common/.mozilla/firefox
Bind démonté: /home/jpd/.config/BraveSoftware/Brave-Browser
Bind démonté: /home/jpd/.config/vivaldi
Démontage du Vault...
Vault démonté: /home/jpd/Vault
Fermeture de LUKS...
LUKS fermé: vault_prof
OK: Vault fermé.
```

Les binds sont démontés dans l'ordre inverse de leur déclaration (Firefox cache d'abord, Vivaldi en dernier).

### Codes de retour

| Script | Code | Signification |
| ------ | ---- | ------------- |
| `vault-open.sh` | 0 | Vault ouvert, monté, binds en place (ou déjà tous actifs) |
| `vault-open.sh` | 1 | `~/vault.img` introuvable, ou échec cryptsetup/mount (`set -e`) |
| `vault-close.sh` | 0 | Toujours — y compris si un démontage a réellement échoué (voir *Notes de maintenance*) |
| `vault-status.sh` | 0 | Toujours — script purement diagnostique, aucun `exit` explicite |

---

## Section développeur

### Architecture interne

Les trois scripts sont linéaires (pas de `main()`, contrairement à `vault-create.sh` — voir *Notes de maintenance*).

**`vault-open.sh`**

1. Vérifie que `~/vault.img` existe (`die` sinon), crée `~/Vault` si absent.
2. Ouvre LUKS (`sudo cryptsetup open`, interactif) si `/dev/mapper/vault_prof` n'existe pas encore.
3. Monte le volume sur `~/Vault` et corrige la propriété (`chown -R`) si pas déjà monté.
4. Pour chaque paire du tableau `BINDS` : crée les deux répertoires (source dans le vault, cible dans `$HOME`), puis bind-mount si la cible n'est pas déjà un point de montage.

**`vault-close.sh`**

1. Tue les process navigateurs connus (`PROCS`), en ignorant l'absence de process.
2. Démonte chaque cible de `BIND_TARGETS`, en ordre inverse de déclaration, en ignorant les cibles absentes ou déjà démontées.
3. Démonte `~/Vault` s'il est monté.
4. Ferme le mapper LUKS `vault_prof` s'il existe.

**`vault-status.sh`**

1. Affiche si `/dev/mapper/vault_prof` existe (LUKS ouvert/fermé).
2. Affiche si `~/Vault` est monté, et sa ligne `findmnt` (source, type, options) si oui.
3. Pour chaque paire de son propre tableau `BINDS` (2 entrées seulement, voir *Notes de maintenance*) : affiche si la cible est montée, et sa source réelle via `findmnt`.

### Détail des choix techniques

**Ordre miroir strict entre ouverture et fermeture.** LUKS → volume → binds à l'ouverture ; binds → volume → LUKS à la fermeture. Cet ordre n'est pas arbitraire : les sources des binds vivent *dans* `~/Vault` (ex. `~/Vault/browser/vivaldi-prof`), donc démonter `~/Vault` avant ses binds échouerait avec *target is busy* (le point de montage serait encore référencé). `vault-close.sh` respecte cet ordre en démontant `BIND_TARGETS` en premier.

**`vault-open.sh` échoue vite, `vault-close.sh` n'échoue (presque) jamais.** Les deux tournent sous `set -euo pipefail`, mais `vault-close.sh` neutralise systématiquement l'échec de chaque commande sensible (`sudo umount ... 2>/dev/null || true`, `sudo cryptsetup close ... || true`) — un choix délibéré pour que la fermeture aille au bout même si une étape est déjà faite (LUKS déjà fermé, bind déjà démonté). L'effet de bord : le message qui suit (`echo "Bind démonté: $dst"`) s'affiche **sans vérifier** que la commande a réussi. Un démontage réellement en échec (ex. un process qui tient encore un fichier ouvert dans le bind, malgré le `pkill` en tête de script) est donc rapporté comme réussi, et le script continue — jusqu'à `OK: Vault fermé.` en toute confiance, potentiellement à tort. Voir *Notes de maintenance*.

**`vault-status.sh` ne modifie jamais rien.** Aucun `sudo`, aucune commande d'écriture : uniquement des tests (`[[ -e ]]`, `mountpoint -q`) et des lectures (`findmnt`). C'est le seul des trois qu'on peut lancer sans réfléchir, y compris pour vérifier l'état avant de faire confiance à un `OK` de `vault-close.sh`.

**`mkdir -p` des deux côtés du bind, dans `vault-open.sh`.** Au tout premier lancement, ni la source (`~/Vault/browser/...`) ni la cible (`~/.config/...`) n'existent forcément. Créer les deux avant le `mount --bind` rend le premier lancement et les suivants identiques, sans cas particulier pour « première fois ».

### Dépendances externes

| Binaire | Fourni par | Fonctionnalité qui l'impose |
| ------- | ---------- | ---------------------------- |
| `cryptsetup` | paquet `cryptsetup` | `open` / `close` du conteneur LUKS |
| `mount`, `umount`, `mountpoint` | util-linux | montage du volume et des binds |
| `findmnt` | util-linux | lecture de la source réelle d'un montage (`vault-status.sh`) |
| `pkill` | procps | fermeture des navigateurs avant démontage (`vault-close.sh`) |
| `bash` | — | here-string (`<<<`) pour parser les paires `BINDS`, `[[ ]]` |

### Tier sudo appliqué

**Tier 2** (mix opérations utilisateur + système) pour `vault-open.sh` et `vault-close.sh` : `cryptsetup`, `mount`/`umount`, `chown` nécessitent root ; la lecture du tableau `BINDS` et les `mkdir` sont des opérations utilisateur. Contrairement à `vault-create.sh`, aucun des deux ne fait de `sudo -v` en préchauffage : le mot de passe peut être redemandé plusieurs fois dans la même exécution. Mineur vu le nombre d'appels `sudo` par script (1 à 2 en pratique), mais à garder en tête si la liste des binds grandit.

`vault-status.sh` n'est **pas** Tier 2 : aucun appel `sudo`, donc rien à préchauffer.

### Points d'extension

**Ajouter un navigateur au vault** — toucher les trois scripts à la fois, sous peine de répéter l'écart déjà présent avec Firefox dans `vault-status.sh` (voir *Notes de maintenance*) :

```bash
# vault-open.sh (BINDS, source|cible) et vault-close.sh (BIND_TARGETS, cible seule)
"$MNT/browser/chrome-prof|$HOME/.config/google-chrome"
# + PROCS dans vault-close.sh : chrome
# + BINDS dans vault-status.sh (actuellement en retard sur les deux autres)
```

**Rendre `vault-close.sh` honnête sur ses échecs** — remplacer chaque `|| true` par un test explicite et un compteur, pour que `OK: Vault fermé.` ne s'affiche que si tout a réellement réussi (et que le code de retour reflète un échec partiel) :

```bash
if sudo umount "$dst" 2>/dev/null; then
  echo "Bind démonté: $dst"
else
  echo "ÉCHEC démontage: $dst" >&2
  had_error=1
fi
```

**Sortie machine-lisible pour `vault-status.sh`** — un flag `--quiet` (code de retour non nul si quelque chose manque) permettrait de l'utiliser dans un script de vérification automatique plutôt qu'à l'œil.

### Notes de maintenance

- **`vault-status.sh` ne connaît que 2 des 4 binds réels.** Son tableau `BINDS` ne liste que Vivaldi et Brave ; les deux entrées Firefox présentes dans `vault-open.sh` (`BINDS`) et `vault-close.sh` (`BIND_TARGETS`) en sont absentes. Concrètement : après un `vault-open.sh` qui a bien monté les quatre binds, `vault-status.sh` n'en rapporte que deux — un bind Firefox démonté (ou jamais monté) passe inaperçu. À corriger en alignant son tableau `BINDS` sur celui de `vault-open.sh`.
- **`OK: Vault fermé.` n'est pas une garantie.** Voir *Détail des choix techniques* : chaque étape de `vault-close.sh` peut échouer silencieusement (`|| true`). En cas de doute réel (ex. après avoir dû forcer la fermeture d'un navigateur récalcitrant), le réflexe est de lancer `vault-status.sh` juste après, pas de se fier au seul message final.
- **Ni `main()`, ni les fonctions de log canoniques (`[INFO]`/`[OK]`/`[ATTENTION]`/`[ERREUR]`).** Les trois scripts sont antérieurs à ces conventions (cf. CLAUDE.md, *Shell Script Structure* et *Shell Script Color and Logging Conventions*) : ils utilisent `echo`/`die` bruts et un enchaînement linéaire plutôt qu'un point d'entrée `main()`. `vault-create.sh` suit la convention actuelle ; aligner les trois autres dessus (ou l'inverse) est un choix à faire consciemment, pas un oubli à corriger en douce.
- **`BINDS` (source|cible) vit dans `vault-open.sh` ; `vault-create.sh` en dépend sans le dupliquer** — voir [vault-create.md](vault-create.md), *Notes de maintenance*.
