#!/usr/bin/env python3
"""
yadm_alt_link.py — manage yadm alternates + dev symlinks (Linux/macOS/WSL/Windows)
==================================================================
* Converts each listed path into a yadm *variant* `<name>##class.devonly`.
  The `class.devonly` suffix never matches any yadm class, so the file is
  only present in the development checkout, not deployed to $HOME.
* Creates a working‑name link (symlink, junction, or hard‑link when
  Windows lacks symlink privilege).
* Adds the working name to `.git/info/exclude`.
* **Optional**: automatically runs `git rm --cached` on the working name
  so it stops being tracked once the variant exists.

If no paths are passed, the script reads them from
`.config/yadm/alt-link-list.txt` (one per line, `#` allowed).

Migration: files using the old `##os.None` suffix are automatically
renamed to `##class.devonly` on first run.

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
import shutil
import argparse
import filecmp
from dataclasses import dataclass
from typing import List

# --- Configuration ---
SUFFIX = "##class.devonly"
OLD_SUFFIX = "##os.None"
ALT_DIR = pathlib.PurePosixPath(".config/yadm/alt")
LIST_FILE = pathlib.PurePosixPath(".config/yadm/alt-link-list.txt")
DEBUG = False # Mettre à True pour afficher les informations de débogage
NO_SYMLINK = {
    ".gitignore",
    ".gitattributes",
    ".gitmodules",
}
MAX_TRACKED_LIST = 30


@dataclass
class ProcessingStats:
    """Compteurs de suivi pour le traitement des fichiers."""
    processed: int = 0
    moved: int = 0
    linked: int = 0
    replaced: int = 0
    already_ok: int = 0
    warnings: int = 0
    skipped: int = 0
    migrated: int = 0

    @property
    def changes_made(self) -> int:
        """Nombre total de modifications effectuées."""
        return self.moved + self.linked + self.replaced + self.migrated

    def summary(self) -> str:
        """Retourne un résumé formaté des statistiques."""
        parts = []
        if self.migrated:
            parts.append(f"{self.migrated} migré(s)")
        if self.moved:
            parts.append(f"{self.moved} déplacé(s)")
        if self.linked:
            parts.append(f"{self.linked} lié(s)")
        if self.replaced:
            parts.append(f"{self.replaced} remplacé(s)")
        if self.already_ok:
            parts.append(f"{self.already_ok} déjà OK")
        if self.warnings:
            parts.append(f"{self.warnings} avertissement(s)")
        if self.skipped:
            parts.append(f"{self.skipped} ignoré(s)")
        if not parts:
            return f"{self.processed} traité(s), aucune modification"
        return f"{self.processed} traité(s) : " + ", ".join(parts)

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

# ───────────────────────── link / junction detection ──────────────

def is_link_or_junction(path: pathlib.Path) -> bool:
    """Vérifie si le chemin est un lien symbolique ou une jonction Windows."""
    if path.is_symlink():
        return True
    # Python 3.12+ expose Path.is_junction()
    if hasattr(path, 'is_junction'):
        return path.is_junction()
    # Fallback pour Python < 3.12 sous Windows
    if platform.system() == 'Windows':
        try:
            os.readlink(path)
            return True
        except OSError:
            pass
    return False


# ───────────────────────── link creation ──────────────────────────

def make_link(target: pathlib.Path, link: pathlib.Path) -> None:
    """Crée un lien symbolique de 'link' vers 'target'.
    
    Gère la création de liens relatifs et la solution de rechange pour Windows
    (jonction pour les répertoires, lien physique pour les fichiers).
    """
    if link.exists() or is_link_or_junction(link):
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

def format_rel(path: pathlib.Path, root: pathlib.Path) -> str:
    """Retourne un chemin relatif au dépôt (ou absolu si hors dépôt)."""
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


# ───────────────────────── migration ──────────────────────────────

def _fix_symlinks_after_rename(root: pathlib.Path, old_name: str, new_name: str) -> int:
    """Répare les symlinks cassés après un renommage de variante.

    Parcourt la racine du dépôt à la recherche de symlinks dont la cible
    contient l'ancien nom et les redirige vers le nouveau.
    Retourne le nombre de symlinks réparés.
    """
    fixed = 0
    alt_dir = root / ALT_DIR
    for item in root.iterdir():
        if is_link_or_junction(item):
            target = os.readlink(item)
            if OLD_SUFFIX in str(target):
                new_target = str(target).replace(OLD_SUFFIX, SUFFIX)
                item.unlink()
                os.symlink(new_target, item)
                print(f"  · Symlink réparé : {item.name} → {new_target}")
                fixed += 1
    return fixed


def migrate_old_suffix(root: pathlib.Path, stats: 'ProcessingStats') -> None:
    """Migre les fichiers ##os.None vers ##class.devonly dans le répertoire alt/.

    - Renomme les fichiers/dossiers avec l'ancien suffixe
    - Répare les symlinks cassés par le renommage
    - Les hardlinks survivent au rename (même inode)
    """
    alt_path = root / ALT_DIR
    if not alt_path.exists():
        return

    renamed = []
    for item in sorted(alt_path.iterdir()):
        if item.name.endswith(OLD_SUFFIX):
            new_name = item.name.replace(OLD_SUFFIX, SUFFIX)
            new_path = item.parent / new_name
            if new_path.exists():
                print(f"  WARN: '{new_name}' existe déjà, migration ignorée pour '{item.name}'")
                stats.warnings += 1
                continue
            item.rename(new_path)
            renamed.append((item.name, new_name))
            stats.migrated += 1

    if renamed:
        print(f"\n=== Migration {OLD_SUFFIX} → {SUFFIX} ===")
        for old, new in renamed:
            print(f"  · {old} → {new}")
        _fix_symlinks_after_rename(root, OLD_SUFFIX, SUFFIX)


def should_avoid_symlink(rel: str) -> bool:
    """Indique si le chemin doit éviter les symlinks."""
    return pathlib.PurePosixPath(rel).as_posix() in NO_SYMLINK


def create_working_link_or_file(
    target: pathlib.Path,
    link: pathlib.Path,
    rel: str,
    root: pathlib.Path,
) -> None:
    """Crée un lien de travail ou un fichier selon les contraintes."""
    if link.exists() or is_link_or_junction(link):
        if DEBUG:
            print(f"DEBUG: Le lien/fichier '{link}' existe déjà.")
        return

    if should_avoid_symlink(rel):
        link_rel = format_rel(link, root)
        target_rel = format_rel(target, root)
        try:
            os.link(target, link)
            print(f"Working file created as hardlink: {link_rel} → {target_rel}")
            return
        except OSError:
            if target.is_dir():
                shutil.copytree(target, link)
            else:
                shutil.copy2(target, link)
            print(f"Working file created as copy: {link_rel} → {target_rel}")
            return

    make_link(target, link)

def print_link_created(rel: str, relative_var_path: str, action: str = "Lien créé") -> None:
    """Affiche un message standard pour la création de lien."""
    print(f"{action}: {rel} → {ALT_DIR.as_posix()}/{relative_var_path}")

# ───────────────────────── working path checks ────────────────────

def resolve_symlink_target(link: pathlib.Path) -> pathlib.Path:
    """Résout la cible d'un symlink en chemin absolu."""
    try:
        target = os.readlink(link)
    except OSError:
        return pathlib.Path()
    if not os.path.isabs(target):
        target = os.path.abspath(os.path.join(link.parent, target))
    return pathlib.Path(target)


def is_same_inode(path_a: pathlib.Path, path_b: pathlib.Path) -> bool:
    """Indique si deux chemins pointent vers le même inode."""
    try:
        return os.path.samefile(path_a, path_b)
    except OSError:
        return False


def is_same_content(path_a: pathlib.Path, path_b: pathlib.Path) -> bool:
    """Compare le contenu de deux fichiers."""
    if not path_a.is_file() or not path_b.is_file():
        return False
    try:
        return filecmp.cmp(path_a, path_b, shallow=False)
    except OSError:
        return False


def report_sync_divergence(
    work_path: pathlib.Path,
    var_path: pathlib.Path,
    rel: str,
    root: pathlib.Path,
) -> None:
    """Compare les mtime et affiche la commande cp pour re-synchroniser."""
    if not work_path.exists() or not var_path.exists():
        return
    if is_same_inode(work_path, var_path):
        return
    if is_same_content(work_path, var_path):
        return

    work_mtime = work_path.stat().st_mtime
    var_mtime = var_path.stat().st_mtime
    work_rel = format_rel(work_path, root)
    var_rel = format_rel(var_path, root)

    if work_mtime > var_mtime:
        print(f"  SYNC: '{work_rel}' est plus récent que la variante")
        print(f"        → cp '{work_rel}' '{var_rel}'")
    elif var_mtime > work_mtime:
        print(f"  SYNC: La variante '{var_rel}' est plus récente")
        print(f"        → cp '{var_rel}' '{work_rel}'")
    else:
        print(f"  SYNC: '{rel}' diverge de sa variante (même mtime, contenu différent)")
        print(f"        Vérifiez manuellement : '{work_rel}' vs '{var_rel}'")


def working_is_correct(
    work_path: pathlib.Path,
    var_path: pathlib.Path,
    avoid_symlink: bool,
) -> bool:
    """Vérifie si le working-name correspond déjà à la variante."""
    if not var_path.exists():
        return False
    if is_link_or_junction(work_path):
        if avoid_symlink:
            return False
        return resolve_symlink_target(work_path) == var_path.resolve()
    if is_same_inode(work_path, var_path):
        return True
    return is_same_content(work_path, var_path)


def remove_working_path(work_path: pathlib.Path) -> None:
    """Supprime le working-name sans toucher à la variante."""
    if work_path.is_symlink():
        work_path.unlink()
        return
    # Jonction Windows : os.rmdir supprime la jonction sans suivre la cible
    # (shutil.rmtree suivrait la jonction et détruirait le contenu cible)
    if is_link_or_junction(work_path):
        os.rmdir(work_path)
        return
    if work_path.is_file():
        work_path.unlink()
        return
    if work_path.is_dir():
        shutil.rmtree(work_path)

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

def is_dir_target(rel: str, root: pathlib.Path) -> bool:
    """Détermine si le chemin cible est un dossier."""
    if rel.endswith("/"):
        return True
    candidate = root / rel
    return candidate.exists() and candidate.is_dir()


def git_lines(*args: str) -> List[str]:
    """Retourne la sortie de git sous forme de lignes non vides."""
    result = git(*args)
    if result.returncode != 0:
        return []
    return [ln for ln in result.stdout.splitlines() if ln.strip()]


def warn_tracked(rel: str, tracked: List[str]) -> None:
    """Affiche un avertissement clair pour les fichiers suivis."""
    if not tracked:
        return
    print(f"WARN: Exclusion en conflit: {rel} contient des fichiers suivis par git.")
    show = tracked[:MAX_TRACKED_LIST]
    for line in show:
        print(f"   - {line}")
    remaining = len(tracked) - len(show)
    if remaining > 0:
        print(f"   +{remaining} autres")


def check_tracked(rel: str, root: pathlib.Path) -> List[str]:
    """Détecte les fichiers suivis par git pour un chemin donné."""
    if is_dir_target(rel, root):
        query = rel.rstrip("/") + "/"
        return git_lines("ls-files", "--", query)

    tracked = git_lines("ls-files", "--", rel)
    if tracked:
        stage = git_lines("ls-files", "--stage", "--", rel)
        if stage:
            tracked.extend([f"index: {ln}" for ln in stage])
    return tracked


def remove_from_index(rel: str, root: pathlib.Path, fix_tracked: bool, check_only: bool) -> None:
    """Diagnostique et retire de l'index si nécessaire, y compris pour les dossiers.

    Exemple d'output (dossier exclu mais contenu suivi):
    # WARN: Exclusion en conflit: config/ contient des fichiers suivis par git.
    #    - config/app.yml
    #    - config/secret.env
    #    +2 autres
    """
    tracked = check_tracked(rel, root)
    if not tracked:
        return

    warn_tracked(rel, tracked)
    if check_only:
        print("· Mode check-only: aucun changement dans l'index.")
        return
    if not fix_tracked:
        print("· Correction désactivée (--no-fix-tracked-excluded).")
        return

    print(f"· Retrait des entrées de l'index pour: {rel}")
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


def get_targets(root: pathlib.Path, paths: List[str]) -> List[str]:
    """Obtient la liste des chemins à traiter, soit depuis les arguments, soit depuis le fichier."""
    if paths:
        return paths
        
    paths = read_list_file(root)
    if paths:
        print(f"Aucun chemin via CLI – utilisation de {LIST_FILE} ({len(paths)} entrées)")
        return paths
        
    print("Erreur: Aucun chemin n'a été fourni et le fichier de liste est introuvable ou vide.", file=sys.stderr)
    sys.exit(1)

# ───────────────────────── validation ─────────────────────────────

def validate_targets(targets: List[str], root: pathlib.Path) -> List[str]:
    """Valide et déduplique la liste des chemins cibles.

    - Normalise les / finaux
    - Détecte et élimine les doublons
    - Détecte les chemins imbriqués (ex: docs et docs/sub)
    - Signale les entrées introuvables (ni working-name ni variante)
    Retourne la liste dédupliquée.
    """
    # Normalisation et déduplication
    seen = {}
    deduped = []
    for t in targets:
        normalized = t.rstrip("/")
        if not normalized:
            continue
        if normalized in seen:
            print(f"WARN: Doublon ignoré : '{t}' (déjà listé comme '{seen[normalized]}')")
            continue
        seen[normalized] = t
        deduped.append(normalized)

    # Détection des chemins imbriqués
    sorted_paths = sorted(deduped)
    for i, p in enumerate(sorted_paths):
        for j in range(i + 1, len(sorted_paths)):
            if sorted_paths[j].startswith(p + "/"):
                print(f"WARN: Chemin imbriqué détecté : '{sorted_paths[j]}' est contenu dans '{p}'")

    # Vérification de l'existence
    for t in deduped:
        work = root / t
        var = variant_path(root, t)
        # Vérifie aussi l'ancien suffixe pour les fichiers non encore migrés
        old_var = root / pathlib.Path(str(ALT_DIR / pathlib.Path(t).parent / f"{pathlib.Path(t).name}{OLD_SUFFIX}"))
        if not work.exists() and not work.is_symlink() and not var.exists() and not old_var.exists():
            print(f"WARN: Entrée introuvable : '{t}' (ni working-name ni variante)")

    return deduped


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
    for suffix in (SUFFIX, OLD_SUFFIX):
        root_variant = path.with_name(path.name + suffix)
        if root_variant.exists() and not var_path.exists():
            ensure_variant_dirs(var_path)
            root_variant.rename(var_path)
            rel_var_path = var_path.relative_to(repo_root())
            print(f"· Déplacement de la variante existante → {rel_var_path.as_posix()}")
            break


def process_one(
    rel: str,
    root: pathlib.Path,
    exclude: pathlib.Path,
    fix_tracked: bool,
    check_only: bool,
    force: bool,
    stats: ProcessingStats,
    sync: bool = False,
):
    """Traite un seul chemin : le transforme en variante et crée un lien."""
    print(f"\n--- Traitement de : {rel} ---")
    stats.processed += 1
    work_path = root / rel
    var_path = variant_path(root, rel)
    avoid_symlink = should_avoid_symlink(rel)

    if DEBUG:
        print(f"DEBUG: work_path = '{work_path}'")
        print(f"DEBUG: var_path  = '{var_path}'")

    # Déplace une variante pré-existante qui serait au mauvais endroit
    move_existing_root_variant(work_path, var_path)

    relative_var_path = var_path.relative_to(root / ALT_DIR).as_posix()

    # Cas 1 : La variante n'existe pas, mais le working-name existe.
    if not var_path.exists() and work_path.exists() and not is_link_or_junction(work_path):
        ensure_variant_dirs(var_path)
        work_path.rename(var_path)
        create_working_link_or_file(var_path, work_path, rel, root)
        if avoid_symlink:
            print(f"Déplacé vers la variante: {ALT_DIR.as_posix()}/{relative_var_path}")
        else:
            print_link_created(rel, relative_var_path, action="Déplacé & lié")
        stats.moved += 1

    # Cas 2 : La variante existe, mais le working-name n'existe pas.
    elif var_path.exists() and not work_path.exists() and not is_link_or_junction(work_path):
        create_working_link_or_file(var_path, work_path, rel, root)
        if not avoid_symlink:
            print_link_created(rel, relative_var_path)
        stats.linked += 1

    # Cas 3 : La variante existe et le working-name existe.
    elif var_path.exists() and (work_path.exists() or is_link_or_junction(work_path)):
        if working_is_correct(work_path, var_path, avoid_symlink):
            print(f"✓ Déjà configuré pour {rel}")
            stats.already_ok += 1
            if sync and avoid_symlink:
                report_sync_divergence(work_path, var_path, rel, root)
        else:
            print(f"Avertissement : '{rel}' existe mais ne correspond pas à la variante.")
            stats.warnings += 1
            if sync and avoid_symlink:
                report_sync_divergence(work_path, var_path, rel, root)
            if force:
                remove_working_path(work_path)
                create_working_link_or_file(var_path, work_path, rel, root)
                if not avoid_symlink:
                    print_link_created(rel, relative_var_path, action="Remplacé & lié")
                stats.replaced += 1
            else:
                print("· Utilisez --force pour remplacer le working-name.")

    # Cas 4 : La variante n'existe pas et le working-name est un lien/jonction.
    elif not var_path.exists() and is_link_or_junction(work_path):
        print(f"Avertissement : '{rel}' est un lien mais la variante est absente. Aucun changement appliqué.")
        stats.warnings += 1

    # Cas 5 : Rien à faire.
    else:
        print(f"✓ Rien à faire pour {rel}")
        stats.skipped += 1

    add_to_exclude(exclude, rel)
    remove_from_index(rel, root, fix_tracked, check_only)

# ───────────────────────── main ───────────────────────────────────

def main():
    """Fonction principale du script."""
    try:
        parser = argparse.ArgumentParser(
            description="Gère les variantes yadm et les liens de travail."
        )
        parser.add_argument(
            "paths",
            nargs="*",
            help="Chemins à traiter (sinon via le fichier de liste).",
        )
        parser.add_argument(
            "--fix-tracked-excluded",
            dest="fix_tracked_excluded",
            action="store_true",
            default=True,
            help="Retire de l'index les chemins exclus suivis (par défaut).",
        )
        parser.add_argument(
            "--no-fix-tracked-excluded",
            dest="fix_tracked_excluded",
            action="store_false",
            help="Ne modifie pas l'index, seulement le diagnostic.",
        )
        parser.add_argument(
            "--check-only",
            action="store_true",
            help="Diagnostique uniquement, ne modifie rien.",
        )
        parser.add_argument(
            "--force",
            action="store_true",
            help="Remplace le working-name s'il est incohérent.",
        )
        parser.add_argument(
            "--sync",
            action="store_true",
            help="Détecte les divergences entre les fichiers hardlink/copie et leurs variantes.",
        )
        args = parser.parse_args()

        root = repo_root()
        os.chdir(root) # S'assurer que l'on s'exécute depuis la racine du repo
        exclude = exclude_path()
        stats = ProcessingStats()

        # Migration des anciens suffixes ##os.None → ##class.devonly
        migrate_old_suffix(root, stats)

        targets = get_targets(root, args.paths)
        targets = validate_targets(targets, root)

        for t in targets:
            process_one(
                t,
                root,
                exclude,
                fix_tracked=args.fix_tracked_excluded,
                check_only=args.check_only,
                force=args.force,
                stats=stats,
                sync=args.sync,
            )

        # Résumé final
        print(f"\n=== Résumé : {stats.summary()} ===")

        if stats.changes_made > 0:
            # Construit la liste des fichiers à ajouter pour le message final
            files_to_add = []
            for t in targets:
                var_p = variant_path(root, t)
                if var_p.exists():
                    files_to_add.append(f"'{var_p.relative_to(root).as_posix()}'")

            if files_to_add:
                print(f"\nN'oubliez pas de valider les changements :")
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

# Tests manuels (commandes reproductibles)
# 1) Cas fichier sensible .gitignore (hardlink/copie, pas de warning git)
#    printf "test\n" > .gitignore
#    python3 bin/yadm_alt_link.py .gitignore
#    file .gitignore
#    git add .gitignore  # aucun warning "Trop de niveaux de liens symboliques"
#
# 2) Cas fichier normal (symlink attendu)
#    printf "ok\n" > foo.txt
#    python3 bin/yadm_alt_link.py foo.txt
#    ls -l foo.txt  # doit indiquer un lien symbolique vers .config/yadm/alt/...
#
# 3) Cas dossier (symlink/junction attendu) + exclusion + detection fichiers suivis
#    mkdir -p some/dir
#    printf "data\n" > some/dir/a.txt
#    git add some/dir/a.txt && git commit -m "test: add tracked file"
#    python3 bin/yadm_alt_link.py some/dir
#    ls -l some/dir  # lien vers .config/yadm/alt/...##class.devonly
#    # attendu: avertissement listant some/dir/a.txt
#
# 4) Cas deja versionne (fichier exclu dans l'index)
#    printf "track\n" > tracked.txt
#    git add tracked.txt && git commit -m "test: tracked file"
#    python3 bin/yadm_alt_link.py --fix-tracked-excluded tracked.txt
#    git ls-files -- tracked.txt  # ne doit rien afficher
#
# 5) Migration automatique ##os.None → ##class.devonly
#    # Placer un fichier avec l'ancien suffixe dans .config/yadm/alt/
#    python3 bin/yadm_alt_link.py  # doit migrer et réparer les symlinks
#    ls .config/yadm/alt/  # doit montrer ##class.devonly
#
# 6) Détection de divergence (--sync)
#    echo "test" >> .gitignore
#    python3 bin/yadm_alt_link.py --sync  # doit signaler la divergence
#
# 7) Doublons dans les cibles
#    python3 bin/yadm_alt_link.py .editorconfig .editorconfig  # doit signaler le doublon
#
# 8) Cas répertoire (ex: docs/)
#    mkdir -p docs && echo "readme" > docs/index.md
#    python3 bin/yadm_alt_link.py docs/  # le / final est normalisé
