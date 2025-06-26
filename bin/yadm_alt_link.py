#!/usr/bin/env python3
"""
yadm_alt_link.py — manage yadm alternates and dev symlinks (Linux ⁄ macOS ⁄ WSL ⁄ Windows).

Two modes, chosen automatically:
1. Variant already present → create the working‑name symlink + add to .git/info/exclude.
2. Real file present, variant missing → move to <name>##os.None, create symlink, add exclude.

If *no* path is passed on the command‑line, the script reads the list from
.repo_root/.config/yadm/alt-link-list.txt (one path per line, “#” and blank lines ignored).

Usage examples
--------------
• python yadm_alt_link.py .editorconfig .vscode
• python yadm_alt_link.py          # will read alt-link-list.txt

Prerequisites on Windows
------------------------
• Developer Mode *or* run the terminal as Administrator (to allow symlinks).
• In Git for Windows: git config --global core.symlinks true
"""
import os
import sys
import subprocess
import pathlib
import platform

SUFFIX = "##os.None"
LIST_FILE = pathlib.PurePosixPath(".config/yadm/alt-link-list.txt")

# --- helpers -------------------------------------------------------

def repo_root() -> pathlib.Path:
    return pathlib.Path(
        subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    )

def exclude_path() -> pathlib.Path:
    return pathlib.Path(
        subprocess.check_output(["git", "rev-parse", "--git-path", "info/exclude"], text=True).strip()
    )

def make_link(target: pathlib.Path, link: pathlib.Path) -> None:
    """Create a symlink (works on Windows & *nix, falls back to 'mklink')."""
    try:
        os.symlink(target, link, target_is_directory=target.is_dir())
    except OSError:
        if platform.system() == "Windows":
            args = ["cmd", "/c", "mklink"]
            if target.is_dir():
                args.append("/D")
            args += [str(link), str(target)]
            subprocess.check_call(args, stdout=subprocess.DEVNULL)
        else:
            raise

def add_to_exclude(exclude: pathlib.Path, relative: str) -> None:
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.touch(exist_ok=True)
    with exclude.open() as f:
        if any(line.rstrip("\n") == relative for line in f):
            return  # already there
    with exclude.open("a") as f:
        f.write(relative + "\n")
        print(f"· Added to info/exclude: {relative}")

# --- main logic ----------------------------------------------------

def get_targets(rroot: pathlib.Path) -> list[str]:
    if len(sys.argv) > 1:
        return sys.argv[1:]
    list_file = rroot / LIST_FILE
    if list_file.exists():
        with list_file.open() as f:
            lines = [ln.strip() for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
        if lines:
            print(f"No CLI paths — using {LIST_FILE} ({len(lines)} entries)")
            return lines
    print("Error: no paths given and no list file found.")
    sys.exit(1)


def process_one(path_rel: str, rroot: pathlib.Path, exclude: pathlib.Path):
    path = rroot / path_rel
    variant = path.with_name(path.name + SUFFIX)

    if variant.exists() and not path.is_symlink():
        make_link(variant, path)
        print(f"Symlink created: {path_rel} → {path_rel}{SUFFIX}")
    elif path.exists() and not variant.exists():
        path.rename(variant)
        make_link(variant, path)
        print(f"Moved then linked: {path_rel} → {path_rel}{SUFFIX}")
    else:
        print(f"✓ Nothing to do for {path_rel}")

    add_to_exclude(exclude, path_rel)


def main():
    rroot = repo_root()
    os.chdir(rroot)
    exclude = exclude_path()

    targets = get_targets(rroot)
    for rel in targets:
        process_one(rel, rroot, exclude)

    # advice for committing
    joined = " ".join(f"'{t}{SUFFIX}'" for t in targets)
    print(f"\nDone. Remember to: git add {joined} && git commit -m 'yadm variants'")

if __name__ == "__main__":
    main()
