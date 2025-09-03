# Installation des dotfiles

> [!IMPORTANT]
> Assurez-vous d'avoir installé `yadm` sur votre système avant de cloner le dépôt.

Pour utiliser ces fichiers de configuration sur votre système, vous pouvez les cloner en utilisant `yadm` en exécutant la commande suivante :

```bash
yadm clone --recurse-submodules https://github.com/manastria/dotfile.git
```

Cela créera une copie locale des fichiers de configuration sur votre système.

> [!NOTE]
> Pour gagner du temps et de la bande passante, vous pouvez cloner uniquement la dernière version du dépôt sans les sous-modules :
>
> ```bash
> git clone --depth 1 <https://github.com/manastria/dotfile.git>
> ```

Installer les paquets couramment utilisés :

```bash
bin/install_paquets.sh
```

## Mise à jour des fichiers de configuration

Si vous souhaitez mettre à jour vos fichiers de configuration locaux avec les dernières modifications du dépôt, vous pouvez utiliser la commande suivante :

```bash
yadm pull
```

## Revenir à l'état initial

Si vous souhaitez réinitialiser vos fichiers de configuration locaux à l'état initial du dépôt, vous pouvez utiliser la commande suivante (attention, cela supprimera toutes les modifications locales non enregistrées) :

```bash
yadm reset --hard
```

## Installations

### Installer starship

Starship est un prompt shell rapide et personnalisable qui affiche des informations pertinentes tout en restant minimal et élégant.

```bash
bin/install_starship.sh
```

## Gestion des sous modules

### Téléchargement des sous modules

Après avoir cloné le dépôt, récupérez les submodules avec :

```bash
yadm submodule update --init --recursive
```

Cette commande initialisera et téléchargera tous les submodules configurés dans le dépôt.

Un script existe dans le répertoire `bin` du dépôt pour mettre à jour les sous modules :

```bash
yadm_check_submodules.sh
```

### Vérifier l’état des sous-modules

Pour vérifier si les submodules sont à jour, utilisez la commande :

```bash
git submodule status
```

Si il y a des modifications à télécharger, utiliser la même commande que ci-dessus :

```bash
git submodule update --init --recursive
```
