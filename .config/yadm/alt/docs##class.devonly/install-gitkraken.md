# `install-gitkraken` — Installation de GitKraken et du CLI GitKraken sur Debian/Ubuntu

---

## Section utilisateur

### Description

`install-gitkraken.sh` installe GitKraken (interface graphique) et/ou GitKraken CLI (`gk`) sur un système Debian/Ubuntu x86_64.

Quatre options sont proposées de manière interactive :

| Option | Composant installé | Méthode |
| ------ | ------------------ | ------- |
| 1 | GitKraken GUI | snap (mises à jour automatiques) |
| 2 | GitKraken GUI | paquet `.deb` depuis `release.gitkraken.com` |
| 3 | GitKraken CLI (`gk`) | paquet `.deb` depuis GitHub Releases |
| 4 | GitKraken GUI + CLI | GUI via snap + `.deb` GitHub pour le CLI |
| 5 | GitKraken GUI + CLI | GUI via `.deb` + `.deb` GitHub pour le CLI |

---

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| `bash` ≥ 4 | Interpréteur | `bash --version` |
| `sudo` | Élévation de privilèges | `sudo -v` |
| `wget` | Téléchargement du `.deb` GUI | `wget --version` |
| `curl` | Téléchargement du CLI via API GitHub | `curl --version` |
| `apt` | Gestion des paquets | `apt --version` |
| `snap` | Optionnel — installé automatiquement si absent | `snap --version` |

---

### Syntaxe

```bash
bash install-gitkraken.sh
```

Le script est interactif : il demande le choix à l'exécution.

---

### Exemples d'utilisation

```bash
# Lancer le script
~/.local/bin/install-gitkraken.sh

# Vérifier l'installation de l'interface graphique
gitkraken &

# Vérifier l'installation du CLI
gk --version
```

---

### Variables d'environnement

Aucune variable d'environnement n'est requise.

---

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| 0 | Installation réussie |
| 1 | Architecture non supportée, URL introuvable, ou choix invalide |

---

## Section développeur

### Architecture interne

Le script est structuré en trois fonctions indépendantes :

- **`install_snap()`** — installe snapd si absent, puis `gitkraken --classic` via snap.
- **`install_deb()`** — télécharge `gitkraken-amd64.deb` depuis `release.gitkraken.com` et l'installe via `apt install`.
- **`install_gk_cli()`** — interroge l'API GitHub Releases (`/repos/gitkraken/gk-cli/releases/latest`) pour obtenir l'URL du fichier `linux_amd64.deb`, le télécharge avec `curl`, puis l'installe via `apt install`.

Le menu principal appelle une ou deux fonctions selon le choix (option 4 = `install_snap` + `install_gk_cli`).

### Dépendances

- API GitHub publique : `https://api.github.com/repos/gitkraken/gk-cli/releases/latest`
- Dépôt officiel GitKraken GUI : `https://release.gitkraken.com/linux/gitkraken-amd64.deb`

### Points d'extension

- Pour automatiser le choix sans interaction, passer le numéro via `echo "3" | bash install-gitkraken.sh`.
- Pour épingler une version du CLI, remplacer la résolution dynamique par une URL fixe pointant vers un tag GitHub spécifique.

### Notes de maintenance

- Le script vérifie uniquement l'architecture `x86_64` ; les architectures ARM ne sont pas supportées par GitKraken.
- Sans dépôt APT configuré, les mises à jour (options 2 et 3) nécessitent de relancer le script manuellement.
