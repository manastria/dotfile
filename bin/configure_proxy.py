#!/usr/bin/env python3



"""
Nom du fichier    : proxy_manager.py
Auteur            : Manastria (Amélioré par Gemini)
Date de création  : 31/10/2024
Version           : 1.0
Description       : Script de configuration automatique des proxys pour les environnements
                    'classe' et 'maison'. Configure les proxys pour APT, Docker, Git et les
                    variables d'environnement.
                    Le script utilise un affichage clair et un système de logs pour faciliter
                    l'utilisation et le débogage.

Usage             : python3 proxy_manager.py [options] [commande]
                   - Exécutez sans commande pour une détection automatique de l'environnement.
                   - Utilisez 'enable' ou 'disable' pour forcer un état.

Options :
  --dry-run       : Simuler les actions sans appliquer de modifications.
  --proxy <IP:port>: Forcer une adresse de proxy spécifique pour une commande.
  --service <nom> : Spécifier un service unique à configurer (apt, docker, git, env).
  -v, --verbose   : Activer les logs de débogage.

Dépendances       :
  - nc (netcat) pour tester la disponibilité des proxys.
  - rich (pip install rich) pour un affichage amélioré.
  - Privilèges root requis pour appliquer les configurations.

Modifications :
- 23/05/2025 : v1.0 - Refonte complète pour améliorer la maintenabilité, les logs et l'UX.
                     - Centralisation de la configuration.
                     - Intégration du module 'logging'.
                     - Utilisation de 'rich' pour un affichage clair et un tableau récapitulatif.
- 31/10/2024 : v0.1 - Version initiale.
"""

import os
import subprocess
import shutil
import argparse
import logging
import sys
from typing import Dict, List, Optional, Tuple

# --- Dépendances externes ---
try:
    from rich.console import Console
    from rich.table import Table
    from rich.logging import RichHandler
except ImportError:
    print("Erreur: La bibliothèque 'rich' est requise. Veuillez l'installer avec : pip install rich")
    sys.exit(1)

# --- Configuration du Logging ---
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    datefmt="[%X]",
    handlers=[RichHandler(rich_tracebacks=True, show_path=False)]
)
log = logging.getLogger("proxy_manager")
console = Console()

# --- Configuration Principale ---
GW_CLASSROOM = "172.25.254.254"

SERVICES_CONFIG = {
    "apt": {
        "proxies": ["172.25.253.25:3142", "172.16.0.1:3128"],
        "config_file": "/etc/apt/apt.conf.d/01proxy",
        "enable_content": 'Acquire::http::Proxy "http://{proxy}";\nAcquire::https::Proxy "http://{proxy}";',
        "disable_content": (
            'Acquire::http::Proxy "DIRECT";\n'
            'Acquire::https::Proxy "DIRECT";\n'
            'Acquire::http::Proxy-Auto-Detect "";\n'
            'Acquire::https::Proxy-Auto-Detect "";\n'
        ),
    },
    "docker": {
        "proxies": ["172.25.253.25:5000"],
        "config_file": "/etc/docker/daemon.json",
        "enable_content": '{{"registry-mirrors": ["http://{proxy}"], "insecure-registries": ["{proxy}"]}}',
        "post_actions": {
            "enable": ["systemctl", "daemon-reload", "&&", "systemctl", "restart", "docker"],
            "disable": ["systemctl", "daemon-reload", "&&", "systemctl", "restart", "docker"],
        }
    },
    "git": {
        "proxies": ["172.16.0.1:3128"],
        "config_commands": {
            "enable": [
                ["git", "config", "--system", "http.proxy", "http://{proxy}"],
                ["git", "config", "--system", "https.proxy", "http://{proxy}"]
            ],
            "disable": [
                ["git", "config", "--system", "--unset-all", "http.proxy"],
                ["git", "config", "--system", "--unset-all", "https.proxy"]
            ]
        }
    },
    "env": {
        "proxies": ["172.16.0.1:3128"],
        "config_file": "/etc/profile.d/proxy_env.sh",
        "enable_content": (
            'export http_proxy="http://{proxy}"\n'
            'export https_proxy="http://{proxy}"\n'
            'export ftp_proxy="http://{proxy}"\n'
            'export no_proxy="localhost,127.0.0.1,.lan,.local"\n'
        ),
    }
}

# --- Fonctions Utilitaires ---

def check_dependencies():
    """Vérifie que les outils nécessaires (nc, git, docker) sont installés."""
    if not shutil.which("nc"):
        log.error("Dépendance manquante : 'nc' (netcat) n'est pas installé. Veuillez l'installer pour continuer.")
        sys.exit(1)
    if not shutil.which("git"):
        log.warning("L'utilitaire 'git' n'est pas détecté. Les configurations pour Git seront ignorées.")
        del SERVICES_CONFIG["git"]
    if not shutil.which("docker") or not shutil.which("systemctl"):
        log.warning("L'utilitaire 'docker' ou 'systemctl' n'est pas détecté. Les configurations pour Docker seront ignorées.")
        if "docker" in SERVICES_CONFIG:
            del SERVICES_CONFIG["docker"]

def is_root() -> bool:
    """Vérifie si le script est exécuté avec les privilèges root."""
    return os.geteuid() == 0

def run_command(command: List[str], dry_run: bool) -> bool:
    """Exécute une commande système et log le résultat."""
    cmd_str = ' '.join(command)
    if dry_run:
        log.info(f"[DRY-RUN] Exécuterait la commande : '{cmd_str}'")
        return True
    
    log.debug(f"Exécution de la commande : '{cmd_str}'")
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=10
        )
        if result.returncode != 0:
            log.error(f"Erreur lors de l'exécution de '{cmd_str}':\n{result.stderr}")
            return False
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        log.error(f"Erreur lors de l'exécution de '{cmd_str}': {e}")
        return False

def test_proxy(proxy_address: str) -> bool:
    """Teste la disponibilité d'un proxy avec netcat."""
    try:
        host, port = proxy_address.split(":")
        command = ["nc", "-z", "-w", "2", host, port]
        result = subprocess.run(command, capture_output=True)
        return result.returncode == 0
    except ValueError:
        log.error(f"Format de proxy invalide : {proxy_address}")
        return False

def find_available_proxy(proxies: List[str]) -> Optional[str]:
    """Trouve le premier proxy disponible dans une liste."""
    for proxy in proxies:
        log.debug(f"Test du proxy {proxy}...")
        if test_proxy(proxy):
            console.print(f"[green]Proxy {proxy} disponible.[/green]")
            return proxy
    log.warning("Aucun proxy disponible trouvé dans la liste.")
    return None

# --- Logique de Configuration ---

def manage_service(service_name: str, config: Dict, action: str, dry_run: bool, selected_proxy: Optional[str] = None) -> Tuple[str, Optional[str]]:
    """Gère l'activation ou la désactivation d'un service."""
    status = "Échec"
    
    # 1. Gérer les configurations basées sur des commandes (ex: git)
    if "config_commands" in config:
        if action in config["config_commands"]:
            commands = config["config_commands"][action]
            success = True
            for cmd_template in commands:
                cmd = [part.format(proxy=selected_proxy) for part in cmd_template]
                if not run_command(cmd, dry_run):
                    success = False
                    break
            if success:
                status = "Activé" if action == "enable" else "Désactivé"
        return status, selected_proxy

    # 2. Gérer les configurations basées sur des fichiers (ex: apt, env, docker)
    config_file = config["config_file"]
    
    # Action de désactivation
    if action == "disable":
        if "disable_content" in config:
            content = config["disable_content"]
            log.info(f"Écriture du fichier de désactivation : {config_file}")
            if not dry_run:
                try:
                    os.makedirs(os.path.dirname(config_file), exist_ok=True)
                    with open(config_file, "w") as f:
                        f.write(content)
                    status = "Désactivé"
                except IOError as e:
                    log.error(f"Impossible d'écrire dans {config_file}: {e}")
        else:
            if os.path.exists(config_file):
                log.info(f"Suppression du fichier {config_file}")
                if not dry_run:
                    os.remove(config_file)
            status = "Désactivé"
    # Action d'activation
    elif action == "enable" and selected_proxy:
        content = config["enable_content"].format(proxy=selected_proxy)
        log.info(f"Création du fichier de configuration : {config_file}")
        if not dry_run:
            try:
                os.makedirs(os.path.dirname(config_file), exist_ok=True)
                with open(config_file, "w") as f:
                    f.write(content)
                status = "Activé"
            except IOError as e:
                log.error(f"Impossible d'écrire dans le fichier {config_file}: {e}")
    
    # 3. Exécuter les actions post-configuration (ex: redémarrer docker)
    if status in ["Activé", "Désactivé"] and "post_actions" in config and action in config["post_actions"]:
        command_str = ' '.join(config["post_actions"][action])
        commands = [part.strip() for part in command_str.split("&&")]
        for cmd in commands:
            if not run_command(cmd.split(), dry_run):
                return "Échec (post-action)", selected_proxy

    return status, selected_proxy

# --- Fonctions Principales ---

def main():
    """Point d'entrée principal du script."""
    parser = argparse.ArgumentParser(
        description="Gère la configuration des proxys système.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        'command',
        nargs='?',
        choices=['enable', 'disable'],
        help="""
    enable      : Force l'activation des proxys pour l'environnement 'classe'.
    disable     : Force la désactivation de tous les proxys pour l'environnement 'maison'.
    (aucun)     : Détecte automatiquement l'environnement.
    """
    )
    parser.add_argument('--dry-run', action='store_true', help="Simuler les actions sans appliquer de modifications.")
    parser.add_argument('--proxy', type=str, help="Forcer une adresse de proxy spécifique (ex: 192.168.1.1:3128).")
    parser.add_argument('--service', type=str, choices=SERVICES_CONFIG.keys(), help="Cibler un seul service.")
    parser.add_argument('-v', '--verbose', action='store_true', help="Activer les logs de débogage.")
    args = parser.parse_args()

    if args.verbose:
        log.setLevel(logging.DEBUG)
    
    if not args.dry_run and not is_root():
        log.error("Ce script nécessite des privilèges 'root' pour modifier la configuration système. Utilisez 'sudo' ou l'option --dry-run.")
        sys.exit(1)

    if args.dry_run:
        console.print("[yellow]-- Mode DRY-RUN activé : Aucune modification ne sera appliquée --[/yellow]")

    check_dependencies()

    # Déterminer l'action principale : 'enable' ou 'disable'
    action = args.command
    if not action:
        log.info(f"Détection de l'environnement via la passerelle {GW_CLASSROOM}...")
        is_classroom = test_proxy(f"{GW_CLASSROOM}:80") # Ping est moins fiable
        if is_classroom:
            action = "enable"
            console.print("[bold cyan]Environnement 'Classe' détecté.[/bold cyan] Activation des proxys.")
        else:
            action = "disable"
            console.print("[bold green]Environnement 'Maison' détecté.[/bold green] Désactivation des proxys.")
    else:
        console.print(f"[bold yellow]Commande forcée : {action}[/bold yellow]")

    # Préparer le tableau récapitulatif
    summary_table = Table(title="Récapitulatif de la Configuration Proxy", show_header=True, header_style="bold magenta")
    summary_table.add_column("Service", style="cyan")
    summary_table.add_column("Proxy Sélectionné", style="yellow")
    summary_table.add_column("Statut", style="green")

    services_to_configure = [args.service] if args.service else SERVICES_CONFIG.keys()
    
    for service_name in services_to_configure:
        config = SERVICES_CONFIG[service_name]
        selected_proxy = None
        
        if action == "enable":
            # Si un proxy est forcé par l'utilisateur
            if args.proxy:
                log.info(f"Utilisation du proxy forcé par l'utilisateur : {args.proxy}")
                selected_proxy = args.proxy
            # Sinon, chercher un proxy disponible pour le service
            else:
                log.info(f"Recherche d'un proxy pour le service '{service_name}'...")
                selected_proxy = find_available_proxy(config["proxies"])
                if not selected_proxy:
                    log.error(f"Aucun proxy fonctionnel trouvé pour {service_name}. Le service ne sera pas configuré.")
                    summary_table.add_row(service_name.capitalize(), "Aucun", "[red]Non configuré[/red]")
                    continue
        
        status, final_proxy = manage_service(service_name, config, action, args.dry_run, selected_proxy)
        
        # Mettre à jour le statut dans le tableau
        status_color = "green" if status in ["Activé", "Désactivé"] else "red"
        proxy_display = final_proxy if final_proxy else "N/A"
        summary_table.add_row(service_name.capitalize(), proxy_display, f"[{status_color}]{status}[/{status_color}]")

    console.print(summary_table)

if __name__ == "__main__":
    main()
