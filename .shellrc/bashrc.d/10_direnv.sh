# Vérifier si direnv est installé
# Si le binaire direnv existe
if command -v direnv &> /dev/null; then
    eval "$(direnv hook bash)"
fi
