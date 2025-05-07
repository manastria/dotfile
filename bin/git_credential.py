#!/usr/bin/env python3

import getpass
import subprocess

username = input("GitHub username: ")
token = getpass.getpass("GitHub token (fine-grained): ")

# Configure Git to cache credentials for 1 hour
subprocess.run(["git", "config", "--global", "credential.helper", "cache --timeout=3600"])

# Prepare credential input
cred_input = f"""protocol=https
host=github.com
username={username}
password={token}
"""

# Inject credentials into Git's credential cache
proc = subprocess.run(
    ["git", "credential-cache", "store"],
    input=cred_input.encode(),
    check=True
)

print("✅ GitHub credentials stored in memory for 1 hour.")

