# firefox-snap-vers-apt.sh

> Script : [`.local/bin/firefox-snap-vers-apt.sh`](../.local/bin/firefox-snap-vers-apt.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`firefox-snap-vers-apt.sh` bascule Firefox du paquet Snap vers le `.deb` officiel publié par Mozilla sur `packages.mozilla.org`. La raison : la sandbox du Snap bloque la messagerie native que l'extension KeePassXC-Browser utilise pour parler à KeePassXC, alors que le paquet `.deb` n'a pas cette limitation. Le script ajoute le dépôt APT de Mozilla (clé de signature vérifiée par empreinte), installe le paquet `firefox`, puis retire le Snap s'il était présent. Il ne fait **pas** de sauvegarde ni de reprise des profils Firefox : chaque utilisateur repart avec un profil vide sous `~/.mozilla/firefox/`. Il se relance automatiquement en root si besoin (accès à `/etc/apt` requis, pas besoin de taper `sudo` soi-même) et peut être relancé sans risque sur un poste déjà migré.

---

## Section utilisateur

### Description

Fait basculer un poste Debian/Ubuntu où Firefox est installé en Snap vers le paquet `.deb` publié directement par Mozilla, en configurant le dépôt APT officiel (clé signée, épinglage `Pin-Priority: 1000`) puis en installant `firefox` par ce canal.

Il diffère de [`switch-to-networkmanager.sh`](../.local/bin/switch-to-networkmanager.sh) (bascule d'une brique système différente, netplan/systemd-networkd) : ici, la bascule concerne uniquement le paquet Firefox et son mode de confinement, pas la pile réseau.

Le script signale aussi, sans agir dessus, le cas où KeePassXC lui-même est installé en Snap sur le poste — cause possible d'instabilité résiduelle de la messagerie native même après la bascule de Firefox.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `sudo` | le script se relance lui-même en root si lancé en utilisateur normal | `sudo -v` |
| `wget` | téléchargement de la clé de signature Mozilla | `wget --version` |
| `gpg` | affichage de l'empreinte de la clé pour vérification | `gpg --version` |
| `apt` | ajout du dépôt, installation du paquet | `apt --version` |
| `snap` | détection et retrait du Snap Firefox (si présent) | `snap version` |
| accès réseau | `packages.mozilla.org` (clé + dépôt) | `wget -q --spider https://packages.mozilla.org` |

### Syntaxe

```bash
firefox-snap-vers-apt.sh
```

Se relance automatiquement avec `sudo` s'il n'est pas déjà lancé en root (Tier 1, sans `-E` : l'environnement utilisateur n'est pas propagé). Le script n'accepte aucune option ; il n'implémente pas d'aide `-h`/`--help` (déviation par rapport à la convention du dépôt, voir *Notes de maintenance*).

### Exemples d'utilisation

```bash
# Bascule sur le poste courant (demande le mot de passe sudo si besoin)
.local/bin/firefox-snap-vers-apt.sh

# Équivalent explicite
sudo .local/bin/firefox-snap-vers-apt.sh
```

Sortie type (Firefox en Snap au départ) :

```
== État actuel du poste ==
- Firefox est installé en Snap : bascule vers le paquet .deb Mozilla.

== Ajout du dépôt APT officiel de Mozilla ==
Empreinte attendue : 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
Empreinte obtenue  : 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3

== Installation du paquet .deb ==
...
== Retrait de l'ancien Firefox Snap ==
firefox supprimé

== Terminé ==
Dans KeePassXC : Outils > Paramètres > Intégration navigateur,
décocher puis recocher la case Firefox pour régénérer le fichier de
messagerie native, puis relancer la connexion depuis l'extension.
```

Relancé sur un poste déjà migré, le script saute simplement l'étape de retrait du Snap (`FIREFOX_SNAP=0`) et réinstalle/confirme le paquet `.deb`.

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Bascule terminée (ou déjà à jour) |
| *(autre)* | `set -euo pipefail` propage tel quel le code de sortie de la première commande en échec (`sudo`, `wget`, `gpg`, `apt`, `snap`) — pas de code dédié par étape |

---

## Section développeur

### Architecture interne

Script linéaire, sans `main()` ni fonctions : les étapes s'enchaînent au fil du fichier sous `set -euo pipefail`.

1. Auto-relance en root (Tier 1) : `[ "$(id -u)" -ne 0 ] && exec sudo "$(readlink -f "$0")" "$@"`.
2. État du poste : `snap list firefox` (fixe `FIREFOX_SNAP`), `snap list keepassxc` (avertissement informatif seulement).
3. Ajout du dépôt Mozilla : `install -d` du dossier de clés, téléchargement de la clé (`wget | tee`), vérification de son empreinte via `gpg --import-show`, écriture de `sources.list.d/mozilla.list` et du pin `preferences.d/mozilla` (priorité 1000).
4. `apt update` puis `apt install -y --allow-downgrades firefox`.
5. Si `FIREFOX_SNAP=1` : `snap remove --purge firefox`.
6. Message final : procédure de reconnexion de la messagerie native KeePassXC.

### Détail des choix techniques

**Auto-relance `sudo` sans `-E` (Tier 1).** Toutes les opérations du script sont système (`/etc/apt`, `apt`, `snap`) : il relance donc lui-même `sudo "$(readlink -f "$0")" "$@"` si non déjà lancé en root, plutôt que d'exiger `sudo` de l'utilisateur (motif explicitement interdit par la convention du dépôt : forcer `sudo bash …` oblige à connaître le chemin complet, `~/.local/bin` n'étant pas dans le `secure_path` de sudo). L'absence de `-E` est volontaire : `sudo -E` propagerait l'environnement utilisateur (`PATH`, `LD_PRELOAD`, etc.) au processus root, ce qui est évité ici.

**`Pin-Priority: 1000` sur `packages.mozilla.org`.** Sans épinglage fort, une mise à jour système ultérieure pourrait réinstaller la version Ubuntu de `firefox` (le paquet transitionnel vers le Snap) à la place du `.deb` Mozilla. La priorité 1000 dépasse le maximum qu'APT peut atteindre par un dépôt normal, ce qui force le choix du paquet Mozilla à chaque `apt upgrade`.

**`GNUPGHOME` jetable pour la vérification d'empreinte.** `gpg -n` (`--dry-run`, utilisé pour ne rien modifier au trousseau) refuse de **créer** son répertoire de configuration s'il n'existe pas encore — il échoue alors avec `Fatal: <homedir> : le répertoire n'existe pas.` C'est systématiquement le cas de `/root/.gnupg` au premier lancement du script via `sudo` (root n'a jamais utilisé `gpg` sur la machine). Le symptôme observé était trompeur : `gpg` n'affiche que la ligne `pub ...` avant de mourir, sans jamais imprimer l'empreinte ; combiné à `2>/dev/null` (qui masque le vrai message d'erreur) et à `set -o pipefail` + `set -e` (qui propagent le code d'échec de `gpg` à travers le pipe `| awk` puis à l'affectation `FINGERPRINT_OBTENUE=$(...)`), le script s'arrêtait juste après `== Ajout du dépôt APT officiel de Mozilla ==`, sans aucun message exploitable. Fix : un `GNUPGHOME` créé par `mktemp -d` (nettoyé par un `trap ... EXIT`) est passé explicitement via `--homedir`, indépendamment de tout état préexistant du compte root.

**`--allow-downgrades` sur `apt install`.** Le paquet `firefox` transitionnel d'Ubuntu (celui qui redirige vers le Snap) porte un epoch `1:` (ex. `1:1snap1-0ubuntu8`), qui le fait toujours l'emporter, en comparaison de versions dpkg, sur une vraie version Mozilla sans epoch (ex. `155.0.1~build1`) — quel que soit le pin. C'est le mécanisme volontaire par lequel Ubuntu pousse ses utilisateurs vers Snap. Sans `--allow-downgrades`, `apt install -y` refuse ce qu'il perçoit comme une rétrogradation, avec `Erreur : Des paquets ont été rétrogradés et -y a été employé sans --allow-downgrades.` — et ce, systématiquement, pour n'importe quel poste ciblé par ce script (puisque la cible même du script est un poste avec Firefox en Snap).

**Empreinte de clé codée en dur (`FINGERPRINT_ATTENDUE`).** Comparaison en clair plutôt que rejet automatique en cas de désaccord : un changement d'affichage `gpg` selon la version installée ne doit pas bloquer un poste à tort. En cas de non-correspondance, le script affiche un avertissement et laisse l'opérateur comparer les deux lignes à l'œil, plutôt que d'échouer — arbitrage documenté dans le code même (lignes 71-75).

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | ---------------------------- |
| `bash` | 4.x | `set -o pipefail` |
| `wget` | — | téléchargement de la clé de signature |
| `gpg` | 2.x (`import-options import-show`) | affichage de l'empreinte sans modifier de trousseau persistant |
| `apt`/`dpkg` | supportant `--allow-downgrades` | installation du paquet Mozilla malgré l'epoch du paquet Ubuntu |
| `snapd` | — | uniquement si Firefox et/ou KeePassXC sont installés en Snap |
| coreutils | — | `mktemp -d`, `install -d`, `tee` |

### Points d'extension

**Suivre un changement de clé de signature Mozilla** — si Mozilla renouvelle sa clé, mettre à jour la constante :

```bash
FINGERPRINT_ATTENDUE="<nouvelle empreinte>"
```

**Basculer aussi KeePassXC** — le script se contente aujourd'hui d'avertir si `keepassxc` est en Snap (lignes 36-43) ; un script frère `keepassxc-snap-vers-apt.sh` suivant la même structure (dépôt/`.deb` officiel KeePassXC) couvrirait le cas signalé.

### Notes de maintenance

- **Pas d'aide `-h`/`--help`.** Autre déviation de convention (le script n'a pas de bloc `while`-based parser) : `-h` serait aujourd'hui traité comme n'importe quel argument surnuméraire, silencieusement ignoré (le script n'utilise pas `$@`).
- **`--allow-downgrades` restera nécessaire tant qu'Ubuntu maintient l'epoch `1:` sur son paquet stub Snap.** Ce n'est pas un contournement ponctuel : c'est structurel au mécanisme par lequel Ubuntu privilégie le Snap, et cela concerne tout poste ciblé par ce script.
- **Profils Firefox non repris.** Volontaire (voir en-tête du script) : sans conséquence tant qu'un profil vide par utilisateur est de toute façon recréé à chaque séance sur les postes concernés ; à revoir si ce script est un jour utilisé sur un poste à profils persistants importants.
