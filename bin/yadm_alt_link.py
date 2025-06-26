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

SUFFIX = "##os.None"
ALT_DIR = pathlib.PurePosixPath(".config/yadm/alt")
LIST_FILE = pathlib.PurePosixPath(".config/yadm/alt-link-list.txt")

# ───────────────────────── git helpers ────────────────────────────

def git(*args: str, capture: bool = True) -> subprocess.CompletedProcess:
    """Run git and return CompletedProcess."""
    return subprocess.run(["git", *args], text=True,
                          capture_output=capture, check=False)

def repo_root() -> pathlib.Path:
    return pathlib.Path(git("rev-parse", "--show-toplevel").stdout.strip())


def exclude_path() -> pathlib.Path:
    return pathlib.Path(git("rev-parse", "--git-path", "info/exclude").stdout.strip())

# ───────────────────────── link creation ──────────────────────────

def make_link(target: pathlib.Path, link: pathlib.Path) -> None:
    if link.exists():
        return
    try:
        os.symlink(target, link, target_is_directory=target.is_dir())
        return
    except (OSError, NotImplementedError) as err:
        if platform.system() != "Windows" or getattr(err, "winerror", None) != 1314:
            raise
    # Windows fallback (no symlink privilege)
    cmd = ["cmd", "/c", "mklink"]
    cmd += ["/J" if target.is_dir() else "/H", str(link), str(target)]
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# ───────────────────────── exclude handling ───────────────────────

def add_to_exclude(exclude: pathlib.Path, rel: str) -> None:
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.touch(exist_ok=True)
    with exclude.open() as f:
        if rel in {ln.rstrip() for ln in f}:
            return
    with exclude.open("a") as f:
        f.write(rel + "\n")
    print(f"· Added to info/exclude: {rel}")

# ───────────────────────── index cleanup ──────────────────────────

def remove_from_index(rel: str) -> None:
    if git("ls-files", "--error-unmatch", rel).returncode == 0:
        git("rm", "--cached", "-r", "--", rel, capture=False)
        print(f"· Removed from index: {rel}")

# ───────────────────────── targets list ───────────────────────────

def read_list_file(root: pathlib.Path) -> List[str]:
    fp = root / LIST_FILE
    if not fp.exists():
        return []
    with fp.open() as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.lstrip().startswith('#')]


def get_targets(root: pathlib.Path) -> List[str]:
    if len(sys.argv) > 1:
        return sys.argv[1:]
    paths = read_list_file(root)
    if paths:
        print(f"No CLI paths – using {LIST_FILE} ({len(paths)} entries)")
        return paths
    print("Error: no paths given and no list file found.")
    sys.exit(1)

# ───────────────────────── processing ─────────────────────────────

def variant_path(root: pathlib.Path, rel: str) -> pathlib.Path:
    p = pathlib.Path(rel)
    return root / ALT_DIR / p.parent / f"{p.name}{SUFFIX}"


def ensure_variant_dirs(path: pathlib.Path):
    path.parent.mkdir(parents=True, exist_ok=True)


def move_existing_root_variant(path: pathlib.Path, var_path: pathlib.Path):
    root_variant = path.with_name(path.name + SUFFIX)
    if root_variant.exists() and not var_path.exists():
        ensure_variant_dirs(var_path)
        root_variant.rename(var_path)
        print(f"· Moved existing root variant → {ALT_DIR}/{var_path.relative_to(pathlib.Path('.'))}")


def process_one(rel: str, root: pathlib.Path, exclude: pathlib.Path):
    work_path = root / rel
    var_path = variant_path(root, rel)

    # Move any pre‑existing root‑level variant
    move_existing_root_variant(work_path, var_path)

    if var_path.exists() and not work_path.is_symlink():
        make_link(os.path.relpath(var_path, start=work_path.parent), work_path)
        print(f"Symlink created: {rel} → {ALT_DIR}/{var_path.relative_to(root/ALT_DIR)}")
    elif work_path.exists() and not var_path.exists():
        ensure_variant_dirs(var_path)
        work_path.rename(var_path)
        make_link(os.path.relpath(var_path, start=work_path.parent), work_path)
        print(f"Moved & linked: {rel} → {ALT_DIR}/{var_path.relative_to(root/ALT_DIR)}")
    else:
        print(f"✓ Nothing to do for {rel}")

    add_to_exclude(exclude, rel)
    remove_from_index(rel)

# ───────────────────────── main ───────────────────────────────────

def main():
    root = repo_root()
    os.chdir(root)
    exclude = exclude_path()

    targets = get_targets(root)
    for t in targets:
        process_one(t, root, exclude)

    if targets:
        variants = " ".join(f"'{ALT_DIR}/{pathlib.Path(t).name}{SUFFIX}'" for t in targets)
        print(f"\nDone. Remember to: git add {variants} && git commit -m 'yadm variants in alt/'")

if __name__ == "__main__":
    main()
