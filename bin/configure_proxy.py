#!/usr/bin/env python3

"""
Nom du fichier    : proxy_configurator.py
Auteur            : Manastria
Date de création  : 31/10/2024
Version           : 0.1
Description       : Script de configuration automatique des proxys pour les environnements
                    'classe' et 'maison'. Configure les proxys pour APT, Docker, Git et les
                    variables d'environnement selon la disponibilité détectée ou forcée.
                    Le script applique les configurations globales via /etc/profile.d/
                    pour tous les utilisateurs.

Usage             : python3 proxy_configurator.py [options] <service>
                   - Utilisez l'option --dry pour activer le mode DRY (sans modifications).
                   - Utilisez --proxy pour spécifier un proxy particulier.
                   - Utilisez --force-env pour forcer un environnement ('classe' ou 'maison').

Options :
  --dry           : Activer le mode DRY pour ne pas appliquer les modifications.
  --proxy <IP:port> : Forcer une adresse de proxy spécifique (ex: 192.168.1.1:3128).
  --force-env <env> : Forcer l'environnement ('classe' pour activer les proxys ou 'maison' pour les désactiver).

Dépendances       : 
  - nc (netcat) pour tester la disponibilité des proxys.
  - Privilèges root requis pour appliquer les configurations en mode non-DRY.

Modifications :
- 31/10/2024 : Version initiale.
"""

import os
import subprocess
import shutil
import argparse

# Configuration des proxys disponibles
APT_PROXIES = ["172.25.253.25:3142", "172.16.0.1:3128"]
DOCKER_PROXIES = ["172.25.253.25:5000"]
HTTP_PROXIES = ["172.16.0.1:3128"]
GW_CLASSROOM = "172.25.254.254"


#region enable_disable_functions

def disable_apt():
    """Désactive la configuration APT."""
    if DRY_MODE:
        print("[DRY MODE] Désactiver la configuration APT (supprimer /etc/apt/apt.conf.d/01proxy)")
    else:
        print("Désactivation de la configuration APT")
        if os.path.exists("/etc/apt/apt.conf.d/01proxy"):
            os.remove("/etc/apt/apt.conf.d/01proxy")


def enable_apt(apt_proxy):
    """Active la configuration APT."""
    if DRY_MODE:
        print(f"[DRY MODE] Activer la configuration APT avec le proxy : {apt_proxy}")
    else:
        print(f"Activation de la configuration APT avec le proxy : {apt_proxy}")
        with open("/etc/apt/apt.conf.d/01proxy", "w") as f:
            f.write(f"Acquire::http::Proxy \"http://{apt_proxy}\";")


def disable_docker():
    """Désactive la configuration Docker."""
    if shutil.which('docker') is not None:
        if DRY_MODE:
            print("[DRY MODE] Désactiver la configuration Docker (supprimer /etc/docker/daemon.json et /etc/systemd/system/docker.service.d/http-proxy.conf)")
        else:
            print("Désactivation de la configuration Docker")
            os.makedirs("/etc/systemd/system/docker.service.d", exist_ok=True)
            with open("/etc/systemd/system/docker.service.d/http-proxy.conf", "w") as f:
                f.write("[Service]\nEnvironment=\"NO_PROXY=\"")
            subprocess.run(["systemctl", "daemon-reload"])
            subprocess.run(["systemctl", "restart", "docker"])
            if os.path.exists("/etc/docker/daemon.json"):
                os.remove("/etc/docker/daemon.json")


def enable_docker(docker_proxy):
    """Active la configuration Docker."""
    if shutil.which('docker') is not None:
        if DRY_MODE:
            print(f"[DRY MODE] Activer la configuration Docker avec le proxy : {docker_proxy}")
        else:
            print(f"Activation de la configuration Docker avec le proxy : {docker_proxy}")
            with open("/etc/docker/daemon.json", "w") as f:
                f.write(f"{{\n  \"registry-mirrors\": [\"http://{docker_proxy}\"],\n  \"insecure-registries\": [\"{docker_proxy}\"]\n}}")
            subprocess.run(["systemctl", "daemon-reload"])
            subprocess.run(["systemctl", "restart", "docker"])


def disable_git():
    """Désactive la configuration Git."""
    if shutil.which('git') is not None:
        if DRY_MODE:
            print("[DRY MODE] Désactiver la configuration Git")
        else:
            print("Désactivation de la configuration Git")
            subprocess.run(["git", "config", "--system", "--unset", "http.proxy"])
            subprocess.run(["git", "config", "--system", "--unset", "https.proxy"])
    else:
        print_advanced("Git n'est pas installé sur ce système.", "red")

def enable_git(http_proxy):
    """Active la configuration Git."""
    if shutil.which('git') is not None:
        if DRY_MODE:
            print(f"[DRY MODE] Activer la configuration Git avec le proxy : {http_proxy}")
        else:
            print(f"Activation de la configuration Git avec le proxy : {http_proxy}")
            subprocess.run(["git", "config", "--system", "http.proxy", f"http://{http_proxy}"])
            subprocess.run(["git", "config", "--system", "https.proxy", f"http://{http_proxy}"])
    else:
        print_advanced("Git n'est pas installé sur ce système.", "red")

def disable_env_proxy():
    """Supprime la configuration des variables d'environnement pour tous les utilisateurs."""
    if DRY_MODE:
        print("[DRY MODE] Supprimer la configuration des variables d'environnement globales (supprimer /etc/profile.d/proxy_env.sh)")
    else:
        proxy_env_path = "/etc/profile.d/proxy_env.sh"
        if os.path.exists(proxy_env_path):
            os.remove(proxy_env_path)
            print("Configuration des variables d'environnement globales supprimée.")
        else:
            print("Aucune configuration de proxy globale à supprimer.")


def enable_env_proxy(proxy):
    """Ajoute les variables d'environnement du proxy pour tous les utilisateurs."""
    if DRY_MODE:
        print(f"[DRY MODE] Ajouter les variables d'environnement du proxy global : {proxy}")
    else:
        proxy_env_path = "/etc/profile.d/proxy_env.sh"
        with open(proxy_env_path, "w") as f:
            f.write(f"export http_proxy=\"http://{proxy}\"\n")
            f.write(f"export https_proxy=\"http://{proxy}\"\n")
            f.write(f"export ftp_proxy=\"http://{proxy}\"\n")
            f.write("export no_proxy=\"localhost,127.0.0.1,.local\"\n")
        print("Variables d'environnement globales de proxy configurées.")

#endregion


#region print_functions
def print_advanced(text, color="default", indent=0):
    # Dictionnaire des couleurs ANSI
    colors = {
        "default": "\033[0m",
        "black": "\033[30m",
        "red": "\033[31m",
        "green": "\033[32m",
        "yellow": "\033[33m",
        "blue": "\033[34m",
        "magenta": "\033[35m",
        "cyan": "\033[36m",
        "light_gray": "\033[37m",
        "dark_gray": "\033[90m",
        "light_red": "\033[91m",
        "light_green": "\033[92m",
        "light_yellow": "\033[93m",
        "light_blue": "\033[94m",
        "light_magenta": "\033[95m",
        "light_cyan": "\033[96m",
        "white": "\033[97m",
    }

    # Validation de la couleur
    color_code = colors.get(color.lower(), colors["default"])
    
    # Construction de la ligne avec indentation et couleur
    indented_text = " " * indent + text
    colored_text = f"{color_code}{indented_text}{colors['default']}"
    
    # Affichage du texte
    print(colored_text)


# Fonction pour afficher un titre avec couleur et soulignement adapté
def print_title(title):
    title_length = len(title)
    print(f"\033[1m{title}\033[0m")
    print(f"\033[94m{'=' * title_length}\033[0m")
#endregion


def test_proxy(proxy_ip):
    """Teste la disponibilité d'un proxy."""
    print(f"    - Test de la disponibilité du proxy : {proxy_ip}...", end=" ")
    host, port = proxy_ip.split(":")
    result = subprocess.run(["nc", "-z", "-w", "2", host, port], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode == 0:
        print("\033[92mdisponible.\033[0m")
        return True
    else:
        print("\033[91mnon disponible.\033[0m")
        return False


def find_proxy(type_proxy):
    if type_proxy == "apt":
        msg = "Recherche du proxy APT disponible..."
        print_advanced(msg)
        return find_available_proxy(APT_PROXIES)
    elif type_proxy == "docker":
        msg = "Recherche du proxy Docker disponible..."
        print_advanced(msg)
        return find_available_proxy(DOCKER_PROXIES)
    elif type_proxy == "http":
        msg = "Recherche du proxy HTTP disponible..."
        print_advanced(msg)
        return find_available_proxy(HTTP_PROXIES)
    else:
        return None


def find_available_proxy(proxies):
    """Trouve le premier proxy disponible dans une liste."""
    print("  \033[1mRecherche du proxy disponible...\033[0m")
    for proxy in proxies:
        if test_proxy(proxy):
            return proxy
    print("Aucun proxy disponible trouvé.")
    return None

def configure_all_proxies():
    """Configure tous les services avec le proxy approprié."""
    apt_proxy = find_available_proxy(APT_PROXIES)
    docker_proxy = find_available_proxy(DOCKER_PROXIES)
    http_proxy = find_available_proxy(HTTP_PROXIES)

    enable_apt(apt_proxy if apt_proxy else "Aucun proxy trouvé pour APT")
    enable_docker(docker_proxy if docker_proxy else "Aucun proxy trouvé pour Docker")
    enable_git(http_proxy if http_proxy else "Aucun proxy trouvé pour Git")
    enable_env_proxy(http_proxy if http_proxy else "Aucun proxy trouvé pour HTTP")


def disable_all_proxies():
    """Désactive tous les services de proxy."""
    disable_apt()
    disable_docker()
    disable_git()
    disable_env_proxy()


def detect_environment():
    """Détecte l'environnement pour déterminer la configuration des proxys."""
    print("\033[1mDétection de l'environnement (classe ou maison)...\033[0m")
    result = subprocess.run(["ping", "-c", "1", "-W", "2", GW_CLASSROOM], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0  # True si on est en classe


def is_root():
    """
    Check if the current user is the root user.

    Returns:
        bool: True if the current user is root, False otherwise.
    """
    return os.geteuid() == 0

def main():
    global proxy  # Utiliser le proxy spécifié ou rechercher un proxy disponible

    if args.force_env == "classe":
        print_advanced("Mode forcé : Environnement classe. Configuration des proxys...", "yellow")
        configure_all_proxies()
    elif args.force_env == "maison":
        print_advanced("Mode forcé : Environnement maison. Désactivation des proxys.", "green")
        disable_all_proxies()
    elif not args.service:  # Si aucun service n'est spécifié, tester l'environnement classe/maison
        if detect_environment():
            print_advanced("Environnement classe détecté. Configuration des proxys...", "yellow")
            configure_all_proxies()
        else:
            print_advanced("Environnement maison détecté. Désactivation des proxys.", "green")
            disable_all_proxies()
    else:
        if args.proxy:
            proxy = args.proxy  # Utiliser le proxy spécifié
        elif args.service == "apt":
            proxy = find_proxy("apt")
        elif args.service == "git":
            proxy = find_proxy("git")
        elif args.service == "docker":
            proxy = find_proxy("docker")
        elif args.service == "http":
            proxy = find_proxy("http")
        
        if proxy:
            service = args.service
            print_advanced(f"Configuration du proxy pour le service '{service}' avec le proxy : {proxy}", "cyan")
            if service == "apt":
                disable_apt()
                enable_apt(proxy)
            elif service == "git":
                disable_git()
                enable_git(proxy)
            elif service == "docker":
                disable_docker()
                enable_docker(proxy)
            elif service == "http":
                disable_env_proxy()
                enable_env_proxy(proxy)
        else:
            print(f"Aucun proxy disponible pour le service '{args.service}'. Utilisez l'option --proxy pour en spécifier un.")

# Configuration des arguments
parser = argparse.ArgumentParser(description="Configurer les proxys pour divers services.")
parser.add_argument('--dry', action='store_true', help="Activer le mode DRY pour ne pas appliquer les modifications")
parser.add_argument('--proxy', type=str, help="Forcer une adresse de proxy spécifique (ex: 192.168.1.1:3128)")
parser.add_argument('--force-env', type=str, choices=["classe", "maison"], 
                    help="Forcer l'environnement : 'classe' pour activer les proxys ou 'maison' pour les désactiver")
subparsers = parser.add_subparsers(dest="service", help="Service à configurer (apt, git, docker, http)")

# Sous-commandes pour chaque service
subparsers.add_parser("apt", help="Configurer le proxy pour APT")
subparsers.add_parser("git", help="Configurer le proxy pour Git")
subparsers.add_parser("docker", help="Configurer le proxy pour Docker")
subparsers.add_parser("http", help="Configurer le proxy pour les variables d'environnement HTTP")

args = parser.parse_args()
DRY_MODE = args.dry
proxy = args.proxy

# Vérifier les privilèges root si le mode DRY est désactivé
if not DRY_MODE and not is_root():
    msg="ERREUR: Ce script doit être exécuté avec des privilèges root (sudo) lorsque le mode DRY est désactivé."
    print_advanced(msg, "red")
    exit(1)

if __name__ == "__main__":
    main()