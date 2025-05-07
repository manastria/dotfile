#!/usr/bin/env python3

import getpass
import subprocess
import os
import re
from pathlib import Path

# Définir le chemin du fichier de configuration
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
                print(f"GitHub username loaded from {config_file}")
                break

# Si aucun nom d'utilisateur trouvé, le demander à l'utilisateur
if not username:
    username = input("GitHub username: ")

    # Proposer de l'enregistrer dans le fichier de configuration
    save = input(f"Do you want to save this username to {config_file}? [y/N] ").strip().lower()
    if save == 'y':
        # Ajouter ou créer le fichier avec la ligne username=...
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
token = getpass.getpass("GitHub token (fine-grained): ")

# Configurer Git pour mettre en cache les identifiants pendant 1 heure
subprocess.run(["git", "config", "--global", "credential.helper", "cache --timeout=3600"])

# Préparer les informations d'identification à injecter dans le cache de Git
cred_input = f"""protocol=https
host=github.com
username={username}
password={token}
"""

# Injecter les informations d'identification dans le cache de Git
subprocess.run(
    ["git", "credential-cache", "store"],
    input=cred_input.encode(),
    check=True
)

print("✅ GitHub credentials stored in memory for 1 hour.")
