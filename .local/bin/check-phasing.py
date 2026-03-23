#!/usr/bin/python3

import apt_pkg
import subprocess
import sys
import hashlib

def get_machine_id():
    """Récupère l'ID machine utilisé pour le calcul du score de déploiement."""
    try:
        with open('/etc/machine-id') as f:
            return f.read().strip()
    except FileNotFoundError:
        return None

def get_phasing_score():
    # Initialiser apt_pkg
    apt_pkg.init_system()
    
    try:
        # Lire le machine-id
        with open('/etc/machine-id', 'r') as f:
            machine_id = f.read().strip()
        
        # Calculer le hash
        hash_obj = hashlib.sha512(machine_id.encode())
        hash_bytes = hash_obj.digest()
        
        # Utiliser les 2 premiers octets pour générer un nombre entre 0 et 100
        score = (hash_bytes[0] << 8 | hash_bytes[1]) % 100
        
        return score
        
    except Exception as e:
        print(f"Erreur: {e}")
        return None

def get_package_phasing(package_name):
    """Récupère le statut de déploiement progressif d'un paquet."""
    try:
        output = subprocess.check_output(['apt-cache', 'policy', package_name], 
                                      universal_newlines=True)
        for line in output.splitlines():
            if 'phased' in line:
                return int(line.split('phased')[1].strip('()%'))
    except:
        return None
    return None

def will_get_update(package_name):
    """Détermine si cette machine recevra la mise à jour pour un paquet donné."""
    phasing = get_package_phasing(package_name)
    if phasing is None:
        return None
    return get_phasing_score() <= phasing

def main():
    score = get_phasing_score()
    machine_id = get_machine_id()
    
    print(f"Score de déploiement de cette machine : {score}%")
    print(f"ID Machine : {machine_id}")
    print("\nCela signifie que :")
    print(f"- Vous recevrez les mises à jour quand leur déploiement dépassera {score}%")
    print("- Par exemple :")
    print(f"  - Une mise à jour à 'phased 30%' : {'Oui' if score <= 30 else 'Non'}")
    print(f"  - Une mise à jour à 'phased 50%' : {'Oui' if score <= 50 else 'Non'}")
    print(f"  - Une mise à jour à 'phased 80%' : {'Oui' if score <= 80 else 'Non'}")
    
    # Vérifier quelques paquets upgradables
    print("\nAnalyse des mises à jour différées disponibles :")
    try:
        output = subprocess.check_output(['apt', 'list', '--upgradable'], 
                                      universal_newlines=True)
        packages = [line.split('/')[0] for line in output.splitlines()[1:]]
        for pkg in packages:
            phasing = get_package_phasing(pkg)
            if phasing is not None:
                will_get = will_get_update(pkg)
                status = "recevrez" if will_get else "ne recevrez pas encore"
                print(f"- {pkg} : phased {phasing}% - Vous {status} cette mise à jour")
    except:
        print("Impossible de vérifier les paquets upgradables")

if __name__ == "__main__":
    main()

