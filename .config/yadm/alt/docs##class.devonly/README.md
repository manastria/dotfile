# Documentation du dépôt dotfile

Index des pages de `docs/`. Deux natures de documents cohabitent :

- **pages de script** — une par script de [`.local/bin/`](../.local/bin/), nommée d'après le script sans son extension, structurée en *Section utilisateur* / *Section développeur* ;
- **guides thématiques** — un sujet transverse (prompt, navigation, profils zsh…) qui couvre plusieurs fichiers de configuration.

Les conventions de rédaction sont fixées dans [CLAUDE.md](../CLAUDE.md), section *Documentation des scripts*.

---

## Pages de script

### Archivage et sauvegarde

| Page | Script | Objet |
| ---- | ------ | ----- |
| [pack_project.md](pack_project.md) | [`pack-project.sh`](../.local/bin/pack-project.sh) | Archive `.tar.zst` d'un projet, exclusions dev automatiques, `.git` conservé |
| [pack_dir.md](pack_dir.md) | [`pack-dir.sh`](../.local/bin/pack-dir.sh) | Même chose en configurable : codec, `.zip`, exclusions personnalisées |
| [pack-bundle.md](pack-bundle.md) | [`pack-bundle.sh`](../.local/bin/pack-bundle.sh) | Sauvegarde de l'historique Git en fichier `.bundle` clonable |
| [backup-projets.md](backup-projets.md) | [`backup-projets.sh`](../.local/bin/backup-projets.sh) | Miroir incrémental d'une liste de projets vers une clé USB, avant d'éteindre |

### Système et matériel

| Page | Script | Objet |
| ---- | ------ | ----- |
| [usb-mount.md](usb-mount.md) | [`usb-mount.sh`](../.local/bin/usb-mount.sh), [`usb-umount.sh`](../.local/bin/usb-umount.sh) | Montage de clés USB chiffrées LUKS/f2fs depuis un fichier de configuration |
| [switch-to-networkmanager.md](switch-to-networkmanager.md) | [`switch-to-networkmanager.sh`](../.local/bin/switch-to-networkmanager.sh) | Bascule de netplan/systemd-networkd vers NetworkManager |

### Shell et environnement

| Page | Script | Objet |
| ---- | ------ | ----- |
| [set-default-shell.md](set-default-shell.md) | [`set-default-shell.sh`](../.local/bin/set-default-shell.sh) | Menu interactif : shell par défaut (bash/zsh) et profil zsh |
| [fix-zsh-completions.md](fix-zsh-completions.md) | [`fix-zsh-completions.sh`](../.local/bin/fix-zsh-completions.sh) | Répare les complétions zsh cassées (liens morts `compinit`, montages WSL volatils) |

### Outillage du dépôt

| Page | Script | Objet |
| ---- | ------ | ----- |
| [yadm-alt-link.md](yadm-alt-link.md) | [`yadm-alt-link.py`](../.local/bin/yadm-alt-link.py) | Sépare les fichiers réservés au développement via les alt yadm |
| [yadm-check-submodules.md](yadm-check-submodules.md) | [`yadm-check-submodules.sh`](../.local/bin/yadm-check-submodules.sh) | Synchronise les submodules du dépôt yadm vers le commit épinglé |

### Installateurs

| Page | Script | Objet |
| ---- | ------ | ----- |
| [install-gitkraken.md](install-gitkraken.md) | [`install-gitkraken.sh`](../.local/bin/install-gitkraken.sh) | GitKraken (GUI) et GitKraken CLI (`gk`) sur Debian/Ubuntu |
| [install-xmind.md](install-xmind.md) | [`install-xmind.sh`](../.local/bin/install-xmind.sh) | Xmind (`.deb` officiel) sur KUbuntu/XUbuntu : profil AppArmor et trousseau de clés |
| [install-projecteur.md](install-projecteur.md) | [`install-projecteur.sh`](../.local/bin/install-projecteur.sh) | Projecteur (pointeur laser virtuel Logitech Spotlight), compilé depuis les sources |

---

## Guides thématiques

| Guide | Sujet |
| ----- | ----- |
| [zsh-profils.md](zsh-profils.md) | Profils zsh (`zenv`) : powerlevel10k, oh-my-zsh, tmux, profil minimal |
| [zsh-light.md](zsh-light.md) | Profil `light`, basé sur le prompt *pure* |
| [prompt-starship.md](prompt-starship.md) | Prompt Starship et repli sur le prompt Bash natif |
| [navigation-fasd-fzf.md](navigation-fasd-fzf.md) | Navigation interactive : zoxide + fzf |
| [migration-fasd-fzf-vers-zoxide.md](migration-fasd-fzf-vers-zoxide.md) | Historique : migration de fasd + fzf (subrepo) vers zoxide + fzf (binaire) |
| [mise-a-jour-submodules-zsh.md](mise-a-jour-submodules-zsh.md) | Mise à jour d'oh-my-zsh, de ses plugins et du thème (submodules git) |

---

## Ajouter ou mettre à jour une page

1. Nommer le fichier d'après le script, **sans extension** : `mon-script.sh` → `docs/mon-script.md`.
   Les pages `pack_dir.md` et `pack_project.md` utilisent des tirets bas pour des raisons historiques ; ne pas reproduire ce choix.
2. Reprendre le plan imposé — *En bref* (paragraphe de rappel pour le mémo), puis *Section utilisateur* (Description, Prérequis, Syntaxe, Exemples, Codes de retour), puis *Section développeur* (Architecture interne, Détail des choix techniques, Dépendances externes, Points d'extension, Notes de maintenance). [yadm-check-submodules.md](yadm-check-submodules.md) sert de modèle récent.
3. **Ajouter la ligne correspondante dans cet index**, dans la catégorie qui convient.
4. À chaque modification du comportement d'un script (option, valeur par défaut, code de retour, prérequis), relire sa page. Script supprimé : supprimer sa page et sa ligne ici.

> `docs/` est un lien yadm alt vers `.config/yadm/alt/docs##class.devonly/` : écrire dans `docs/` suffit, le fichier est versionné à son emplacement réel.

---

## Couverture

Les scripts antérieurs à cette convention ne sont pas tous documentés. Pour lister ceux qui n'ont pas encore de page :

```bash
cd ~   # racine du dépôt yadm
LC_ALL=C comm -13 \
  <(ls docs/*.md | xargs -n1 basename | sed 's/\.md$//' | tr '_' '-' | LC_ALL=C sort) \
  <(ls .local/bin/*.sh .local/bin/*.py .local/bin/*.pl | xargs -n1 basename | sed 's/\.[^.]*$//' | LC_ALL=C sort)
```

La commande compare des noms : elle signale aussi les guides thématiques sans script homonyme, et ne détecte pas une page devenue obsolète par rapport à son script.
