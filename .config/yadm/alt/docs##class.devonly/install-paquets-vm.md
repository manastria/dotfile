# `install-paquets-vm.py` — Paquets d'une VM pédagogique décrits par un profil TOML

> Script : [`.local/bin/install-paquets-vm.py`](../.local/bin/install-paquets-vm.py)
> Profil d'exemple : [`.config/install-paquets-vm/paquets.toml.sample`](../.config/install-paquets-vm/paquets.toml.sample)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install-paquets-vm.py` prépare une VM pédagogique à partir d'un **profil TOML** : un fichier par objectif de TP, qui décrit des groupes de paquets soumis à des conditions (distribution, version, bureau Kubuntu, Xubuntu ou Lubuntu). Le script retient les groupes qui correspondent à la machine, met le système à jour, retire puis installe les paquets et nettoie les dépendances inutiles, en demandant `sudo` au besoin. Il ne remplace pas `install-paquets.sh` : celui-ci garde sa liste écrite dans le script et reste l'outil des machines qui ne sont pas des VM pédagogiques. Sans option, il charge `paquets.toml`, cherché d'abord dans le répertoire courant, puis dans `~/.config/install-paquets-vm/`, enfin dans `/etc/install-paquets-vm/`. Au quotidien : `--profil tp-reseau` pour choisir un autre profil, `--dry-run` pour voir les groupes retenus et l'état des paquets sans rien modifier, `--os ubuntu:26.04 --bureau kubuntu` pour vérifier ce qu'un profil donnerait sur une autre machine.

---

## Section utilisateur

### Description

`install-paquets-vm.py` installe les paquets d'une VM à partir d'un fichier de données plutôt que d'une liste écrite dans le code. Chaque TP peut ainsi avoir son profil (`tp-reseau.toml`, `tp-docker.toml`…) sans toucher au script.

| Critère | [`install-paquets.sh`](../.local/bin/install-paquets.sh) | `install-paquets-vm.py` |
| ------- | -------------------- | ----------------------- |
| Liste des paquets | tableaux bash dans le script | profil TOML choisi à l'exécution |
| Variantes gérées | distribution et version | distribution, version **et bureau** |
| Plusieurs listes | non | un profil par objectif pédagogique |
| Dépendances | bash | Python ≥ 3.11 (bibliothèque standard seule) |
| Usage visé | machines de travail, Debian en console | VM pédagogiques Kubuntu / Xubuntu / Lubuntu |

Le déroulement reprend celui d'`install-paquets.sh` : `apt-get update` et `upgrade`, retrait des paquets listés dans `retirer`, installation des paquets manquants disponibles dans les dépôts (les autres sont signalés et ignorés), puis `autoremove`.

#### Choix du profil

`--config CHEMIN` charge un fichier précis. Sinon, le script cherche `NOM.toml` (`NOM` vaut `paquets`, ou la valeur de `--profil`) et **s'arrête au premier fichier trouvé** ; les profils ne sont jamais fusionnés.

| Priorité | Emplacement | Usage typique |
| -------- | ----------- | ------------- |
| 1 | `./NOM.toml` (répertoire courant) | profil fourni avec le TP, sur une clé USB ou dans le dépôt du TP |
| 2 | `~/.config/install-paquets-vm/NOM.toml` | profils personnels de l'enseignant, déployés avec les dotfiles |
| 3 | `/etc/install-paquets-vm/NOM.toml` | profil installé sur la VM modèle, commun à tous les comptes |

Lancé avec `sudo`, le script consulte le `~/.config` de la personne qui a tapé la commande, pas celui de root.

#### Format du profil

```toml
description = "TP réseau : outils de diagnostic"

[[groupe]]
nom = "communs"
paquets = ["curl", "git", "tmux"]

[[groupe]]
nom = "kubuntu"
si = { bureau = "kubuntu" }
paquets = ["yakuake"]

[[groupe]]
nom = "debian-12"
si = { os = "debian", version_max = "12" }
paquets = ["unrar", "haveged"]

[[groupe]]
nom = "obsoletes"
retirer = ["squid-deb-proxy-client"]
```

Un groupe est retenu quand **toutes** ses conditions `si` sont vraies ; sans `si`, il l'est toujours.

| Condition | Valeur | Le groupe est retenu si… |
| --------- | ------ | ------------------------ |
| `os` | texte ou liste | l'`ID` de `/etc/os-release` (`ubuntu`, `debian`) figure dans la liste |
| `version_min` | texte : `"24.04"`, `"12"` | la version est supérieure ou égale à la borne |
| `version_max` | texte | la version est inférieure ou égale à la borne |
| `bureau` | texte ou liste | l'un des bureaux détectés figure dans la liste |

Une borne de version ne compare que les composants qu'elle donne : `version_max = "24"` couvre 24.04 **et** 24.10, alors que `"24.04"` exclut 24.10. Les versions s'écrivent **entre guillemets** : sans guillemets, TOML lit `24.10` comme le nombre 24.1, et le script refuse le profil.

Le bureau est déduit du métapaquet installé :

| Bureau | Métapaquet recherché |
| ------ | -------------------- |
| `kubuntu` | `kubuntu-desktop*` |
| `xubuntu` | `xubuntu-desktop*` |
| `lubuntu` | `lubuntu-desktop*` |
| `ubuntu` | `ubuntu-desktop*` (GNOME) |
| `aucun` | aucun des précédents (serveur, console) |

Quand un paquet change de nom selon la distribution, les groupes gardent le nom canonique et une table `renommages` donne le nom réel. La clé la plus précise l'emporte (`"ubuntu:24.04"`, puis `"ubuntu:24"`, puis `"ubuntu"`) :

```toml
[renommages.netcat]
"ubuntu:24.04" = "netcat-openbsd"
"debian"       = "netcat-traditional"
```

Le modèle commenté [`paquets.toml.sample`](../.config/install-paquets-vm/paquets.toml.sample) reprend la liste d'`install-paquets.sh` et l'étend aux trois bureaux. Déployé dans `~/.config/install-paquets-vm/`, il n'est jamais chargé tel quel à cause de son suffixe `.sample` : le copier sous le nom `paquets.toml` ou `NOM.toml`.

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `python3` ≥ 3.11 | Interpréteur ; module `tomllib` pour lire le profil | `python3 --version` |
| `dpkg-query` | État des paquets, détection du bureau | `dpkg-query --version` |
| `apt-get`, `apt-cache` | Mise à jour, installation, disponibilité dans les dépôts | `apt-get --version` |
| `sudo` | Élévation des droits (sauf `--dry-run` et `--os`) | `sudo -V` |

Aucun module Python à installer. Le `python3` exécuté en root est celui que `sudo` trouve dans son `secure_path`, soit `/usr/bin/python3` : Debian 12 et Ubuntu 24.04 conviennent, Ubuntu 22.04 (Python 3.10) non.

---

### Syntaxe

```text
install-paquets-vm.py [-p NOM | -c CHEMIN] [-n] [--os ID:VERSION] [--bureau NOM] [-h]
```

| Option | Argument | Défaut | Description |
| ------ | -------- | ------ | ----------- |
| `-p`, `--profil` | nom | `paquets` | Profil à chercher dans les trois emplacements ; un suffixe `.toml` est toléré |
| `-c`, `--config` | chemin | — | Fichier TOML chargé tel quel, sans recherche ; exclusif de `--profil` |
| `-n`, `--dry-run` | — | désactivé | Affiche profil, OS, bureau, groupes retenus et état de chaque paquet ; ne modifie rien, pas de `sudo` |
| `--os` | `ID:VERSION` | OS détecté | Simule une autre distribution (`ubuntu:26.04`, `debian:12`) ; liste les paquets sans leur état ; implique `--dry-run` |
| `--bureau` | nom | détecté (`aucun` avec `--os`) | Force le bureau : `kubuntu`, `xubuntu`, `lubuntu`, `ubuntu` ou `aucun` |
| `-h`, `--help` | — | — | Affiche l'en-tête manpage du script |

---

### Exemples d'utilisation

```bash
# Vérifier ce que le profil par défaut ferait sur cette VM, sans rien modifier
install-paquets-vm.py --dry-run

# Préparer la VM pour le TP réseau (profil tp-reseau.toml, cherché par priorité)
install-paquets-vm.py --profil tp-reseau

# Utiliser un profil apporté sur une clé USB
install-paquets-vm.py --config /media/usb/tp-docker.toml

# Contrôler un profil pour une VM Kubuntu 26.04 depuis un autre poste
install-paquets-vm.py --profil tp-reseau --os ubuntu:26.04 --bureau kubuntu

# Le métapaquet du bureau a disparu : forcer la détection
install-paquets-vm.py --bureau xubuntu
```

**Exemple de sortie** (simulation avec le profil d'exemple) :

```text
=== Installation des paquets de la VM ===

[INFO]      Profil : /home/user/.config/install-paquets-vm/paquets.toml.sample (--config)
[INFO]      Description : Exemple : outils console communs et compléments par bureau
[ATTENTION] OS simulé (--os) : ubuntu 26.04, bureau kubuntu — ne décrit pas cette machine.

Groupes du profil ([x] = retenu) :
  [x] communs     toujours
  [x] obsoletes   toujours
  [ ] debian-12   os = debian, version ≤ 12
  [x] virtualbox  toujours
  [x] graphiques  bureau = kubuntu ou xubuntu ou lubuntu ou ubuntu
  [x] kubuntu     bureau = kubuntu
  [ ] xubuntu     bureau = xubuntu
  [ ] lubuntu     bureau = lubuntu

Paquets à installer (45) :
  - aptitude
  - bash-completion
  …
  - gvfs-backends
  - terminator
  - yakuake

Paquets à retirer (1) :
  - squid-deb-proxy-client
```

Avec `--dry-run` sur la machine réelle, l'OS et le bureau sont détectés et chaque paquet porte son état : `installé`, `à installer`, ou `introuvable` s'il n'existe pas dans les dépôts.

```text
[INFO]      OS détecté : Ubuntu 24.04.4 LTS (id=ubuntu, version=24.04)
[INFO]      Bureau détecté : aucun
[ATTENTION] Mode --dry-run : aucune modification ne sera effectuée.
…
Paquets à installer (42) :
  - aptitude : installé
  - bash-completion : installé
…
  - micro : à installer
…
  - sshfs : à installer
…
Paquets à retirer (1) :
  - squid-deb-proxy-client : absent
```

Profil introuvable : le script liste les emplacements consultés, sans demander de mot de passe.

```text
[ERREUR]    Profil « tp-reseau » introuvable. Emplacements consultés, par priorité :
    /home/user/tp-reseau.toml
    /home/user/.config/install-paquets-vm/tp-reseau.toml
    /etc/install-paquets-vm/tp-reseau.toml
Modèle commenté : ~/.config/install-paquets-vm/paquets.toml.sample
```

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Terminé avec succès, ou simulation (`--dry-run`, `--os`) |
| `1` | Erreur d'exécution : Python < 3.11, `sudo` ou `dpkg-query` absent, `/etc/os-release` illisible, profil inaccessible, échec d'`apt-get` |
| `2` | Erreur d'usage : option inconnue ou sans valeur, `--os` ou `--bureau` invalide, profil introuvable |
| `3` | Profil invalide : syntaxe TOML, clé inconnue, valeur incorrecte, ou paquet à la fois à installer et à retirer sur cette machine |
| `130` | Interruption (Ctrl+C) |

---

## Section développeur

### Architecture interne

```text
main
├─ parse_args            options ; valide --os et --bureau ; --os active --dry-run
├─ trouver_config        --config, sinon ./ → ~/.config (home_appelant) → /etc
├─ charger_profil        tomllib puis valider_profil : clés, types, noms (code 3)
├─ elever_privileges     sudo python3 <script> <mêmes arguments>, sauf --dry-run
├─ construire_contexte   os-release et bureau (dpkg-query), ou contexte simulé --os
├─ construire_plan       conditions_remplies, resoudre_nom, contrôle des conflits
├─ afficher_groupes
└─ afficher_paquets      (--dry-run)
   ou executer           update/upgrade → remove → install → autoremove
```

Le processus relancé par `sudo` refait tout depuis `parse_args` : la recherche du profil tombe sur le même fichier, puisque `sudo` conserve le répertoire courant et que `home_appelant()` retrouve le `~` de l'appelant.

---

### Détail des choix techniques

**TOML plutôt que YAML**
`tomllib` fait partie de la bibliothèque standard depuis Python 3.11. PyYAML exigerait d'installer `python3-yaml` avant de pouvoir lancer le script chargé justement d'installer les paquets.

**Profil cherché et validé avant `sudo`**
Une faute de frappe dans `--profil` ou dans le TOML est signalée sans demander de mot de passe. Les messages ne sont affichés qu'après l'élévation, sinon ils apparaîtraient deux fois.

**`sudo python3` plutôt que `sys.executable`**
C'est l'équivalent du Tier 1 de CLAUDE.md : l'interpréteur exécuté en root doit venir du `secure_path` de `sudo`, pas de l'environnement de l'utilisateur (pyenv, venv).

**Clés inconnues refusées**
Une clé mal orthographiée serait sinon ignorée en silence : `versoin_max` ferait appliquer le groupe partout, `paquet` le laisserait vide.

**Noms de paquets filtrés**
Les noms doivent respecter la règle de la Debian Policy (`[a-z0-9][a-z0-9+.-]+`). Un nom ne peut donc pas commencer par `-` et un profil ne peut pas glisser d'option à `apt-get` exécuté en root, par exemple `-oAPT::Update::Pre-Invoke::=commande`. C'est d'autant plus utile que le répertoire courant est consulté en premier.

**Versions : guillemets obligatoires, bornes par préfixe**
Un flottant TOML (`24.10`) a déjà perdu l'information (24.1) quand le script le lit : il est refusé. `true` est refusé aussi, car `bool` hérite d'`int` en Python. La comparaison de tuples tronqués (`(24, 10)[:1] <= (24,)`) donne le sens attendu à `version_max = "24"`.

**Bureau déduit du métapaquet**
`/etc/os-release` renvoie `ID=ubuntu` pour les trois variantes, et `$XDG_CURRENT_DESKTOP` n'existe ni sous `sudo` ni en SSH. Le motif `kubuntu-desktop*` couvre les variantes (`-minimal`…) sans les énumérer. Si plusieurs bureaux sont installés, ils sont tous retenus et un groupe s'applique dès que l'un d'eux figure dans sa condition.

**`dpkg-query` en un seul appel**
Il sort en code 1 dès qu'un nom ne correspond à rien, mais liste quand même les autres : seule la sortie standard est lue. La deuxième lettre de `${db:Status-Abbrev}` donne l'état réel : `ii` installé, `rc` supprimé avec sa configuration conservée.

**`apt-cache show` lu ligne à ligne**
Appelé avec plusieurs noms, `apt-cache show` renvoie 0 même si certains sont inconnus. Pour un paquet purement virtuel (`mail-transport-agent`), il ne produit aucune fiche et renvoie 0 aussi, alors qu'`apt-get install` échoue dès que ce paquet a plusieurs fournisseurs. Le script relève donc les lignes `Package:` : un paquet virtuel est signalé « introuvable » au lieu de faire échouer toute l'installation. `install-paquets.sh` ne voit pas ce cas, puisqu'il se fie au code de retour.

**`--os` : ni état ni détection locale**
`dpkg` et `apt-cache` décriraient la machine locale et non la cible simulée. Le bureau vaut donc `aucun` sauf `--bureau` explicite, et l'état des paquets n'est pas affiché.

**Conflits vérifiés après la sélection**
Un contrôle sur tout le profil interdirait des cas légitimes, comme installer `netcat-openbsd` sous Ubuntu et le retirer sous Debian. Seuls les groupes retenus pour la machine sont comparés, après renommage.

**`flush=True` sur chaque message**
Hors terminal, la sortie standard de Python est tamponnée par blocs : sans `flush`, les messages du script arriveraient après la sortie d'`apt-get` dans un fichier journal.

---

### Dépendances externes

```text
python3 ≥ 3.11   →  tomllib ; platform.freedesktop_os_release (≥ 3.10)
dpkg             →  dpkg-query --show --showformat, champ ${db:Status-Abbrev}
apt              →  apt-get update/upgrade/remove/install/autoremove,
                    apt-cache show --no-all-versions
sudo             →  élévation, secure_path pour résoudre python3
```

Le script ne recourt à aucune syntaxe récente (`match`…) et reporte l'import de `tomllib` : lancé avec Python 3.9 ou 3.10, il affiche un message clair (code 1) au lieu d'une trace d'erreur.

---

### Points d'extension

**Reconnaître un bureau Debian**
Le dictionnaire `BUREAUX` associe un nom de bureau à des motifs de métapaquets. Pour qu'une condition `bureau = "kubuntu"` couvre aussi Debian KDE :

```python
BUREAUX = {
    "kubuntu": ["kubuntu-desktop*", "task-kde-desktop"],
    ...
}
```

**Nouvelle condition : l'hyperviseur**
Pour installer les additions invité selon la plateforme (VirtualBox, KVM, VMware), ajouter la clé dans `CLES_SI`, la lire dans `valider_conditions()` et la tester dans `conditions_remplies()` :

```python
# construire_contexte() : ["oracle"] pour VirtualBox, ["kvm"], ["vmware"], ["none"]
virt = subprocess.run(["systemd-detect-virt"], capture_output=True, text=True).stdout.split()

# conditions_remplies()
if cond.virt is not None and ctx.virt.isdisjoint(cond.virt):
    return False
```

**Lister les profils disponibles**
Une option `--liste` peut parcourir les trois emplacements et marquer les profils masqués par un homonyme plus prioritaire :

```python
vus = set()
for dossier in (Path.cwd(), home_appelant() / ".config" / APP, Path("/etc") / APP):
    for fichier in sorted(dossier.glob("*.toml")):
        masque = fichier.stem in vus
        vus.add(fichier.stem)
        afficher(f"  {fichier.stem:<20} {fichier}{' (masqué)' if masque else ''}")
```

---

### Notes de maintenance

- **Répertoire courant prioritaire** : un `paquets.toml` déposé par un tiers dans le répertoire courant serait appliqué en root. Le filtrage des noms bloque l'injection d'options, pas un `retirer = ["openssh-server"]`. Sur une machine partagée, lancer le script depuis un répertoire de confiance, ou passer `--config`.
- **`python3` de root** : `--dry-run` tourne avec l'interpréteur de l'utilisateur (pyenv 3.12, par exemple), l'installation avec `/usr/bin/python3`. Si ce dernier est antérieur à 3.11, l'échec n'apparaît qu'après le mot de passe, avec un message explicite.
- **Cache apt en `--dry-run`** : aucune commande `apt-get update` n'est lancée, donc les états « à installer » et « introuvable » reflètent la dernière mise à jour du cache.
- **Métapaquet disparu** : désinstaller certaines applications fournies par défaut peut emporter le métapaquet du bureau, qui est alors détecté comme `aucun`. Passer `--bureau`.
- **Paquets virtuels** : ils sont signalés « introuvable ». Mettre le nom du paquet concret dans le profil.
- **Deux listes indépendantes** : le profil d'exemple a été créé à partir d'`install-paquets.sh`, mais les deux listes évoluent séparément.
- **Tester sans risque** : placer un faux `sudo` en tête du `PATH` (un script qui affiche ses arguments et sort en erreur). Sans `--dry-run`, le script s'arrête sur ce faux `sudo` et `apt-get` n'est jamais lancé, ce qui permet aussi de vérifier les arguments transmis à la relance.
