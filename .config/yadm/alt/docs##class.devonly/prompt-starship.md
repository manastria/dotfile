# Gestion du prompt avec Starship

Ce document décrit le système de gestion du prompt du shell, basé sur [Starship](https://starship.rs/) avec un fallback Bash natif.

---

## Vue d'ensemble

Le fichier [.shellrc/bashrc.d/10_prompt.bash](.shellrc/bashrc.d/10_prompt.bash) gère le prompt selon la logique suivante :

1. **Starship disponible** → Starship est activé avec le profil courant (persisté dans `~/.config/starship/current_profile`).
2. **Starship absent** → un prompt Bash coloré de secours est activé automatiquement.

---

## Prérequis : installer les polices Nerd Fonts

Starship utilise des glyphes (icônes, flèches) issus des **Nerd Fonts**. Sans elles, le prompt affiche des caractères illisibles.

### Script d'installation

Le script [.local/bin/install-term-fonts.sh](.local/bin/install-term-fonts.sh) installe **FiraCode Nerd Font** et **FiraMono Nerd Font** (v3.4.0).

#### Installation en mode utilisateur (recommandé)

```bash
~/.local/bin/install-term-fonts.sh
```

Les polices sont installées dans `~/.local/share/fonts/nerd-fonts/`.

#### Installation système (tous les utilisateurs)

```bash
~/.local/bin/install-term-fonts.sh --system
# ou, si sudo est requis :
sudo ~/.local/bin/install-term-fonts.sh --system
```

Les polices sont installées dans `/usr/local/share/fonts/nerd-fonts/`.

#### Miroir personnalisé

```bash
NF_URL_FIRACODE="https://mon-miroir/FiraCode.zip" \
NF_URL_FIRAMONO="https://mon-miroir/FiraMono.zip" \
~/.local/bin/install-term-fonts.sh
```

#### Dépendances

Le script installe automatiquement via `apt-get` si nécessaire : `curl`, `unzip`, `fontconfig`.

#### Configurer la police dans votre terminal

Après installation, dans les préférences de votre terminal :

| Usage          | Police à sélectionner               |
| -------------- | ----------------------------------- |
| Sans ligatures | `FiraMono Nerd Font Mono` (Regular) |
| Avec ligatures | `FiraCode Nerd Font Mono` (Regular) |

### Vérifier que la Nerd Font est active

Après avoir sélectionné la police dans votre terminal, testez l'affichage des glyphes avec cette commande :

```bash
echo -e "\ue0b0 \ue0b2 \uf09b \uf015 \uf001 \uf121 \uf1d3 \uf0e7 \uf484 \uf17a"
```

Résultat attendu si la police est correctement configurée :

```
  ➜  ➜  ➜  ➜  ➜  ➜  ➜  ➜  ➜
```

> Vous devez voir des icônes reconnaissables (flèches Powerline, logo GitHub, maison, note de musique, etc.).
> Si vous voyez des carrés □ ou des points d'interrogation ?, la police Nerd Font **n'est pas active** dans votre terminal.

Pour un test plus complet avec les symboles les plus courants du prompt Starship :

```bash
printf "Powerline : \ue0b0 \ue0b1 \ue0b2 \ue0b3\n"
printf "Git       : \uf418  branche  \uf06a  conflit  \uf00c  ok\n"
printf "Dossier   : \uf07c  dossier  \uf15b  fichier\n"
printf "Statuts   : \uf058  succès   \uf057  erreur   \uf059  info\n"
printf "Langages  : \ue626  Python   \ue69d  Rust     \ue781  Go\n"
```

Si une ligne affiche des □ à la place des icônes, la police n'est pas correctement sélectionnée dans les préférences du terminal. Relancez le terminal après le changement de police.

---

## Profils Starship

Les configs Starship se trouvent dans [.config/starship/](.config/starship/).

### Profil `default`

Fichier : [.config/starship/default.toml](.config/starship/default.toml)

Prompt complet avec icônes et couleurs :
- Nom d'utilisateur en bleu gras
- Répertoire en cyan
- Branche Git avec icône 🌱
- Symbole `❯` vert (succès) ou `✗` rouge (erreur)

### Profil `projector`

Fichier : [.config/starship/projector.toml](.config/starship/projector.toml)

Prompt simplifié à fort contraste, conçu pour la projection (cours, présentations) :
- Format réduit : `user > répertoire > branche > symbole`
- Fond coloré sur chaque segment pour la lisibilité
- Pas d'horloge ni de modules distrayants
- Troncature du chemin à 5 niveaux

---

## Changer de profil

Deux fonctions sont disponibles directement dans le shell (définies dans [.shellrc/bashrc.d/10_prompt.bash](.shellrc/bashrc.d/10_prompt.bash)) :

### `prompt_default`

Active le profil Starship standard.

```bash
prompt_default
```

### `prompt_projector`

Active le profil à fort contraste pour la projection.

```bash
prompt_projector
```

Le choix est **persisté** dans `~/.config/starship/current_profile` : il sera rechargé automatiquement à la prochaine ouverture de shell.

Pour que le changement prenne effet immédiatement dans la session courante :

```bash
exec $SHELL
```

---

## Fallback Bash (sans Starship)

Si Starship n'est pas installé, un prompt coloré natif est activé automatiquement :

```
(venv) user@host ~/chemin $
```

| Élément    | Comportement                                      |
| ---------- | ------------------------------------------------- |
| `user`     | Vert si dernière commande OK, rouge sinon         |
| `(venv)`   | Affiché en cyan si un virtualenv Python est actif |
| `host`     | Bleu gras                                         |
| `~/chemin` | Violet                                            |
| `$`        | Jaune vif                                         |

Le titre de l'onglet/fenêtre est mis à jour automatiquement (`host: ~/chemin`) pour les terminaux compatibles (xterm, rxvt, konsole, gnome-terminal, alacritty).

---

## Installer Starship

```bash
curl -sS https://starship.rs/install.sh | sh
```

Puis relancer le shell :

```bash
exec $SHELL
```
