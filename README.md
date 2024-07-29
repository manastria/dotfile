# Configuration Linux avec YADM

Ce dépôt contient les fichiers de configuration Linux de l'utilisateur Manastria. Vous pouvez facilement les utiliser en suivant les étapes ci-dessous.

## Clonage du dépôt

Pour utiliser ces fichiers de configuration sur votre système, vous pouvez les cloner en utilisant `yadm` en exécutant la commande suivante :

```bash
yadm clone https://github.com/manastria/dotfile.git
```

Cela créera une copie locale des fichiers de configuration sur votre système.

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

## Changement de l'URL du dépôt distant (HTTP vers SSH ou vice versa)

Si vous souhaitez changer l'URL du dépôt distant de HTTPS à SSH (ou vice versa), vous pouvez utiliser la commande `yadm remote set-url`. Voici comment faire :

### Passage de HTTPS à SSH

```bash
yadm remote set-url origin git@github.com:manastria/dotfile.git
```

Uniquement pour push :
```bash
yadm remote set-url --push origin git@github.com:manastria/dotfile.git
```

### Passage de SSH à HTTPS

```bash
yadm remote set-url origin https://github.com/manastria/dotfile.git
```
Uniquement pour push :
```bash
yadm remote set-url --push origin https://github.com/manastria/dotfile.git
```


Assurez-vous d'avoir configuré correctement vos clés SSH si vous choisissez d'utiliser l'URL SSH.

C'est tout ! Vous pouvez maintenant utiliser les fichiers de configuration Linux de Manastria à l'aide de `yadm` et les personnaliser selon vos besoins.
