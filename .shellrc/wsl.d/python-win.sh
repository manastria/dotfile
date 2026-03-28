# pyenv-win du PATH
export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v 'pyenv-win' | tr '\n' ':' | sed 's/:$//')
