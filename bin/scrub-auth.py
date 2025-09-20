#!/usr/bin/env python3
"""Scrub authentication traces before distributing a machine image."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence

MODULE_ORDER = ["docker", "gh", "git", "shell", "libsecret", "extra"]

EXTRA_RM_PATHS = [
    "~/.gitconfig.local",
    "~/.local/share/marks/marks.sqlite",
    # "~/.cache/my-app",
]

LIBSECRET_CLEAR_RULES = [
    "service=git",
    "service=git;host=github.com",
    "service=git;host=gitlab.com",
    "service=git;host=bitbucket.org",
    "service=git;protocol=https",
    "service=https://index.docker.io/v1/",
    "service=registry-1.docker.io",
    "service=gh",
    "xdg:schema=org.freedesktop.Secret.Generic;service=git",
]

NETRC_HOST_PREFIXES = ("github.", "gitlab.", "bitbucket.")

HOME = Path.home()
SHRED = shutil.which("shred")

_sections_printed = 0


class Palette:
    def __init__(self, enabled: bool) -> None:
        if enabled:
            self.reset = "\033[0m"
            self.info = "\033[36m"
            self.ok = "\033[32m"
            self.warn = "\033[33m"
            self.error = "\033[31m"
            self.header = "\033[35m"
            self.bold = "\033[1m"
        else:
            self.reset = ""
            self.info = ""
            self.ok = ""
            self.warn = ""
            self.error = ""
            self.header = ""
            self.bold = ""


palette = Palette(False)


def log(message: str = "") -> None:
    print(message, file=sys.stderr)


def info(message: str) -> None:
    print(f"{palette.info}[INFO]{palette.reset} {message}", file=sys.stderr)


def ok(message: str) -> None:
    print(f"{palette.ok}[ OK ]{palette.reset} {message}", file=sys.stderr)


def warn(message: str) -> None:
    print(f"{palette.warn}[WARN]{palette.reset} {message}", file=sys.stderr)


def error(message: str) -> None:
    print(f"{palette.error}[ERR ]{palette.reset} {message}", file=sys.stderr)


def section(title: str) -> None:
    global _sections_printed
    prefix = "\n" if _sections_printed else ""
    print(f"{prefix}{palette.header}{palette.bold}== {title} =={palette.reset}", file=sys.stderr)
    _sections_printed += 1


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def run(
    cmd: Sequence[str],
    *,
    capture_output: bool = False,
    check: bool = False,
) -> Optional[subprocess.CompletedProcess]:
    try:
        return subprocess.run(cmd, check=check, capture_output=capture_output, text=True)
    except FileNotFoundError:
        return None
    except Exception as exc:
        warn(f"Failed to run {' '.join(cmd)}: {exc}")
        return None


def backup_file(src: Path, suffix: str = "bak") -> Optional[Path]:
    if not src.exists():
        return None
    timestamp = time.strftime("%Y%m%d%H%M%S")
    dest = Path(f"{src}.{suffix}.{timestamp}")
    try:
        shutil.copy2(src, dest)
    except Exception as exc:
        warn(f"Unable to back up {src}: {exc}")
        return None
    return dest


def read_json(path: Path) -> Optional[Dict[str, object]]:
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except Exception as exc:
        warn(f"Unable to read {path}: {exc}")
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        warn(f"Unable to parse {path}: {exc}")
        return None
    if not isinstance(data, dict):
        warn(f"{path} does not contain a JSON object")
        return None
    return data


def safe_unlink(path: Path) -> None:
    try:
        path.unlink()
    except FileNotFoundError:
        return
    except OSError as exc:
        warn(f"Unable to remove {path}: {exc}")


def secure_delete(path: Path) -> None:
    if path.is_dir():
        try:
            shutil.rmtree(path)
        except FileNotFoundError:
            return
        except OSError as exc:
            warn(f"Unable to remove directory {path}: {exc}")
        return
    if SHRED:
        proc = run([SHRED, "-u", str(path)])
        if proc and proc.returncode == 0:
            return
    safe_unlink(path)


def docker_audit() -> None:
    cfg = HOME / ".docker" / "config.json"
    if not cfg.exists():
        ok("Docker: no config.json file")
        return
    info(f"Docker config found at {cfg}")
    data = read_json(cfg)
    if not data:
        warn("Docker: unable to inspect config.json")
        return
    auths = data.get("auths")
    registries: List[str] = []
    if isinstance(auths, dict):
        registries = sorted(k for k in auths if isinstance(k, str) and k)
    if registries:
        warn("Docker auth entries detected:")
        for reg in registries:
            log(f"  - {reg}")
    else:
        ok("No Docker auth entries")
    if any(key in data for key in ("credsStore", "credHelpers")):
        warn("Docker credsStore or credHelpers configured")
    else:
        ok("No Docker credsStore or credHelpers configured")


def docker_clean() -> None:
    cfg = HOME / ".docker" / "config.json"
    data = read_json(cfg) if cfg.exists() else None
    registries: List[str] = []
    if data and isinstance(data.get("auths"), dict):
        registries = sorted(k for k in data["auths"] if isinstance(k, str) and k)
    if registries:
        if command_exists("docker"):
            for reg in registries:
                info(f"docker logout {reg}")
                run(["docker", "logout", reg])
        else:
            warn("Docker CLI not available; cannot logout registries")
    backup = backup_file(cfg)
    if backup:
        info(f"Docker: backup created at {backup}")
    if not data:
        if cfg.exists():
            warn("Docker: removing config.json (invalid or unreadable)")
            safe_unlink(cfg)
    else:
        for key in ("auths", "credsStore", "credHelpers"):
            data.pop(key, None)
        try:
            cfg.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        except Exception as exc:
            warn(f"Docker: unable to write config.json: {exc}")
        else:
            ok("Docker: removed auth/credsStore/credHelpers sections")
    token_seed = HOME / ".docker" / ".token_seed"
    safe_unlink(token_seed)


def gh_hosts() -> List[str]:
    hosts_file = HOME / ".config" / "gh" / "hosts.yml"
    if not hosts_file.exists():
        return []
    hosts: List[str] = []
    try:
        for line in hosts_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            if not line or line.lstrip() != line:
                continue
            if line.startswith("#"):
                continue
            host = line.split(":", 1)[0].strip()
            if host:
                hosts.append(host)
    except Exception as exc:
        warn(f"gh: unable to parse hosts.yml ({exc})")
    return sorted(dict.fromkeys(hosts))


def gh_audit() -> None:
    hosts_file = HOME / ".config" / "gh" / "hosts.yml"
    if hosts_file.exists():
        info(f"gh hosts file found at {hosts_file}")
    else:
        ok("gh: no hosts.yml file")
    hosts = gh_hosts()
    if "github.com" not in hosts:
        hosts.append("github.com")
    hosts = sorted(dict.fromkeys(hosts))
    if not hosts:
        ok("gh: no known hosts to inspect")
        return
    if not command_exists("gh"):
        warn("gh CLI not available; skipping authentication status checks")
        return
    for host in hosts:
        proc = run(["gh", "auth", "status", "-h", host])
        if proc and proc.returncode == 0:
            warn(f"gh authenticated against {host}")
        else:
            ok(f"gh not authenticated against {host}")


def gh_clean() -> None:
    hosts = gh_hosts()
    if "github.com" not in hosts:
        hosts.append("github.com")
    hosts = list(dict.fromkeys(hosts))
    if hosts and command_exists("gh"):
        for host in hosts:
            info(f"gh auth logout -h {host}")
            run(["gh", "auth", "logout", "-h", host, "--hostname", host, "--confirm"])
    elif hosts:
        warn("gh CLI not available; cannot logout hosts")
    hosts_file = HOME / ".config" / "gh" / "hosts.yml"
    if hosts_file.exists():
        backup = backup_file(hosts_file)
        if backup:
            info(f"gh: backup created at {backup}")
        try:
            hosts_file.write_text("", encoding="utf-8")
        except Exception as exc:
            warn(f"gh: unable to clear hosts.yml ({exc})")
        else:
            ok("gh: hosts.yml cleared")


def git_audit() -> None:
    if command_exists("git"):
        proc = run(["git", "config", "--global", "--get-all", "credential.helper"], capture_output=True)
        helpers: List[str] = []
        if proc and proc.stdout:
            helpers = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
        if helpers:
            warn("git: global credential.helper entries found:")
            for helper in helpers:
                log(f"  - {helper}")
        else:
            ok("git: no global credential.helper")
    else:
        warn("git command not available; skipping credential helper inspection")
    git_credentials = HOME / ".git-credentials"
    if git_credentials.exists():
        warn("git: ~/.git-credentials present")
    else:
        ok("git: no ~/.git-credentials file")
    gitconfig_local = HOME / ".gitconfig.local"
    if gitconfig_local.exists():
        warn("git: ~/.gitconfig.local present")
    else:
        ok("git: no ~/.gitconfig.local file")
    netrc = HOME / ".netrc"
    if netrc.exists():
        try:
            data = netrc.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:
            warn(f"netrc: unable to read ~/.netrc ({exc})")
        else:
            if re.search(r"(?im)^machine\s+(github|gitlab|bitbucket)\.", data):
                warn("netrc: git related machine entries detected")
            else:
                ok("netrc: no github/gitlab/bitbucket entries")
    else:
        ok("netrc: no ~/.netrc file")


def scrub_netrc(content: str) -> str:
    lines = content.splitlines()
    result: List[str] = []
    skip = False
    for line in lines:
        stripped = line.strip()
        if stripped.lower().startswith("machine "):
            parts = stripped.split()
            if len(parts) >= 2:
                host = parts[1].lower()
                if any(host.startswith(prefix) for prefix in NETRC_HOST_PREFIXES):
                    skip = True
                    continue
        if skip:
            if stripped == "":
                skip = False
            continue
        result.append(line)
    cleaned = "\n".join(result)
    if content.endswith("\n"):
        cleaned += "\n"
    return cleaned


def git_clean() -> None:
    if command_exists("git"):
        info("git: removing global credential.helper entries")
        run(["git", "config", "--global", "--unset-all", "credential.helper"])
        run(["git", "credential-cache", "exit"])
    else:
        warn("git command not available; skipping credential.helper cleanup")
    git_credentials = HOME / ".git-credentials"
    if git_credentials.exists():
        backup = backup_file(git_credentials)
        if backup:
            info(f"git: backup created at {backup}")
        secure_delete(git_credentials)
        ok("git: ~/.git-credentials removed")
    gitconfig_local = HOME / ".gitconfig.local"
    if gitconfig_local.exists():
        backup = backup_file(gitconfig_local)
        if backup:
            info(f"git: backup created at {backup}")
        secure_delete(gitconfig_local)
        ok("git: ~/.gitconfig.local removed")
    netrc = HOME / ".netrc"
    if netrc.exists():
        backup = backup_file(netrc)
        if backup:
            info(f"netrc: backup created at {backup}")
        try:
            original = netrc.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:
            warn(f"netrc: unable to read ~/.netrc ({exc})")
        else:
            cleaned = scrub_netrc(original)
            if cleaned == original:
                ok("netrc: no github/gitlab/bitbucket entries to remove")
            else:
                try:
                    netrc.write_text(cleaned, encoding="utf-8")
                except Exception as exc:
                    warn(f"netrc: unable to write ~/.netrc ({exc})")
                else:
                    ok("netrc: github/gitlab/bitbucket entries removed")


def shell_audit() -> None:
    history_files = [
        ("bash", HOME / ".bash_history"),
        ("zsh", HOME / ".zsh_history"),
        ("zsh", HOME / ".zhistory"),
    ]
    for label, path in history_files:
        if path.exists():
            warn(f"{label}: {path.name} present")
        else:
            ok(f"{label}: no {path.name} file")


def shell_clean() -> None:
    for path in [HOME / ".bash_history", HOME / ".zsh_history", HOME / ".zhistory"]:
        if path.exists():
            info(f"shell: removing {path}")
            secure_delete(path)
    os.environ.pop("HISTFILE", None)


def libsecret_audit() -> None:
    if not command_exists("secret-tool"):
        warn("libsecret: secret-tool not available; skipping audit")
        return
    info("libsecret: checking common credentials")
    proc = run(["secret-tool", "lookup", "service", "git", "host", "github.com"])
    if proc and proc.returncode == 0:
        warn("libsecret: git/github.com entry found")
    else:
        ok("libsecret: no git/github.com entry detected")
    proc = run(["secret-tool", "lookup", "service", "https://index.docker.io/v1/"])
    if proc and proc.returncode == 0:
        warn("libsecret: dockerhub entry found")
    else:
        ok("libsecret: no dockerhub entry detected")

def libsecret_clean() -> None:
    if not command_exists("secret-tool"):
        warn("libsecret: secret-tool not available; skipping cleanup")
        return
    info("libsecret: applying cleanup rules")
    for rule in LIBSECRET_CLEAR_RULES:
        parts = [segment for segment in rule.split(";") if segment]
        args: List[str] = []
        for segment in parts:
            key, _, value = segment.partition("=")
            if key and value:
                args.extend([key, value])
        if args:
            run(["secret-tool", "clear", *args])
    ok("libsecret: cleanup rules executed")


def expand_path(path_str: str) -> Path:
    return Path(os.path.expandvars(path_str)).expanduser()


def extra_audit() -> None:
    found = False
    for path_str in EXTRA_RM_PATHS:
        path = expand_path(path_str)
        if path.exists():
            warn(f"extra: path present -> {path}")
            found = True
    if not found:
        ok("extra: no additional paths present")


def extra_clean() -> None:
    for path_str in EXTRA_RM_PATHS:
        path = expand_path(path_str)
        if path.exists():
            info(f"extra: removing {path}")
            secure_delete(path)


def final_checks() -> None:
    section("FINAL CHECKS")
    docker_cfg = HOME / ".docker" / "config.json"
    if docker_cfg.exists():
        data = read_json(docker_cfg)
        if not data:
            warn("Docker: unable to inspect config.json")
        elif any(key in data for key in ("auths", "credsStore", "credHelpers")):
            warn("Docker: credentials still present in config.json")
        else:
            ok("Docker: config.json clean")
    else:
        ok("Docker: no config.json file")
    if command_exists("gh"):
        proc = run(["gh", "auth", "status", "-h", "github.com"])
        if proc and proc.returncode == 0:
            warn("gh: still authenticated with github.com")
        else:
            ok("gh: not authenticated with github.com")
    else:
        warn("gh CLI not available; skipped status check")
    if command_exists("git"):
        proc = run(["git", "config", "--global", "--get-all", "credential.helper"], capture_output=True)
        helpers = []
        if proc and proc.stdout:
            helpers = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
        if helpers:
            warn("git: credential.helper entries still configured")
        else:
            ok("git: no global credential.helper")
    else:
        warn("git command not available; skipped credential helper check")
    for path, label in [
        (HOME / ".git-credentials", "git: ~/.git-credentials"),
        (HOME / ".gitconfig.local", "git: ~/.gitconfig.local"),
        (HOME / ".bash_history", "bash history"),
        (HOME / ".zsh_history", "zsh history"),
    ]:
        if path.exists():
            warn(f"{label} still present")
        else:
            ok(f"{label} not present")




@dataclass(frozen=True)
class Module:
    name: str
    description: str
    audit: Callable[[], None]
    clean: Callable[[], None]


MODULES: Dict[str, Module] = {
    "docker": Module("docker", "Docker configuration and tokens", docker_audit, docker_clean),
    "gh": Module("gh", "GitHub CLI authentication", gh_audit, gh_clean),
    "git": Module("git", "Git credentials and helpers", git_audit, git_clean),
    "shell": Module("shell", "Shell history files", shell_audit, shell_clean),
    "libsecret": Module("libsecret", "GNOME keyring entries", libsecret_audit, libsecret_clean),
    "extra": Module("extra", "Custom extra paths", extra_audit, extra_clean),
}


def parse_module_list(value: str) -> List[str]:
    items: List[str] = []
    for raw in value.split(","):
        name = raw.strip().lower()
        if not name:
            continue
        if name not in MODULES:
            raise argparse.ArgumentTypeError(f"Unknown module: {name}")
        if name not in items:
            items.append(name)
    if not items:
        raise argparse.ArgumentTypeError("Module list cannot be empty")
    return items


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scrub authentication artifacts across several tools.",
    )
    parser.set_defaults(mode="audit")
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--audit",
        dest="mode",
        action="store_const",
        const="audit",
        help="Run in audit mode (default)",
    )
    mode_group.add_argument(
        "--clean",
        dest="mode",
        action="store_const",
        const="clean",
        help="Run in cleanup mode",
    )
    parser.add_argument(
        "--only",
        type=parse_module_list,
        help="Comma separated list of modules to run",
        metavar="MODULES",
    )
    parser.add_argument(
        "--skip",
        type=parse_module_list,
        help="Comma separated list of modules to skip",
        metavar="MODULES",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colors in the output",
    )
    parser.add_argument(
        "--list-modules",
        action="store_true",
        help="List supported modules and exit",
    )
    return parser.parse_args(argv)


def select_modules(only: Optional[List[str]], skip: Optional[List[str]]) -> List[str]:
    if only:
        selected = only[:]
    else:
        selected = MODULE_ORDER[:]
    if skip:
        skip_set = set(skip)
        selected = [name for name in selected if name not in skip_set]
    if not selected:
        raise ValueError("No module selected to run")
    return selected


def list_modules() -> None:
    for name in MODULE_ORDER:
        module = MODULES[name]
        print(f"{module.name:10s} {module.description}")


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    if args.list_modules:
        list_modules()
        return 0
    global palette, _sections_printed
    palette = Palette(enabled=not args.no_color and sys.stderr.isatty())
    _sections_printed = 0
    try:
        selected = select_modules(args.only, args.skip)
    except ValueError as exc:
        print(f"scrub-auth: {exc}", file=sys.stderr)
        return 2
    section(f"MODE {args.mode.upper()}")
    if args.mode == "audit":
        log("No change will be applied.")
    else:
        log("Cleanup actions will be applied.")
    for name in selected:
        module = MODULES[name]
        section(f"{module.name.upper()} ({args.mode.upper()})")
        handler = module.audit if args.mode == "audit" else module.clean
        try:
            handler()
        except KeyboardInterrupt:
            raise
        except Exception as exc:
            error(f"{module.name}: {exc}")
    final_checks()
    return 0


if __name__ == "__main__":
    sys.exit(main())
