#!/usr/bin/env python3
"""
yadm_alt_link.py — manage yadm alternates + dev symlinks (Linux/macOS/WSL/Windows)
==================================================================
* Converts each listed path into a yadm *variant* `<name>##os.None`.
* Creates a working‑name link (symlink, junction, or hard‑link when
  Windows lacks symlink privilege).
* Adds the working name to `.git/info/exclude`.
* **Optional**: automatically runs `git rm --cached` on the working name
  so it stops being tracked once the variant exists.

If no paths are passed, the script reads them from
`.config/yadm/alt-link-list.txt` (one per line, `#` allowed).

Windows notes
-------------
* Symlinks need Developer Mode or elevated shell.
* Fallback: directory → junction (`mklink /J`), file → hard‑link (`mklink /H`).
  Hard‑links must stay on the same volume.
"""
import os
import sys
import subprocess
import pathlib
import platform
from typing import List

# --- Configuration ---
SUFFIX = "##os.None"
ALT_DIR = pathlib.PurePosixPath(".config/yadm/alt")
LIST_FILE = pathlib.PurePosixPath(".config/yadm/alt-link-list.txt")
DEBUG = False # Mettre à True pour afficher les informations de débogage

# ───────────────────────── git helpers ────────────────────────────

def git(*args: str, capture: bool = True) -> subprocess.CompletedProcess:
    """Run git and return CompletedProcess."""
    return subprocess.run(["git", *args], text=True,
                          capture_output=capture, check=False)

def repo_root() -> pathlib.Path:
    """Trouve et renvoie le chemin racine du dépôt git."""
    result = git("rev-parse", "--show-toplevel")
    if result.returncode != 0:
        print("Erreur: Impossible de trouver la racine du dépôt git. Assurez-vous d'exécuter ce script dans un dépôt git.", file=sys.stderr)
        sys.exit(1)
    return pathlib.Path(result.stdout.strip())


def exclude_path() -> pathlib.Path:
    """Renvoie le chemin du fichier d'exclusion git local."""
    return pathlib.Path(git("rev-parse", "--git-path", "info/exclude").stdout.strip())

# ───────────────────────── link creation ──────────────────────────

def make_link(target: pathlib.Path, link: pathlib.Path) -> None:
    """Crée un lien symbolique de 'link' vers 'target'.
    
    Gère la création de liens relatifs et la solution de rechange pour Windows
    (jonction pour les répertoires, lien physique pour les fichiers).
    """
    if link.exists() or link.is_symlink():
        if DEBUG: print(f"DEBUG: Le lien '{link}' existe déjà.")
        return

    # Le contenu du lien symbolique doit être un chemin relatif pour la portabilité.
    link_content_path = os.path.relpath(target, start=link.parent)
    
    if DEBUG:
        print(f"DEBUG: make_link(target='{target}', link='{link}')")
        print(f"DEBUG: -> Contenu du lien relatif calculé : '{link_content_path}'")
        print(f"DEBUG: -> La cible est un répertoire : {target.is_dir()}")

    try:
        # La vérification 'target_is_directory' est cruciale, surtout sur Windows.
        os.symlink(link_content_path, link, target_is_directory=target.is_dir())
        return
    except (OSError, NotImplementedError) as err:
        # Sur Windows, une erreur 1314 signifie que le privilège de lien symbolique manque.
        if platform.system() != "Windows" or getattr(err, "winerror", None) != 1314:
            raise  # Lève à nouveau l'erreur si ce n'est pas le cas attendu.
        
        print("· Privilège de lien symbolique manquant, utilisation de la solution de rechange Windows.")
        # Solution de rechange : mklink /J (jonction) ou /H (lien physique)
        # Ces commandes nécessitent des chemins absolus.
        cmd = ["cmd", "/c", "mklink"]
        cmd += ["/J" if target.is_dir() else "/H", str(link), str(target)]
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# ───────────────────────── exclude handling ───────────────────────

def add_to_exclude(exclude: pathlib.Path, rel: str) -> None:
    """Ajoute un chemin au fichier .git/info/exclude."""
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.touch(exist_ok=True)
    
    # Utilise un set pour une recherche efficace et éviter les doublons.
    with exclude.open('r', encoding='utf-8') as f:
        if rel in {ln.rstrip() for ln in f}:
            return
            
    with exclude.open("a", encoding='utf-8') as f:
        f.write(rel + "\n")
    print(f"· Ajouté à info/exclude: {rel}")

# ───────────────────────── index cleanup ──────────────────────────

def remove_from_index(rel: str) -> None:
    """Retire un fichier de l'index git s'il y est présent."""
    if git("ls-files", "--error-unmatch", rel).returncode == 0:
        print(f"· '{rel}' est suivi par git. Tentative de retrait de l'index...")
        git("rm", "--cached", "-r", "--", rel, capture=False)
        print(f"· Retiré de l'index: {rel}")

# ───────────────────────── targets list ───────────────────────────

def read_list_file(root: pathlib.Path) -> List[str]:
    """Lit la liste des chemins depuis le fichier de configuration."""
    fp = root / LIST_FILE
    if not fp.exists():
        return []
    with fp.open('r', encoding='utf-8') as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.lstrip().startswith('#')]


def get_targets(root: pathlib.Path) -> List[str]:
    """Obtient la liste des chemins à traiter, soit depuis les arguments, soit depuis le fichier."""
    if len(sys.argv) > 1:
        return sys.argv[1:]
        
    paths = read_list_file(root)
    if paths:
        print(f"Aucun chemin via CLI – utilisation de {LIST_FILE} ({len(paths)} entrées)")
        return paths
        
    print("Erreur: Aucun chemin n'a été fourni et le fichier de liste est introuvable ou vide.", file=sys.stderr)
    sys.exit(1)

# ───────────────────────── processing ─────────────────────────────

def variant_path(root: pathlib.Path, rel: str) -> pathlib.Path:
    """Construit le chemin de la variante yadm pour un chemin relatif donné."""
    p = pathlib.Path(rel)
    # Utilise PurePosixPath pour la construction afin de garantir des slashes, puis convertit en Path
    return root / pathlib.Path(str(ALT_DIR / p.parent / f"{p.name}{SUFFIX}"))


def ensure_variant_dirs(path: pathlib.Path):
    """S'assure que les répertoires parents pour une variante existent."""
    path.parent.mkdir(parents=True, exist_ok=True)


def move_existing_root_variant(path: pathlib.Path, var_path: pathlib.Path):
    """Déplace une variante existante au mauvais endroit vers le répertoire alt/."""
    root_variant = path.with_name(path.name + SUFFIX)
    if root_variant.exists() and not var_path.exists():
        ensure_variant_dirs(var_path)
        root_variant.rename(var_path)
        rel_var_path = var_path.relative_to(repo_root())
        print(f"· Déplacement de la variante existante → {rel_var_path.as_posix()}")


def process_one(rel: str, root: pathlib.Path, exclude: pathlib.Path):
    """Traite un seul chemin : le transforme en variante et crée un lien."""
    print(f"\n--- Traitement de : {rel} ---")
    work_path = root / rel
    var_path = variant_path(root, rel)
    
    if DEBUG:
        print(f"DEBUG: work_path = '{work_path}'")
        print(f"DEBUG: var_path  = '{var_path}'")

    # Déplace une variante pré-existante qui serait au mauvais endroit
    move_existing_root_variant(work_path, var_path)

    relative_var_path = var_path.relative_to(root / ALT_DIR).as_posix()

    # Cas 1 : La variante existe, mais le lien de travail n'existe pas ou n'est pas un lien.
    if var_path.exists() and not work_path.is_symlink():
        if work_path.exists():
             print(f"Avertissement : '{rel}' existe mais n'est pas un lien. Il sera ignoré pour éviter la perte de données.")
        else:
            make_link(var_path, work_path)
            print(f"Lien créé: {rel} → {ALT_DIR.as_posix()}/{relative_var_path}")
            
    # Cas 2 : Le fichier de travail existe, mais la variante n'existe pas.
    elif work_path.exists() and not work_path.is_symlink() and not var_path.exists():
        ensure_variant_dirs(var_path)
        work_path.rename(var_path)
        make_link(var_path, work_path)
        print(f"Déplacé & lié: {rel} → {ALT_DIR.as_posix()}/{relative_var_path}")
        
    # Cas 3 : Tout est déjà en place ou la situation n'est pas gérée.
    else:
        status = "Déjà configuré." if work_path.is_symlink() else "Rien à faire."
        print(f"✓ {status} pour {rel}")

    add_to_exclude(exclude, rel)
    remove_from_index(rel)

# ───────────────────────── main ───────────────────────────────────

def main():
    """Fonction principale du script."""
    try:
        root = repo_root()
        os.chdir(root) # S'assurer que l'on s'exécute depuis la racine du repo
        exclude = exclude_path()

        targets = get_targets(root)
        for t in targets:
            process_one(t, root, exclude)

        if targets:
            # Construit la liste des fichiers à ajouter pour le message final
            files_to_add = []
            for t in targets:
                var_p = variant_path(root, t)
                if var_p.exists():
                    # Utilise as_posix() pour des chemins propres dans le message
                    files_to_add.append(f"'{var_p.relative_to(root).as_posix()}'")
            
            if files_to_add:
                print(f"\nTerminé. N'oubliez pas de valider les changements :")
                print(f"git add {' '.join(files_to_add)}")
                print(f"git commit -m 'feat: add yadm variants for cross-platform support'")

    except Exception as e:
        print(f"\nUne erreur inattendue est survenue : {e}", file=sys.stderr)
        if DEBUG:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
