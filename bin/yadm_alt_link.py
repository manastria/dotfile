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
LIST_FILE = pathlib.PurePosixPath(".config/yadm/alt-link-list.txt")

# ───────────────────────── helpers ────────────────────────────────

def run_git(*args: str, **kw) -> subprocess.CompletedProcess:
    """Run git command, returning CompletedProcess."""
    return subprocess.run(["git", *args], text=True, capture_output=True, **kw)


def repo_root() -> pathlib.Path:
    return pathlib.Path(run_git("rev-parse", "--show-toplevel").stdout.strip())


def exclude_path() -> pathlib.Path:
    return pathlib.Path(run_git("rev-parse", "--git-path", "info/exclude").stdout.strip())


# ---- link creation cross‑OS --------------------------------------

def make_link(target: pathlib.Path, link: pathlib.Path) -> None:
    if link.exists():
        return  # already there
    try:
        os.symlink(target, link, target_is_directory=target.is_dir())
        return
    except (OSError, NotImplementedError) as err:
        is_win = platform.system() == "Windows"
        if not is_win or getattr(err, "winerror", None) != 1314:
            raise
    # Windows fallback (no symlink privilege)
    cmd = ["cmd", "/c", "mklink"]
    if target.is_dir():
        cmd += ["/J"]  # junction
    else:
        cmd += ["/H"]  # hard‑link
    cmd += [str(link), str(target)]
    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as e:
        raise RuntimeError("mklink failed — enable Developer Mode or run as Admin") from e


# ---- .git/info/exclude handling ----------------------------------

def add_to_exclude(exclude: pathlib.Path, rel: str) -> None:
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.touch(exist_ok=True)
    with exclude.open() as f:
        if rel in {ln.rstrip() for ln in f}:
            return
    with exclude.open("a") as f:
        f.write(rel + "\n")
    print(f"· Added to info/exclude: {rel}")


# ---- git index cleanup -------------------------------------------

def remove_from_index(rel: str) -> None:
    """If path is tracked, git rm --cached (-r) it."""
    ls = run_git("ls-files", "--error-unmatch", rel)
    if ls.returncode == 0:
        rm = run_git("rm", "--cached", "-r", "--", rel)
        if rm.returncode == 0:
            print(f"· Removed from index: {rel}")
        else:
            print(rm.stderr, file=sys.stderr)


# ---- list of targets ---------------------------------------------

def read_list_file(rroot: pathlib.Path) -> List[str]:
    fp = rroot / LIST_FILE
    if not fp.exists():
        return []
    with fp.open() as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.lstrip().startswith("#")]


def get_targets(rroot: pathlib.Path) -> List[str]:
    if len(sys.argv) > 1:
        return sys.argv[1:]
    paths = read_list_file(rroot)
    if paths:
        print(f"No CLI paths — using {LIST_FILE} ({len(paths)} entries)")
        return paths
    print("Error: no paths given and no list file found.")
    sys.exit(1)


# ---- main per‑file process ---------------------------------------

def process_one(rel: str, rroot: pathlib.Path, exclude: pathlib.Path):
    path = rroot / rel
    variant = path.with_name(path.name + SUFFIX)

    if variant.exists() and not path.is_symlink():
        make_link(variant, path)
        print(f"Symlink created: {rel} → {rel}{SUFFIX}")
    elif path.exists() and not variant.exists():
        path.rename(variant)
        make_link(variant, path)
        print(f"Moved and linked: {rel} → {rel}{SUFFIX}")
    else:
        print(f"✓ Nothing to do for {rel}")

    add_to_exclude(exclude, rel)
    remove_from_index(rel)


# ---- main ---------------------------------------------------------

def main():
    root = repo_root()
    os.chdir(root)
    exclude = exclude_path()

    targets = get_targets(root)
    for rel in targets:
        process_one(rel, root, exclude)

    if targets:
        joined = " ".join(f"'{t}{SUFFIX}'" for t in targets)
        print(f"\nDone. Remember to: git add {joined} && git commit -m 'yadm variants'")

if __name__ == "__main__":
    main()
