# -*- mode: shell-script -*-

if (( $+commands[tmux] )); then
	if [ "${TMUX}" ]; then
		add-zsh-hook precmd (){
		  tmux set -wq @status $?
	    }
	fi
fi

