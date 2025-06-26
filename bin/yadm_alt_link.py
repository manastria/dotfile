#!/usr/bin/env python3
"""
yadm_alt_link.py — cross‑platform helper for yadm alternates + development symlinks
================================================================
*   Keeps real content under <name>##os.None (never installed by yadm)
*   Creates a working‑name link and adds it to .git/info/exclude
*   Works on **Linux / macOS / WSL / Windows**
*   If called **without arguments**, reads the list of paths from
    `.config/yadm/alt-link-list.txt` (one per line, `#`‑comments allowed).

Windows specifics
-----------------
Windows blocks symbolic links unless **Developer Mode** is enabled *or*
terminal is run as **Administrator**.  This script transparently falls back:
* Directory → **junction**  (`mklink /J`) – no special right needed.
* File      → **hard link** (`mklink /H`) – no special right needed.

Hard links cannot span drives. For a different drive you’ll still need the
privilege or create a copy manually.
"""
import os
import sys
import subprocess
import pathlib
import platform
from typing import List

SUFFIX = "##os.None"
LIST_FILE = pathlib.PurePosixPath(".config/yadm/alt-link-list.txt")

# ────────────────────────── helpers ──────────────────────────────

def run_git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def repo_root() -> pathlib.Path:
    return pathlib.Path(run_git("rev-parse", "--show-toplevel"))

def exclude_path() -> pathlib.Path:
    return pathlib.Path(run_git("rev-parse", "--git-path", "info/exclude"))


def make_link(target: pathlib.Path, link: pathlib.Path) -> None:
    """Create a link. Use symlink when allowed, else junction (/J) or hard‑link (/H)."""
    if link.exists():
        # Nothing to do (idempotent execution)
        return

    try:
        os.symlink(target, link, target_is_directory=target.is_dir())
        return  # Success (any OS that supports it / privilege present)
    except (OSError, NotImplementedError) as err:
        # On Windows check privilege error code 1314 (ERROR_PRIVILEGE_NOT_HELD)
        is_win = platform.system() == "Windows"
        win_priv_error = getattr(err, "winerror", None) == 1314
        if not is_win or not win_priv_error:
            raise  # Other errors ➜ propagate

    # ── Windows fallback (no symlink privilege) ──────────────────
    cmd_base = ["cmd", "/c", "mklink"]

    if target.is_dir():
        # Directory → junction (doesn’t need privilege)
        cmd = cmd_base + ["/J", str(link), str(target)]
    else:
        # File → hard link (same volume only)
        cmd = cmd_base + ["/H", str(link), str(target)]

    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            "Impossible de créer le lien (même avec mklink). "
            "Exécute le terminal en Administrateur ou active le Mode Développeur."
        ) from e


def add_to_exclude(exclude: pathlib.Path, relative: str) -> None:
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.touch(exist_ok=True)
    with exclude.open() as f:
        if relative in {ln.rstrip("\n") for ln in f}:
            return
    with exclude.open("a") as f:
        f.write(relative + "\n")
        print(f"· Ajouté à info/exclude : {relative}")


# ────────────────────────── main logic ───────────────────────────

def read_list_file(rroot: pathlib.Path) -> List[str]:
    file_path = rroot / LIST_FILE
    if not file_path.exists():
        return []
    with file_path.open() as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.lstrip().startswith("#")]


def get_targets(rroot: pathlib.Path) -> List[str]:
    if len(sys.argv) > 1:
        return sys.argv[1:]
    lines = read_list_file(rroot)
    if lines:
        print(f"No CLI paths — using {LIST_FILE} ({len(lines)} entries)")
        return lines
    print("Erreur : aucun chemin passé et aucun fichier liste trouvé.")
    sys.exit(1)


def process_one(path_rel: str, rroot: pathlib.Path, exclude: pathlib.Path):
    path = rroot / path_rel
    variant = path.with_name(path.name + SUFFIX)

    if variant.exists() and not path.is_symlink():
        make_link(variant, path)
        print(f"Lien créé : {path_rel} → {path_rel}{SUFFIX}")
    elif path.exists() and not variant.exists():
        path.rename(variant)
        make_link(variant, path)
        print(f"Déplacé puis lien : {path_rel} → {path_rel}{SUFFIX}")
    else:
        print(f"✓ Rien à faire pour {path_rel}")

    add_to_exclude(exclude, path_rel)


def main():
    rroot = repo_root()
    os.chdir(rroot)
    exclude = exclude_path()

    targets = get_targets(rroot)
    for rel in targets:
        process_one(rel, rroot, exclude)

    joined = " ".join(f"'{t}{SUFFIX}'" for t in targets)
    if joined:
        print(f"\nTerminé – pense à : git add {joined} && git commit -m 'yadm variants'")

if __name__ == "__main__":
    main()
