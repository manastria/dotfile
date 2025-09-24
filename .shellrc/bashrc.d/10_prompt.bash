# -*- mode: bash -*-
# ===================================================================
# =                     GESTIONNAIRE DE PROMPT                      =
# =      Starship (si dispo) + fallback Bash propre et lisible      =
# ===================================================================
#
#  ➤ Conception
#    1) Si Starship est installé → on l'active et on NE câble PAS le fallback.
#    2) Si Starship n’est pas dispo → on active un prompt Bash « maison ».
#    3) Profils Starship persistants :
#         - écriture du profil choisi dans ~/.config/starship/current_profile
#         - variable STARSHIP_CONFIG pointant vers le .toml correspondant
#
#  ➤ Fonctions utiles exposées à l'utilisateur
#       - prompt_default   : sélectionne le profil Starship "default"
#       - prompt_projector : sélectionne le profil Starship "projector"
#
#  ➤ Notes d’implémentation
#       - On protège l’activation du fallback pour ne JAMAIS écraser Starship.
#       - Anti-doublons soignés pour PROMPT_COMMAND.
#       - Titre de fenêtre mis à jour côté fallback uniquement.
#       - Détection « shell interactif » pour ne rien faire en mode non-interactif.
#
# -------------------------------------------------------------------
# 0) NE RIEN FAIRE EN SHELL NON-INTERACTIF
#    (évite d’altérer des scripts qui "sourcent" ce fichier)
# -------------------------------------------------------------------
case $- in
  *i*) : ;;            # interactif → on continue
  *)   return 0 2>/dev/null || exit 0 ;;
esac

# -------------------------------------------------------------------
# 1) CONSTANTES & EMPLACEMENTS
# -------------------------------------------------------------------
# Répertoire de config XDG (fallback sur ~/.config si non défini)
_XDG_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# Dossier Starship (configs .toml)
_STARSHIP_DIR="$_XDG_CFG_DIR/starship"
# Fichier qui mémorise le profil courant
_STARSHIP_PROFILE_FILE="$_STARSHIP_DIR/current_profile"
# Nom du profil par défaut si le fichier n'existe pas
_STARSHIP_DEFAULT_PROFILE="default"

# Flag interne : Starship activé avec succès ?
PROMPT_MANAGER_STARSHIP_ACTIVE=0

# -------------------------------------------------------------------
# 2) OUTILS : DÉTECTION COULEURS & TITRE DE FENÊTRE (fallback)
# -------------------------------------------------------------------
_detect_color_support() {
  # Retourne "yes" ou "no" via echo (usage : COLOR=$(_detect_color_support))
  local term="$TERM"
  case "$term" in
    xterm-color|*-256color|xterm) ;;
    *) echo "no"; return ;;
  esac
  if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    echo "yes"
  else
    echo "no"
  fi
}

# Titre d'onglet/fenêtre : "host: chemin"
_set_window_title() {
  case "$TERM" in
    xterm*|rxvt*|konsole*|gnome*|alacritty)
      local cwd short_host
      cwd="$(pwd | sed -e "s#^$HOME\$#~#" -e "s#^$HOME/#~/#")"
      short_host="${HOSTNAME%%.*}"
      [ -z "$short_host" ] && short_host="$(hostname -s 2>/dev/null || echo "$HOSTNAME")"
      # OSC 0 ; <titre> BEL  — compatible MobaXterm/terminaux courants
      echo -en "\033]0;${short_host}: ${cwd}\a"
      ;;
  esac
}

# -------------------------------------------------------------------
# 3) FALLBACK BASH : construction dynamique du prompt
#    (jamais branché si Starship est actif)
# -------------------------------------------------------------------
__prompt_command() {
  # Si Starship est actif, on ne touche pas à PS1 (sécurité supplémentaire)
  if [ "${PROMPT_MANAGER_STARSHIP_ACTIVE:-0}" -eq 1 ]; then
    return
  fi

  local EXIT="$?"  # code retour de la commande précédente

  # Palette
  local RCol='\[\e[0m\]'
  local Red='\[\e[0;31m\]'
  local Gre='\[\e[0;32m\]'
  local BYel='\[\e[1;33m\]'
  local BBlu='\[\e[1;34m\]'
  local Pur='\[\e[0;35m\]'
  local BCya='\[\e[1;36m\]'

  # Indicateur venv (si Python virtualenv actif)
  local venv_indicator=""
  if [ -n "${VIRTUAL_ENV:-}" ]; then
    venv_indicator="${BCya}($(basename "$VIRTUAL_ENV")) ${RCol}"
  fi

  # Utilisateur en vert si OK, rouge si erreur
  local user_color="${Gre}"
  [ "$EXIT" -ne 0 ] && user_color="${Red}"

  # Construction PS1
  PS1=""
  PS1+="${venv_indicator}"               # (venv)
  PS1+="${user_color}\u${RCol}"          # user coloré selon EXIT
  PS1+="${RCol}@${BBlu}\h ${Pur}\w"      # @host <espace> chemin
  PS1+="${BYel}\\$ ${RCol}"              # signe $ en jaune vif

  # Mise à jour du titre de fenêtre (terminaux graphiques)
  _set_window_title
}

# -------------------------------------------------------------------
# 4) PROFILS STARSHIP : fonctions utilisateur
#    - écrivent le profil choisi
#    - ajustent STARSHIP_CONFIG pour le shell courant (effet immédiat partiel)
# -------------------------------------------------------------------
_pm_set_profile() {
  # $1 = nom du profil (ex: default, projector)
  local profile="$1"
  mkdir -p "$_STARSHIP_DIR"
  echo "$profile" > "$_STARSHIP_PROFILE_FILE"

  local cfg="$_STARSHIP_DIR/${profile}.toml"
  if [ -f "$cfg" ]; then
    export STARSHIP_CONFIG="$cfg"
    echo "✅ Profil Starship « ${profile} » sélectionné. (config: $cfg)"
  else
    # Pas de fichier → Starship utilisera sa config par défaut
    unset STARSHIP_CONFIG
    echo "ℹ️ Profil « ${profile} » sélectionné, mais aucun fichier ${cfg} trouvé."
    echo "   Starship utilisera sa configuration par défaut."
  fi

  # NB : Starship lit sa config à l’initialisation. Pour un rechargement total :
  echo "Astuce : exécutez « exec \$SHELL » pour relancer proprement le shell."
}

prompt_default()   { _pm_set_profile "default"; }
prompt_projector() { _pm_set_profile "projector"; }

# -------------------------------------------------------------------
# 5) ACTIVATION STARSHIP (si disponible)
#    - Détermine le profil courant
#    - Exporte STARSHIP_CONFIG si le fichier existe
#    - Lance l'init Starship
# -------------------------------------------------------------------
_activate_starship_if_available() {
  if ! command -v starship >/dev/null 2>&1; then
    return 1  # Starship absent
  fi

  # Profil courant (ou "default" par défaut)
  local profile
  if [ -f "$_STARSHIP_PROFILE_FILE" ]; then
    profile="$(cat "$_STARSHIP_PROFILE_FILE" 2>/dev/null || true)"
    [ -z "$profile" ] && profile="$_STARSHIP_DEFAULT_PROFILE"
  else
    profile="$_STARSHIP_DEFAULT_PROFILE"
  fi

  # Pointeur de config (si le .toml existe)
  local cfg="$_STARSHIP_DIR/${profile}.toml"
  if [ -f "$cfg" ]; then
    export STARSHIP_CONFIG="$cfg"
  else
    unset STARSHIP_CONFIG  # Starship tombera sur sa config intégrée
  fi

  # Initialisation Starship pour bash
  # (si échec → on retournera 1 pour déclencher le fallback)
  if eval "$(starship init bash)" >/dev/null 2>&1; then
    PROMPT_MANAGER_STARSHIP_ACTIVE=1
    return 0
  else
    return 1
  fi
}

# -------------------------------------------------------------------
# 6) ROUTAGE PRINCIPAL : Starship d’abord, sinon fallback Bash
# -------------------------------------------------------------------
if _activate_starship_if_available; then
  :
  # ✅ Starship est actif. NE SURTOUT PAS câbler le fallback.
else
  # ❌ Starship absent/indisponible → Fallback Bash
  COLOR_PROMPT="$(_detect_color_support)"

  if [ "$COLOR_PROMPT" = "yes" ]; then
    # Ajouter __prompt_command une seule fois à PROMPT_COMMAND
    case ";$PROMPT_COMMAND;" in
      *";__prompt_command;"*) : ;;                 # déjà présent
      "") PROMPT_COMMAND="__prompt_command" ;;     # vide → init
      *)  PROMPT_COMMAND+=$'\n''__prompt_command' ;;  # empilement propre
    esac
  else
    # Terminal sans couleurs → prompt statique minimal
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
  fi
fi

# -------------------------------------------------------------------
# 7) NETTOYAGE LÉGER (évite d’encombrer l’environnement)
# -------------------------------------------------------------------
unset COLOR_PROMPT
# (on conserve volontairement les fonctions prompt_default / prompt_projector)
