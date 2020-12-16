# Setup fzf
# ---------
if [[ ! "$PATH" == */home/sysadmin/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/sysadmin/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/sysadmin/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/sysadmin/.fzf/shell/key-bindings.zsh"
