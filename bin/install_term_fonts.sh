#!/usr/bin/env bash
set -Eeuo pipefail

# Installe FiraCode & FiraMono Nerd Fonts v3.4.0 (user ou system), en minimisant les appels à apt.
# Usage:
#   ./install-fira-nerdfonts.sh           # installation utilisateur (~/.local/share/fonts)
#   ./install-fira-nerdfonts.sh --system  # installation système (/usr/local/share/fonts) (sudo requis)
# Personnalisation des URLs (miroir interne possible) :
#   NF_URL_FIRACODE="https://..." NF_URL_FIRAMONO="https://..." ./install-fira-nerdfonts.sh

# --- Config des sources ---
declare -A FONTS=(
  [FiraCode]="${NF_URL_FIRACODE:-https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip}"
  [FiraMono]="${NF_URL_FIRAMONO:-https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraMono.zip}"
)

MODE="user"
if [[ "${1:-}" == "--system" ]]; then
  MODE="system"
fi

# --- Couleurs (désactivables avec NO_COLOR=1) ---
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"
  RED="$(printf '\033[31m')"; GREEN="$(printf '\033[32m')"; YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"
  RESET="$(printf '\033[0m')"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi
info () { printf "%b%s%b\n" "$BLUE" "$*" "$RESET"; }
ok   () { printf "%b%s%b\n" "$GREEN" "$*" "$RESET"; }
warn () { printf "%b%s%b\n" "$YELLOW" "$*" "$RESET"; }
err  () { printf "%b%s%b\n" "$RED" "$*" "$RESET" >&2; }

# Escalade si --system sans privilèges
if [[ "$MODE" == "system" && $EUID -ne 0 ]]; then
  warn "Mode système demandé : relance automatique avec sudo…"
  exec sudo --preserve-env=NF_URL_FIRACODE,NF_URL_FIRAMONO "$0" --system
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Binaire -> paquet apt
declare -A REQS=(
  [unzip]=unzip
  [curl]=curl
  [fc-cache]=fontconfig
  [fc-list]=fontconfig
)

# Détection manquants et installation groupée
missing_pkgs=()
for bin in "${!REQS[@]}"; do
  if ! need_cmd "$bin"; then
    pkg="${REQS[$bin]}"
    [[ " ${missing_pkgs[*]-} " =~ " ${pkg} " ]] || missing_pkgs+=("$pkg")
  fi
done

if ((${#missing_pkgs[@]})); then
  if ! need_cmd apt-get; then
    err "Paquets manquants (${missing_pkgs[*]}) et apt-get indisponible. Installez-les puis relancez."
    exit 1
  fi
  if [[ $EUID -ne 0 ]]; then
    info "Installation des dépendances via sudo apt-get : ${missing_pkgs[*]}"
    sudo apt-get update -y -qq
    sudo apt-get install -y -qq "${missing_pkgs[@]}"
  else
    info "Installation des dépendances via apt-get : ${missing_pkgs[*]}"
    apt-get update -y -qq
    apt-get install -y -qq "${missing_pkgs[@]}"
  fi
fi

# Dossiers
if [[ "$MODE" == "system" ]]; then
  DEST_BASE="/usr/local/share/fonts/nerd-fonts"
else
  DEST_BASE="$HOME/.local/share/fonts/nerd-fonts"
fi
mkdir -p "$DEST_BASE"

# Téléchargement temporaire
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

install_font() {
  local name="$1" url="$2"
  local dest="$DEST_BASE/$name"
  local zip="$TMP/${name}.zip"

  info "Téléchargement ${name} : $url"
  curl -fL --retry 3 -o "$zip" "$url"

  info "Décompression ${name} → $dest"
  mkdir -p "$dest"
  unzip -o "$zip" -d "$dest" >/dev/null
}

# Installer FiraCode + FiraMono
for n in "${!FONTS[@]}"; do
  install_font "$n" "${FONTS[$n]}"
done

# Reconstruction du cache
info "Reconstruction du cache de polices"
if [[ "$MODE" == "system" ]]; then
  fc-cache -f
else
  fc-cache -f "$HOME/.local/share/fonts" || fc-cache -f
fi

# Vérifications robustes
FOUND=0
# 1) Familles "Mono" (terminal)
if fc-list | grep -iqE "Fira(Code|Mono) Nerd Font Mono"; then
  FOUND=1
# 2) Familles générales
elif fc-list | grep -iqE "Fira(Code|Mono) Nerd Font"; then
  FOUND=1
# 3) Présence fichiers
elif find "$DEST_BASE" -type f -iname "Fira*.ttf" | grep -q .; then
  FOUND=1
fi

if [[ $FOUND -eq 1 ]]; then
  ok "FiraCode & FiraMono Nerd Fonts installées."
  printf "%b%s%b\n" "$DIM" "Terminator → Profil → Police :" "$RESET"
  printf "%b%s%b\n" "$DIM" "  - Sans ligatures : « FiraMono Nerd Font Mono » (Regular)" "$RESET"
  printf "%b%s%b\n" "$DIM" "  - Avec ligatures : « FiraCode Nerd Font Mono » (Regular)" "$RESET"
else
  warn "Polices Nerd Fira non trouvées."
  printf "%b%s%b\n" "$DIM" "Vérifie $DEST_BASE et relance « fc-cache -f ». Une reconnexion de session peut aider." "$RESET"
fi
