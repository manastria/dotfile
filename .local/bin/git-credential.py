#!/usr/bin/env python3
"""
NAME
    git-credential.py -- stocke temporairement des identifiants GitHub
    (utilisateur + token) dans le cache d'identifiants Git

SYNOPSIS
    python3 git-credential.py

    Aucune option en ligne de commande : le script est entièrement piloté
    par des prompts interactifs (voir OPTIONS).

DESCRIPTION
    Simplifie l'authentification HTTPS vers GitHub en évitant de ressaisir
    un token à chaque `git push`/`git pull`. Le script lit le nom
    d'utilisateur GitHub dans ~/.github_config s'il existe, sinon le
    demande et propose de l'enregistrer pour les prochaines exécutions.
    Le token (idéalement un fine-grained personal access token) est
    ensuite demandé de façon masquée et injecté dans le cache
    d'identifiants Git (`git credential-cache`), qui le garde en mémoire
    (jamais sur disque) pendant 1 heure via un socket local géré par
    `git-credential-cache--daemon`.

OPTIONS
    Aucun argument CLI. Le script interagit via prompts :

    GitHub username
        Chargé automatiquement depuis ~/.github_config si présent,
        sinon demandé en saisie visible.

    Do you want to save this username to ~/.github_config? [y/N]
        N'apparaît que si le username a été saisi manuellement. Répondre
        "y" persiste uniquement le username (jamais le token) dans
        ~/.github_config pour éviter de le ressaisir la prochaine fois.

    GitHub token (fine-grained)
        Saisie masquée (getpass) : le token ne s'affiche jamais à
        l'écran et n'est jamais écrit sur disque, seulement transmis en
        mémoire à `git credential-cache store`.

EXAMPLES
    Premier lancement, aucune configuration existante :
        $ python3 git-credential.py
        GitHub username: manastria
        Do you want to save this username to /home/user/.github_config? [y/N] y
        GitHub token (fine-grained):
        ✅ GitHub credentials stored in memory for 1 hour.

    Lancements suivants, username déjà enregistré :
        $ python3 git-credential.py
        GitHub username loaded from /home/user/.github_config : manastria
        GitHub token (fine-grained):
        ✅ GitHub credentials stored in memory for 1 hour.

    Une fois le script exécuté, les opérations Git HTTPS suivantes ne
    redemandent plus les identifiants pendant 1h :
        $ git push origin main

EXIT CODES
    0   Succès : identifiants stockés dans le cache Git.
    !=0 Le script ne gère pas les erreurs explicitement : toute exception
        Python (ex. `git credential-cache store` en échec via
        check=True) remonte sous forme de traceback avec un code de
        sortie non nul.
"""

import getpass
import subprocess
import os
import re
from pathlib import Path

# Fichier texte local : ne contient que le username, jamais de secret,
# donc il peut rester en clair sans risque particulier.
config_file = Path.home() / ".github_config"
username = None

# Lire le fichier de configuration s'il existe
if config_file.exists():
    with open(config_file, "r") as f:
        for line in f:
            line = line.strip()
            # Chercher une ligne du type "username = toto"
            match = re.match(r'^username\s*=\s*(.+)$', line)
            if match:
                username = match.group(1).strip()
                print(f"GitHub username loaded from {config_file} : {username}")
                break

# Si aucun nom d'utilisateur trouvé, le demander à l'utilisateur
if not username:
    username = input("GitHub username: ")

    # Proposer de l'enregistrer dans le fichier de configuration
    save = input(f"Do you want to save this username to {config_file}? [y/N] ").strip().lower()
    if save == 'y':
        # Ajouter ou créer le fichier avec la ligne username=...
        # On réécrit ligne par ligne (plutôt qu'un simple append) pour
        # remplacer une éventuelle entrée username= existante au lieu
        # d'en créer une seconde, tout en préservant les autres lignes
        # du fichier (utile si d'autres clés y sont ajoutées un jour).
        lines = []
        if config_file.exists():
            with open(config_file, "r") as f:
                lines = f.readlines()
            with open(config_file, "w") as f:
                updated = False
                for line in lines:
                    if line.strip().startswith("username="):
                        f.write(f"username={username}\n")
                        updated = True
                    else:
                        f.write(line)
                if not updated:
                    f.write(f"username={username}\n")
        else:
            with open(config_file, "w") as f:
                f.write(f"username={username}\n")
        print(f"✅ Username saved to {config_file}")

# Demander le token GitHub (fine-grained), masqué à la saisie
# getpass (et non input) pour ne jamais afficher ni logger le secret.
token = getpass.getpass("GitHub token (fine-grained): ")

# Configurer Git pour mettre en cache les identifiants pendant 1 heure
# --global : nécessaire pour que le helper s'applique à tous les repos
# de l'utilisateur, pas seulement au repo courant. `cache` garde le
# secret uniquement en mémoire (socket local), jamais sur disque,
# contrairement au helper `store`.
subprocess.run(["git", "config", "--global", "credential.helper", "cache --timeout=3600"])

# Préparer les informations d'identification à injecter dans le cache de Git
# Format imposé par le protocole git-credential(1) : un bloc clé=valeur
# terminé par une ligne vide, lu sur stdin par `git credential-cache store`.
cred_input = f"""protocol=https
host=github.com
username={username}
password={token}
"""

# Injecter les informations d'identification dans le cache de Git
# check=True : fait échouer le script bruyamment si l'injection rate,
# plutôt que de laisser croire à un succès silencieux.
subprocess.run(
    ["git", "credential-cache", "store"],
    input=cred_input.encode(),
    check=True
)

print("✅ GitHub credentials stored in memory for 1 hour.")
