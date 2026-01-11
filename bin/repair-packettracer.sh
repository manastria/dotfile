#!/usr/bin/env bash
set -euo pipefail

# repair-packettracer.sh
# Répare l’intégration desktop de Packet Tracer (menu + icône) et affiche la version détectée.

DESKTOP_SYS="/usr/share/applications/packettracer.desktop"
ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
ICON_SYS="${ICON_DIR}/packettracer.png"
LINK_CMD="/usr/local/bin/packettracer"

PT_APPIMAGE="/opt/pt/packettracer.AppImage"
PT_DIR="/opt/pt"

FIX_ALL_USERS=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  sudo ./repair-packettracer.sh [options]

Options:
  --fix-all-users   Répare aussi les lanceurs utilisateurs (~/.local/...) pour tous les comptes /home/*
  --dry-run         Affiche ce qui serait fait sans modifier le système
  -h, --help        Aide

EOF
}

log() { printf "%s\n" "$*"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "Erreur: ce script doit être lancé en root (sudo)."
    exit 1
  fi
}

# Détecter la version installée (si paquet dpkg présent)
dpkg_version() {
  dpkg-query -W -f='${Version}\n' packettracer 2>/dev/null || true
}

# Trouver un exécutable Packet Tracer (priorité à l’AppImage Cisco /opt/pt)
detect_exec() {
  # 1) AppImage Cisco
  if [[ -f "$PT_APPIMAGE" ]]; then
    echo "$PT_APPIMAGE"
    return 0
  fi

  # 2) Executable dans /opt/pt
  for p in \
    "$PT_DIR/packettracer" \
    "$PT_DIR/bin/packettracer" \
    "$PT_DIR/bin/PacketTracer" \
    "$PT_DIR/PacketTracer"; do
    if [[ -x "$p" ]]; then
      echo "$p"
      return 0
    fi
  done

  # 3) Commande déjà présente
  if command -v packettracer >/dev/null 2>&1; then
    command -v packettracer
    return 0
  fi

  # 4) Recherche légère (sans parcourir tout le disque)
  local found
  found="$(find /opt -maxdepth 4 -type f -executable -iname "*packet*tracer*" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$found" ]]; then
    echo "$found"
    return 0
  fi

  echo ""
  return 0
}

# Extraire l’AppImage dans un tmpdir si dispo (pour icône + version alternative)
extract_appimage() {
  local tmpdir="$1"
  run "mkdir -p '$tmpdir'"
  run "chmod +x '$PT_APPIMAGE'"
  ( cd "$tmpdir" && "$PT_APPIMAGE" --appimage-extract >/dev/null 2>&1 ) || true
}

# Détecter une version via le .desktop contenu dans l’AppImage
appimage_version_from_desktop() {
  local tmpdir="$1"
  local d
  d="$(find "$tmpdir/squashfs-root" -maxdepth 2 -type f -name 'CiscoPacketTracer-*.desktop' 2>/dev/null | head -n 1 || true)"
  if [[ -n "$d" ]]; then
    # Exemple: CiscoPacketTracer-9.0.0.desktop -> 9.0.0
    basename "$d" | sed -E 's/^CiscoPacketTracer-([0-9.]+)\.desktop$/\1/'
  else
    echo ""
  fi
}

# Installer une icône depuis l’AppImage (chemin connu) ou fallback
install_icon() {
  if [[ -f "$PT_APPIMAGE" ]]; then
    local tmpdir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "'"$tmpdir"'"' EXIT

    extract_appimage "$tmpdir"

    local icon_src="$tmpdir/squashfs-root/opt/pt/art/app.png"
    if [[ -f "$icon_src" ]]; then
      run "install -d '$ICON_DIR'"
      run "install -m 644 '$icon_src' '$ICON_SYS'"
      log "Icône installée: $ICON_SYS"
      return 0
    fi

    # Fallback: prendre la première image plausible
    local fallback
    fallback="$(find "$tmpdir/squashfs-root" -maxdepth 4 -type f \( -iname '*.png' -o -iname '*.svg' \) 2>/dev/null \
      | grep -Ei 'app\.png|icon|packet|pt|cisco' | head -n 1 || true)"
    if [[ -n "$fallback" && -f "$fallback" ]]; then
      run "install -d '$ICON_DIR'"
      # on convertit pas: on copie tel quel si PNG, sinon on laisse tomber (icône générique)
      if [[ "${fallback,,}" == *.png ]]; then
        run "install -m 644 '$fallback' '$ICON_SYS'"
        log "Icône installée (fallback): $ICON_SYS"
        return 0
      fi
    fi

    log "Note: aucune icône exploitable trouvée dans l’AppImage (menu OK, icône générique possible)."
    return 0
  fi

  # Si pas d’AppImage, tenter un fallback système (pixmaps)
  if [[ -f /usr/share/pixmaps/packettracer.png ]]; then
    run "install -d '$ICON_DIR'"
    run "install -m 644 /usr/share/pixmaps/packettracer.png '$ICON_SYS'"
    log "Icône installée depuis pixmaps: $ICON_SYS"
    return 0
  fi

  log "Note: aucune icône trouvée (menu OK, icône générique possible)."
}

# Créer le lanceur système
write_system_desktop() {
  local exec_cmd="$1"

  # On préfère Exec=packettracer (commande) en créant un lien /usr/local/bin/packettracer vers la cible si c’est un chemin
  if [[ "$exec_cmd" == /* && -e "$exec_cmd" ]]; then
    run "ln -sf '$exec_cmd' '$LINK_CMD'"
    exec_cmd="packettracer"
  else
    # Exec est déjà une commande; on l’utilise telle quelle
    :
  fi

  run "tee '$DESKTOP_SYS' >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Packet Tracer
Comment=Cisco Packet Tracer
Exec=${exec_cmd}
Icon=packettracer
Terminal=false
Categories=Education;
StartupNotify=true
EOF"
  log "Lanceur système écrit: $DESKTOP_SYS"
}

# Si un lanceur utilisateur cassé existe, il peut “masquer” le lanceur système (certaines implémentations de menu préfèrent ~/.local/)
# Par défaut: on corrige l’utilisateur SUDO_USER. Option: --fix-all-users pour /home/*
fix_user_desktop_for_home() {
  local home="$1"
  local user_desktop="${home}/.local/share/applications/packettracer.desktop"

  if [[ -f "$user_desktop" ]]; then
    # Sauvegarde, puis on le neutralise (sinon il peut continuer à casser l’affichage du menu)
    local bak="${user_desktop}.bak.$(date +%Y%m%d-%H%M%S)"
    run "mkdir -p '$(dirname "$user_desktop")'"
    run "mv '$user_desktop' '$bak'"
    log "Lanceur utilisateur déplacé: $user_desktop -> $bak"
  fi
}

update_caches() {
  run "command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database /usr/share/applications || true"
  run "command -v update-mime-database >/dev/null 2>&1 && update-mime-database /usr/share/mime || true"
  run "command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f /usr/share/icons/hicolor || true"
}

main() {
  for arg in "$@"; do
    case "$arg" in
      --fix-all-users) FIX_ALL_USERS=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h|--help) usage; exit 0 ;;
      *) log "Option inconnue: $arg"; usage; exit 1 ;;
    esac
  done

  need_root

  local exec_path
  exec_path="$(detect_exec)"
  if [[ -z "$exec_path" ]]; then
    log "Erreur: impossible de trouver Packet Tracer. (Installer le .deb d’abord.)"
    exit 1
  fi

  # Version
  local v
  v="$(dpkg_version)"
  if [[ -z "$v" && -f "$PT_APPIMAGE" ]]; then
    local tmpdir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "'"$tmpdir"'"' EXIT
    extract_appimage "$tmpdir"
    v="$(appimage_version_from_desktop "$tmpdir")"
  fi
  [[ -z "$v" ]] && v="(version non détectée)"

  log "Executable détecté: $exec_path"
  log "Version détectée: $v"

  # Neutraliser un lanceur utilisateur cassé (SUDO_USER)
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    local home
    home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    if [[ -n "$home" && -d "$home" ]]; then
      fix_user_desktop_for_home "$home"
    fi
  fi

  # Option: tous les utilisateurs /home/*
  if [[ "$FIX_ALL_USERS" -eq 1 ]]; then
    for h in /home/*; do
      [[ -d "$h" ]] || continue
      fix_user_desktop_for_home "$h"
    done
  fi

  install_icon
  write_system_desktop "$exec_path"
  update_caches

  log "OK: réparation terminée."
  log "Si le menu n’actualise pas immédiatement, déconnexion/reconnexion de la session."
}

main "$@"
