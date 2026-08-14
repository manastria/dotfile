# ~/.shellrc/{zshrc,bashrc}.d/gitignore.zsh
#
# gi <template1> [template2 ...]
#
# Génère / met à jour .gitignore via l'API toptal (gitignore.io), sans
# doublons, en préservant tout ce qui se trouve APRÈS le bloc généré,
# et en garantissant la présence d'une règle pour les fichiers
# "*:Zone.Identifier" qui apparaissent sous WSL2.
#
# Compatible bash et zsh (aucune syntaxe spécifique à l'un ou l'autre).

gi() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: gi <template1> [template2 ...]   (ex: gi python node windows)" >&2
    echo "       gi --list                        (liste les templates dispo)" >&2
    return 1
  fi

  local api_base="https://www.toptal.com/developers/gitignore/api"

  if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
    curl -fsSL "${api_base}/list?format=lines"
    return $?
  fi

  local templates target tmp_new tmp_final tmp_custom
  templates=$(IFS=,; echo "$*")
  target=".gitignore"
  tmp_new=$(mktemp)
  tmp_final=$(mktemp)
  tmp_custom=$(mktemp)

  # --- 1. Récupération ---------------------------------------------------
  if ! curl -fsSL "${api_base}/${templates}" -o "$tmp_new"; then
    echo "gi: échec réseau pour « ${templates} »" >&2
    rm -f "$tmp_new" "$tmp_final" "$tmp_custom"
    return 1
  fi

  if grep -q '^#!! ERROR:' "$tmp_new"; then
    echo "gi: $(grep '^#!! ERROR:' "$tmp_new")" >&2
    rm -f "$tmp_new" "$tmp_final" "$tmp_custom"
    return 1
  fi

  if ! grep -q '^# Created by ' "$tmp_new"; then
    echo "gi: réponse inattendue de l'API :" >&2
    cat "$tmp_new" >&2
    rm -f "$tmp_new" "$tmp_final" "$tmp_custom"
    return 1
  fi

  # --- 2. Préservation de la partie "custom" existante --------------------
  # Convention (identique à celle du dépôt gitignore.io lui-même) :
  # tout ce qui suit la ligne "# End of ..." est à vous, et n'est jamais
  # touché par la régénération du bloc.
  if [ -f "$target" ] && grep -q '^# Created by ' "$target"; then
    awk '/^# End of /{found=1; next} found{print}' "$target" \
      | sed '/./,$!d' > "$tmp_custom"
  elif [ -f "$target" ]; then
    # Fichier existant mais jamais généré par "gi" : on le préserve tel quel
    cp "$target" "$tmp_custom"
  fi

  # --- 3. Reconstruction ---------------------------------------------------
  cat "$tmp_new" > "$tmp_final"
  if [ -s "$tmp_custom" ]; then
    { echo; cat "$tmp_custom"; } >> "$tmp_final"
  fi

  # --- 4. Garantie de la règle Zone.Identifier -----------------------------
  # Sous WSL2 (ext4), Windows ne peut pas stocker l'Alternate Data Stream
  # "Zone.Identifier" nativement : il matérialise l'info sous forme d'un
  # fichier visible "<nom>:Zone.Identifier" à côté du fichier d'origine.
  if ! grep -qxF '*:Zone.Identifier' "$tmp_final"; then
    {
      echo
      echo '### Custom (local) ###'
      echo '# Residus Windows (Alternate Data Stream) rendus visibles sous WSL2'
      echo '# (ext4 ne sait pas stocker les ADS nativement).'
      echo '*:Zone.Identifier'
    } >> "$tmp_final"
  fi

  # --- 5. Filet de sécurité anti-doublons -----------------------------------
  # Les marqueurs "Created by / End of" évitent déjà 95% des doublons lors
  # d'une régénération. Cette passe supprime en plus toute ligne de règle
  # (hors commentaires / lignes vides) déjà vue plus haut dans le fichier,
  # sans changer l'ordre relatif des lignes restantes (donc sans danger pour
  # d'éventuels patterns de négation "!").
  awk '
    /^[[:space:]]*$/ { print; next }
    /^[[:space:]]*#/ { print; next }
    !seen[$0]++ { print }
  ' "$tmp_final" > "$target"

  rm -f "$tmp_new" "$tmp_final" "$tmp_custom"
  echo "gi: ${target} mis a jour (${templates})"
}
