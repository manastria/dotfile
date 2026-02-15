# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A **yadm-managed dotfiles** repository (github.com/manastria/dotfile) for Linux (Debian/Ubuntu). It contains shell configurations (bash + zsh), git settings, vim, tmux, terminal emulators, and utility scripts. The repo is designed to be cloned with `yadm clone --recurse-submodules` directly into `$HOME`.

## Repository Management

This repo uses **yadm** (Yet Another Dotfiles Manager), a git wrapper that manages dotfiles in-place from `$HOME`. Operate with `yadm` commands (yadm add, yadm commit, yadm push) rather than raw git when deploying. For development/editing in this checked-out copy, standard git works fine.

Submodules (defined in `.gitmodules`) are all zsh-related: oh-my-zsh, powerlevel10k, zsh-autosuggestions, zsh-completions, zsh-syntax-highlighting, zsh-vi-mode, zsh-dircolors-solarized. Update them with `yadm submodule update --init --recursive` or the `bin/yadm_check_submodules.sh` script.

## Architecture

### Shell Configuration Loading Order

**Bash** (`.bashrc`):
1. Sources `/etc/bashrc`
2. Sources all `~/.shellrc/bashrc.d/*.bash` files (bash-specific: preexec, prompt, aliases, lscolor, direnv, atuin)
3. Sources all `~/.shellrc/rc.d/*.sh` files (POSIX-compatible, shared with zsh: aliases, variables, ssh-agent, pyenv, pipx, npm)
4. Sources `~/.bash_aliases` (user-local, gitignored)

**Zsh** (`.zshrc`):
1. Sources `~/.zsh/before_compinit.d/**/*.zsh`
2. Selects profile via `$ZSH_PROFILE` env var: `omz` (oh-my-zsh), `omzp10*` (oh-my-zsh + powerlevel10k), `base` (minimal)
3. Sources all `~/.shellrc/zshrc.d/**/*.zsh` files (path, alias, tmux, fzf, history, options, keybinds, direnv)
4. Sources all `~/.shellrc/rc.d/*.sh` files (same shared scripts as bash)
5. Sources `~/.fzf.zsh`

### Key Directories

- **`.shellrc/rc.d/`** - POSIX shell scripts shared by bash and zsh (`.sh` extension)
- **`.shellrc/bashrc.d/`** - Bash-only scripts (`.bash` extension)
- **`.shellrc/zshrc.d/`** - Zsh-only scripts (`.zsh` extension)
- **`bin/`** - Utility scripts: package installation (`install_paquets.sh`), software installers (starship, docker, atuin, vscode, etc.), system management
- **`src/`** - Third-party tools (git-subrepo)
- **`.config/yadm/alt/`** - Yadm alternate files with `##os.None` suffix, symlinked to `$HOME` (`.editorconfig`, `.vscode`, `.gitignore`)

### Gitignored Local Files

- **`.bash_aliases`** - User-local bash aliases (copy from `.bash_aliases.dist` template)
- **`.gitconfig.local`** - User-local git config (see `.gitconfig.local.sample`), included by `.gitconfig`

### Git Configuration

`.gitconfig` includes `.gitconfig_alias` (extensive alias library) and `.gitconfig.local` (user identity). Notable settings: no fast-forward merges (`merge.ff = no`), pull with ff-only (`pull.ff = only`), default branch is `master`.

## Code Conventions

- EditorConfig: 4 spaces indentation, UTF-8. Shell files (`.sh`, `.zsh`) must have LF line endings and a final newline.
- Shell scripts use `#!/bin/bash` with `set -e`. Comments and UI messages are in **French**.
- Alias definitions go in `.shellrc/rc.d/alias.sh` (shared), `.shellrc/bashrc.d/10_alias.bash` (bash-only), or `.shellrc/zshrc.d/02_alias.zsh` (zsh-only). Functions belong in the corresponding `.shellrc/` subdirectory, not in alias files.
- Git aliases go in `.gitconfig_alias`.
