# vault

> Script : [`.local/bin/vault`](../.local/bin/vault)
> Remplace : `vault-create.sh`, `vault-open.sh`, `vault-close.sh`, `vault-status.sh` (supprimés)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`vault` est la commande unique du coffre chiffré LUKS qui héberge les profils des navigateurs (Vivaldi, Brave, Firefox) : `vault open` le déverrouille et pose les bind mounts, `vault close` ferme les navigateurs puis démonte et referme tout, `vault status` affiche l'état sans rien modifier, et `vault create` fabrique le conteneur (une seule fois par machine). `vault clean` supprime les profils « hors coffre » que crée un navigateur lancé coffre fermé : c'est une **simulation** tant qu'on n'ajoute pas `--apply`, et il refuse d'agir si le coffre est ouvert, si un navigateur tourne ou si `~/vault.img` n'existe pas (les profils locaux sont alors les seuls exemplaires). Il ne touche jamais au contenu du coffre. Il ne migre pas non plus un profil existant dans le coffre : `create` masque simplement l'ancien profil.

---

## Section utilisateur

### Description

Le coffre est un conteneur LUKS (`~/vault.img`, mapper `vault_prof`) monté sur `~/Vault`. Les profils y vivent, et des **bind mounts** les rendent visibles là où les navigateurs les cherchent (`~/.config/vivaldi`, etc.). Quand le coffre est fermé, ces emplacements ne sont que des dossiers du disque local : un navigateur lancé à ce moment-là y crée un profil neuf, sans que rien ne soit cassé. Ce profil « hors coffre » est masqué dès la réouverture, mais il occupe de la place et contient des données personnelles. `vault clean` sert à les supprimer.

| Besoin | Commande |
| ------ | -------- |
| Début de cours : ouvrir le coffre | `vault open` |
| Fin de cours : tout fermer | `vault close` |
| Où en est-on ? Reste-t-il des données hors coffre ? | `vault status` |
| Supprimer les profils créés coffre fermé | `vault clean` (simulation), puis `vault clean --apply` |
| Première installation | `vault create [--size 5G]` |

Une seule commande, une seule configuration : les constantes et le tableau `BINDS` en tête du script.

**Sécurité de `vault clean`.** Le danger est de supprimer *à travers* un montage : si le coffre s'ouvre pendant la suppression, `rm -rf` descendrait dans le bind et viderait le coffre. Plusieurs protections indépendantes, dont chacune suffit à refuser :

- aucun chemin en argument : seules les cibles de `BINDS` (et les restes `.purge-*` d'un nettoyage interrompu) sont candidates ;
- `~/vault.img` doit exister : sans lui, aucun coffre sur cette machine, donc les dossiers locaux sont les seuls exemplaires ;
- LUKS fermé, `~/Vault` non monté, aucun navigateur lancé ;
- chaque candidat : vrai dossier (ni lien symbolique, ni composant symlink), strictement sous `$HOME`, hors de `~/Vault`, sans aucun montage dessus ni dessous (lu dans `/proc/self/mountinfo`) ; un seul candidat suspect arrête tout, sans suppression partielle ;
- **renommage avant suppression** : `mv` échoue (`EBUSY`) sur un point de montage, ce qui rend le test atomique avec l'action ; seule la copie renommée est supprimée, avec `rm --one-file-system`, après un second contrôle ;
- **verrou** partagé avec `open`, `close` et `create` : une ouverture lancée pendant le nettoyage attend sa fin ;
- simulation par défaut, puis confirmation à taper (`SUPPRIMER`) ; refus du root.

Les dossiers vides ne sont pas listés (ce ne sont pas des profils). Supprimer n'est pas effacer : sur ext4 ou SSD, les données peuvent rester récupérables.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `sudo` | `open`, `close`, `create` (cryptsetup, mount, chown) | `sudo -v` |
| `cryptsetup` | conteneur LUKS (installé par `create` si absent) | `cryptsetup --version` |
| `mount`, `umount`, `findmnt` (util-linux) | montage et lecture des montages | `findmnt --version` |
| `flock` (util-linux) | verrou entre opérations | `flock --version` |
| `pgrep`, `pkill` (procps) | détection et fermeture des navigateurs | `pgrep --version` |
| `fallocate`, `mkfs.ext4` | `create` uniquement | `mkfs.ext4 -V` |
| `realpath`, `du`, `find`, `mv`, `rm` (coreutils, findutils) | `clean` | `realpath --version` |
| `~/vault.img` | conteneur existant (`open`, `clean`) | `vault status` |

`status` et `clean` n'appellent jamais `sudo`.

### Syntaxe

```bash
vault create [--size TAILLE]
vault open
vault close
vault status
vault clean [--apply]
vault -h | --help
```

| Sous-commande / option | Défaut | Description |
| ---------------------- | ------ | ----------- |
| `create` | — | Crée le conteneur (fallocate, luksFormat, ext4), l'ouvre, pose les binds. Passphrase et mot de passe sudo saisis une seule fois, au début |
| `--size TAILLE` | `15G` | `create` : taille, syntaxe `fallocate` (`15G`, `500M`) |
| `open` | — | Ouvre LUKS (passphrase demandée), monte le coffre, pose les binds ; rejouable |
| `close` | — | Ferme les navigateurs, démonte binds, coffre, LUKS ; s'arrête sans faux succès si un démontage échoue |
| `status` | — | Lecture seule |
| `clean` | simulation | Liste les profils hors coffre ; ne supprime rien sans `--apply` |
| `--apply` | désactivé | `clean` : supprime, après confirmation |
| `-h`, `--help` | — | Affiche l'en-tête du script |

### Exemples d'utilisation

```bash
vault status
vault open
vault close
vault clean            # simulation
vault clean --apply    # suppression, après confirmation tapée
```

`vault status` sur une machine sans coffre, avec un vrai profil local (le cas d'un poste qui n'a jamais eu de coffre) :

```text
vault status
------------------------------------------------------------
Conteneur : ABSENT  /home/jpdemory/vault.img  (pas de coffre sur cette machine)
LUKS      : FERME
Coffre    : DEMONTE (/home/jpdemory/Vault)
------------------------------------------------------------
Binds :
------------------------------------------------------------
- /home/jpdemory/.config/vivaldi : DEMONTE, données locales hors coffre : 2,2G (vault clean)
- /home/jpdemory/.config/BraveSoftware/Brave-Browser : DEMONTE, données locales hors coffre : 12K (vault clean)
- /home/jpdemory/snap/firefox/common/.mozilla/firefox : ABSENT (attendu -> /home/jpdemory/Vault/browser/firefox/mozilla-firefox)
...
```

Sur cette même machine, `vault clean` refuse, ce qui protège les 2,2 Go de Vivaldi :

```text
[ERREUR]    Aucun coffre sur cette machine (/home/jpdemory/vault.img absent) : les dossiers de profil sont les seuls exemplaires. Rien n'est supprimé.
```

`vault clean` (simulation) sur un poste avec coffre fermé (extrait d'un essai sur un `$HOME` factice) :

```text
[ATTENTION] Dossiers HORS coffre (coffre fermé) qui seraient supprimés :
  4,0K             3 entrées  dernière modification 2026-11-12  <HOME>/.config/vivaldi
  4,0K             2 entrées  dernière modification 2026-11-12  <HOME>/snap/firefox/common/.mozilla/firefox
[ATTENTION] S'ils contiennent votre seul exemplaire d'un profil, il sera perdu.
[INFO]      Le contenu du coffre (<HOME>/Vault) n'est jamais touché.
[INFO]      Simulation — rien n'a été supprimé. Relancez avec : vault clean --apply
```

Avec `--apply`, après la confirmation :

```text
Tapez SUPPRIMER pour confirmer : [INFO]      Renommé : <HOME>/.config/vivaldi → vivaldi.purge-20261112140644-42716
[OK]        Supprimé : <HOME>/.config/vivaldi
[OK]        Nettoyage terminé.
```

Refus quand un montage est actif sur la cible :

```text
[ERREUR]    Montage actif sur ou sous <HOME>/.config/vivaldi : suppression refusée.
```

`vault close` quand un démontage échoue (fichier encore ouvert) : il ne prétend pas avoir fermé.

```text
[ATTENTION] Échec du démontage : <HOME>/snap/firefox/common/.mozilla/firefox
[OK]        Bind démonté : <HOME>/.config/vivaldi
[ERREUR]    Des binds sont encore montés (fichier ouvert ?). Coffre laissé ouvert. Piste : fuser -vm <chemin>
```

`vault open` signale les données locales qu'un bind va masquer :

```text
[ATTENTION] Données locales dans <HOME>/.config/vivaldi : elles seront masquées (les supprimer : vault clean).
[OK]        Bind : <HOME>/Vault/browser/vivaldi-prof → <HOME>/.config/vivaldi
```

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Succès, ou rien à faire (y compris simulation de `clean`) |
| 1 | Erreur d'exécution : conteneur absent ou déjà ouvert, démontage ou suppression en échec, garde-fou de `clean`, root, confirmation refusée |
| 2 | Erreur d'usage : sous-commande ou option inconnue, option hors de sa sous-commande |

---

## Section développeur

### Architecture interne

`main()` : sous-commande → `parse_options` → `check_user` (refus du root, `$HOME` absolu) → dispatch. `status` ne prend pas de verrou ; les autres appellent `acquire_lock` ; `open` et `close` font un `warmup_sudo` (Tier 2).

- `cmd_open` : `luks_is_open` ? `cryptsetup open` ; monte le coffre, `fix_mount_ownership` ; vérifie que le coffre est réellement monté ; pour chaque entrée de `BINDS` : `mkdir -p`, avertit des données locales, `mount --bind`.
- `cmd_close` : `stop_browsers` (SIGTERM puis attente jusqu'à 10 s) ; binds en ordre inverse, chaque `umount` vérifié ; coffre ; LUKS. Tout échec = `die`, sans enchaîner l'étape suivante.
- `cmd_status` : lecture seule (`findmnt`, `du`).
- `cmd_clean` : `check_clean_context` → `collect_candidates` → `assert_deletable` sur **tous** → affichage → (`--apply`) `confirm_typed` → `purge_one` par candidat (`assert_deletable`, `mv -T`, `assert_deletable` sur la copie, `rm -rf --one-file-system`).
- `cmd_create` : `check_not_open`, `check_existing_container`, `read_passphrase`, `warmup_sudo` + `start_sudo_keepalive`, `ensure_cryptsetup`, `create_luks`, puis `cmd_open`.

### Détail des choix techniques

**Pourquoi une commande unique.** Les quatre scripts d'origine répétaient les constantes et la liste des binds, et avaient divergé : `vault-status.sh` ne connaissait que 2 binds sur 4 (Firefox absent), et `vault-close.sh` affichait « Bind démonté » après un `umount` échoué (`|| true` sur une sortie redirigée), puis « Vault fermé ». Une configuration unique supprime la première classe de défaut ; la vérification de chaque démontage supprime la seconde.

**Renommer avant de supprimer.** `rm -rf <point de montage>` vide d'abord le contenu monté, puis échoue sur le dossier lui-même : le mal est fait. `rm --one-file-system` ne suffit pas non plus, car il compare au système de fichiers de l'*argument* : si l'argument est le point de montage, son contenu est du même système et serait supprimé. `rename(2)` sur un point de montage renvoie `EBUSY` : le contrôle devient atomique avec l'action, sans fenêtre de course entre « je vérifie » et « je supprime ». Après le renommage, la copie ne peut plus être un montage (un bind monterait sur le nouveau dossier vide) ; elle est recontrôlée, puis supprimée.

**Lecture des montages dans `/proc/self/mountinfo`.** Champ 5 = point de montage, avec espace, tabulation, saut de ligne et `\` écrits en octal : `mi_escape` convertit le chemin dans cette forme. Le chemin passé doit être **canonique** (`mountinfo` ne contient que des chemins réels), d'où le `realpath` dans `assert_deletable`, qui compare aussi avec `$HOME` normalisé (un `$HOME` accessible par lien symbolique reste utilisable). `awk` reçoit le chemin par `ENVIRON`, pas par `-v` : `-v` interpréterait `\040` comme un espace.

**`findmnt --mountpoint` pour les tests « est monté ? ».** `mountpoint -q` compare les numéros de périphérique de la cible et de son parent ; il se trompe pour un bind mount d'un dossier du même système de fichiers. Ici le coffre est un autre périphérique, donc ça marchait, mais `findmnt` lit les montages réels.

**Verrou `flock`.** `$XDG_RUNTIME_DIR/vault.lock`, descripteur ouvert jusqu'à la fin du script, attente de 30 s. Il sérialise `open`, `close`, `create` et `clean` : c'est ce qui couvre la dernière course (ouvrir le coffre *pendant* le nettoyage), en plus du `EBUSY` de `mv`.

**Dossiers vides ignorés, liens et fichiers retenus.** Un dossier vide n'est pas un profil. Un lien symbolique ou un fichier à l'emplacement d'un bind est au contraire gardé comme candidat, pour que `assert_deletable` le refuse bruyamment.

**`~/vault.img` obligatoire pour `clean`.** « Coffre non monté » ne distingue pas « coffre fermé » de « pas de coffre ». Sur un poste sans coffre, les dossiers de profil sont les vrais profils. Constaté sur cette machine : 2,2 Go de Vivaldi, sans `vault.img`.

**`fix_mount_ownership` récursif seulement si nécessaire.** L'ancien `chown -R` parcourait tout le coffre à chaque ouverture. Il n'est plus lancé que si la racine n'appartient pas déjà à l'utilisateur (premier montage après `mkfs`, ou changement d'uid), ce qui couvre aussi un coffre copié d'une autre machine. `id -u`/`id -g` remplacent `$USER`, qui peut être absent.

**Vérifier que le coffre est monté avant les binds.** Sinon `mkdir -p ~/Vault/browser/...` créerait de fausses sources sur le disque local et les binds s'y brancheraient.

**Passphrase.** Passée par stdin (`--key-file=-`), jamais en argument (visible dans `ps`) ni exportée (visible dans `/proc/<pid>/environ`) ; `--batch-mode` supprime la confirmation `YES` de `luksFormat` ; `printf '%s'` n'ajoute pas de saut de ligne, donc `luksFormat` et `open` reçoivent les mêmes octets. `rm -f "$IMG"` avant `fallocate` : `fallocate` ne tronque pas un fichier plus grand que la taille demandée.

**Refus du root (Tier 3).** Sinon `$HOME` serait celui de root (conteneur créé au mauvais endroit) et, pour `clean`, les protections de permissions disparaîtraient.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
| ------- | ---------------- | --------------------------- |
| `bash` | 4.1 | `exec {fd}>fichier` (verrou) |
| `findmnt` | util-linux 2.23 | `--mountpoint` |
| `flock` | util-linux | verrou |
| `mv` | coreutils 8 | `-T` |
| `rm` | coreutils | `--one-file-system` |
| `realpath` | coreutils | `-e` |
| `cryptsetup` | récent | `--key-file=-`, `--batch-mode` |

### Points d'extension

**Ajouter un navigateur** : une ligne dans `BINDS` et son processus dans `PROCS`. `open`, `close`, `status` et `clean` suivent, sans autre modification :

```bash
"browser/chrome-prof|$HOME/.config/google-chrome"
# PROCS : ajouter chrome
```

**Nouvelle sous-commande** : une fonction `cmd_xxx`, un cas dans `main` (et dans la liste des sous-commandes valides), une entrée dans l'en-tête.

**Quarantaine au lieu de suppression** : dans `purge_one`, remplacer le `rm -rf` par un déplacement vers un dossier daté, et purger après N jours. Non retenu : cela garderait hors du coffre des données que le coffre est censé protéger.

### Notes de maintenance

- **Tester `clean` sans risque.** Ne jamais l'essayer sur le vrai `$HOME`. Les constantes dérivent de `$HOME` : lancer avec `HOME=<dossier factice>`. Pour de vrais bind mounts sans root : `unshare --user --map-user=$(id -u) --map-group=$(id -g) --mount --keep-caps bash …` (l'uid reste non nul, donc le refus du root ne se déclenche pas). **Un cas par espace de noms** : sinon les montages d'un cas persistent dans le suivant et le nettoyage du banc d'essai (`rm -rf`) échoue ou, pire, traverse le montage.
- **Cas à rejouer après toute modification de `clean`** : bind actif sur la cible, montage sous la cible, cible = lien symbolique, course simulée (neutraliser `assert_deletable`, `mv` doit renvoyer `EBUSY`), navigateur lancé, chemin avec espace et antislash, reste `.purge-*`, mauvaise confirmation, verrou tenu.
- **`open` et `close` ne se testent pas de bout en bout sans vrai LUKS.** Les essais utilisent un faux `sudo` et un `luks_is_open` forcé : ils couvrent la logique des binds, pas `cryptsetup`.
- **Ne pas affaiblir `assert_deletable` ni l'ordre renommer → recontrôler → supprimer.** Chaque couche couvre une faille que les autres ne voient pas.
- **Complétion shell.** `vault <Tab>` ne complète pas les sous-commandes ; une complétion bash/zsh serait un ajout simple (liste fixe : `create open close status clean`).
- **Anciens noms.** `vault-open.sh`, `vault-close.sh`, `vault-status.sh` et `vault-create.sh` n'existent plus ; un `yadm pull` les retire des machines.
