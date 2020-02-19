autoload -U colors zsh-mime-setup select-word-style compinit
colors          # colors
zsh-mime-setup  # run everything as if it's an executable
select-word-style bash # ctrl+w on words
compinit # Advanced completion

# See: http://zsh.sourceforge.net/Intro/intro_6.html
setopt autopushd pushdminus pushdsilent pushdtohome pushdignoredups


# Caractère du prompt pour un utilisateur non root %#
promptchars="$"

##
# Prompt
##
setopt PROMPT_SUBST     # allow funky stuff in prompt
color="blue"
phost="%m"

# Si on est root
if [[ $EUID == 0 ]]; then
    phost="%{$fg[red]%}%m%{$reset_color%}"
    pchar="#"
else
    phost="%{$fg[green]%}%n@%m%{$reset_color%}"
    pchar="$"
fi;
prompt="$phost %(?..%{$fg[red]%}(%?%)%{$reset_color%}) %T
%{$fg[yellow]%}%~%{$reset_color%}
%B%#%b "
#RPROMPT='${vim_mode} '
# print an empty line before the PROMPT
precmd() { print "" }


# Nouveau prompt
set promptchars=";;"
prompt="${phost}:%{$fg[blue]%}%~%{$reset_color%}
${pchar} "

## clobber
## Allows > redirection to truncate existing files, and >> to create files. Otherwise >! must be used to truncate a file, and >>! to create a file.
#unsetopt clobber
setopt clobber

#
##
# History
##
HISTFILE=~/.zhistory           # enable history saving on shell exit
#HISTFILE=/dev/null
setopt append_history          # append rather than overwrite history file.
HISTSIZE=1200                  # lines of history to maintain memory
SAVEHIST=1000                  # lines of history to maintain in history file.
setopt HIST_EXPIRE_DUPS_FIRST  # allow dups, but expire old ones when I hit HISTSIZE
setopt EXTENDED_HISTORY        # save timestamp and runtime information
bindkey '^R'      history-incremental-pattern-search-backward
unsetopt hist_ignore_space      # ignore space prefixed commands
setopt hist_reduce_blanks       # trim blanks
setopt hist_verify              # show before executing history commands
setopt inc_append_history       # add commands as they are typed, don't wait until shell exit
setopt share_history            # share hist between sessions
setopt bang_hist                # !keyword



bindkey -e                      # emacs keybindings
bindkey '\e[1;5C' forward-word            # C-Right
bindkey '\e[1;5D' backward-word           # C-Left
bindkey '\e[2~'   overwrite-mode          # Insert
bindkey '\e[3~'   delete-char             # Del
bindkey '\e[5~'   history-search-backward # PgUp
bindkey '\e[6~'   history-search-forward  # PgDn
bindkey '^A'      beginning-of-line       # Home
bindkey '^D'      delete-char             # Del
bindkey '^E'      end-of-line             # End

# Edit the current command line in $EDITOR
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

##
# Completion
##
autoload -U compinit
compinit
zmodload -i zsh/complist
setopt hash_list_all            # hash everything before completion
setopt completealiases          # complete alisases
setopt always_to_end            # when completing from the middle of a word, move the cursor to the end of the word
setopt complete_in_word         # allow completion from within a word/phrase
setopt correct                  # spelling correction for commands
setopt list_ambiguous           # complete as much of a completion until it gets ambiguous.

zstyle ':completion::complete:*' use-cache on               # completion caching, use rehash to clear
zstyle ':completion:*' cache-path ~/.zsh/cache              # cache path
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # ignore case
zstyle ':completion:*' menu select=2                        # menu if nb items > 2
highlights='${PREFIX:+=(#bi)($PREFIX:t)(?)*==$color[red]=$color[green];$color[bold]}':${(s.:.)LS_COLORS}}
zstyle -e ':completion:*' list-colors 'reply=( "'$highlights'" )'
#zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}       # colorz !
#zstyle ':completion:*' list-colors  'thingy=${PREFIX##*/} reply=( "=(#b)($thingy)(?)*=00=$color[green]=$color[bg-green]" )'
#zstyle -e ':completion:*' list-colors 'thingy=${PREFIX##*/} reply=( "=(#b)($thingy)(?)*=00=$color[green]=$color[bg-green]" )'
#zstyle ':completion:*' list-colors  'reply=( "=(#b)(*$PREFIX)(?)*=00=$color[green]=$color[bg-green]" )


zstyle ':completion:*::::' completer _expand _complete _ignored _approximate # list of completers to use

# for all completions: show comments when present
zstyle ':completion:*' verbose yes

# for all completions: grouping the output
zstyle ':completion:*' group-name ''


zstyle ':completion:*:manuals' separate-sections true

# statusline for many hits
zstyle ':completion:*:default' select-prompt $'\e[01;35m -- Match %M    %P -- \e[00;00m'

# for all completions: grouping / headline / ...
zstyle ':completion:*:messages' format $'\e[01;35m -- %d -- \e[00;00m'
zstyle ':completion:*:warnings' format $'\e[01;31m -- No Matches Found -- \e[00;00m'
zstyle ':completion:*:descriptions' format $'\e[01;33m -- %d -- \e[00;00m'
zstyle ':completion:*:corrections' format $'\e[01;33m -- %d -- \e[00;00m'

# case insensitivity
#zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ":completion:*" matcher-list 'm:{A-Zöäüa-zÖÄÜ}={a-zÖÄÜA-Zöäü}'

zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*:processes' list-colors "=(#b) #([0-9]#)*=29=34"
zstyle ':completion:*:*:killall:*' menu yes select
zstyle ':completion:*:killall:*' force-list always
users=(jvoisin root)           # because I don't care about others
zstyle ':completion:*' users $users

#generic completion with --help
compdef _gnu_generic gcc
compdef _gnu_generic gdb






##
# Directories
##
# http://zsh.sourceforge.net/Intro/intro_6.html
DIRSTACKSIZE=15
setopt auto_pushd               # make cd push old dir in dir stack
setopt pushd_ignore_dups        # no duplicates in dir stack
setopt pushd_silent             # no dir stack after pushd or popd
setopt pushd_to_home            # `pushd` = `pushd $HOME`
setopt pushdminus               
alias -- -='cd -'
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

alias md='mkdir -p'
alias rd=rmdir

function d () {
  if [[ -n $1 ]]; then
    dirs "$@"
  else
    dirs -v | head -10
  fi
}
compdef _dirs d


##
# systemd
##
user_commands=(
  cat
  get-default
  help
  is-active
  is-enabled
  is-failed
  is-system-running
  list-dependencies
  list-jobs
  list-sockets
  list-timers
  list-unit-files
  list-units
  show
  show-environment
  status)

sudo_commands=(
  add-requires
  add-wants
  cancel
  daemon-reexec
  daemon-reload
  default
  disable
  edit
  emergency
  enable
  halt
  hibernate
  hybrid-sleep
  import-environment
  isolate
  kexec
  kill
  link
  list-machines
  load
  mask
  poweroff
  preset
  preset-all
  reboot
  reenable
  reload
  reload-or-restart
  reset-failed
  rescue
  restart
  revert
  set-default
  set-environment
  set-property
  start
  stop
  suspend
  switch-root
  try-reload-or-restart
  try-restart
  unmask
  unset-environment)

for c in $user_commands; do; alias sc-$c="systemctl $c"; done
for c in $sudo_commands; do; alias sc-$c="sudo systemctl $c"; done
for c in $user_commands; do; alias scu-$c="systemctl --user $c"; done
for c in $sudo_commands; do; alias scu-$c="systemctl --user $c"; done

alias sc-enable-now="sc-enable --now"
alias sc-disable-now="sc-disable --now"
alias sc-mask-now="sc-mask --now"

alias scu-enable-now="scu-enable --now"
alias scu-disable-now="scu-disable --now"
alias scu-mask-now="scu-mask --now"


##
# Various
##
setopt auto_cd                  # if command is a path, cd into it
setopt auto_remove_slash        # self explicit
setopt chase_links              # resolve symlinks
setopt correct                  # try to correct spelling of commands
setopt extended_glob            # activate complex pattern globbing
setopt glob_dots                # include dotfiles in globbing
setopt print_exit_value         # print return value if non-zero
unsetopt beep                   # no bell on error
unsetopt bg_nice                # no lower prio for background jobs
unsetopt clobber                # must use >| to truncate existing files
unsetopt hist_beep              # no bell on error in history
unsetopt hup                    # no hup signal at shell exit
unsetopt ignore_eof             # do not exit on end-of-file
unsetopt list_beep              # no bell on ambiguous completion
unsetopt rm_star_silent         # ask for confirmation for `rm *' or `rm path/*'
print -Pn "\e]0; %n@%M: %~\a"   # terminal title





##########
## vim mode
##########

#bindkey -v      # vi mode
#vim_ins_mode="%{$fg[yellow]%}[INS]%{$reset_color%}"
#vim_cmd_mode="%{$fg[cyan]%}[CMD]%{$reset_color%}"
#vim_mode=$vim_ins_mode

#function zle-keymap-select {
#  vim_mode="${${KEYMAP/vicmd/${vim_cmd_mode}}/(main|viins)/${vim_ins_mode}}"
#  zle reset-prompt
#}
#zle -N zle-keymap-select

#function zle-line-finish {
#  vim_mode=$vim_ins_mode
#}
#zle -N zle-line-finish


############################
# Fonctions
############################

# Créé un répertoire et va dans se nouveau répertoire
function take() {
  mkdir -p $@ && cd ${@:$#}
} 



export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}



mkdir -p $HOME/.shellrc/zshrc.d $HOME/.shellrc/rc.d
# Load all files from .shell/zshrc.d directory
if [ -d $HOME/.shellrc/zshrc.d ]; then
  for file in $HOME/.shellrc/zshrc.d/*.zsh; do
    source $file
  done
fi

# Load all files from .shell/rc.d directory
if [ -d $HOME/.shellrc/rc.d ]; then
  for file in $HOME/.shellrc/rc.d/*.sh; do
    source $file
  done
fi


#
# PATH
#

# rationalize-path()
# Later we'll need to trim down the paths that follow because the ones
# given here are for all my accounts, some of which have unusual
# paths in them.  rationalize-path will remove
# nonexistent directories from an array.
rationalize-path () {             
  # Note that this works only on arrays, not colon-delimited strings.
  # Not that this is a problem now that there is typeset -T.
  local element
  local build
  build=()
  # Evil quoting to survive an eval and to make sure that
  # this works even with variables containing IFS characters, if I'm
  # crazy enough to setopt shwordsplit.
  eval '
  foreach element in "$'"$1"'[@]"
  do
    if [[ -d "$element" ]]
    then
      build=("$build[@]" "$element")
    fi
  done
  '"$1"'=( "$build[@]" )
  '
}


mkdir -p ${HOME}/bin
path=(
  ${HOME}/bin
  /usr/local/bin
  /usr/local/sbin
  /usr/games
  /usr/local/games
  "$path[@]"
)

export PATH
# Only unique entries please.
typeset -U path
# Remove entries that don't exist on this system.  Just for sanity's
# sake more than anything.
rationalize-path path
# path+=${HOME}/bin



# added by travis gem
[ -f /home/jpdemory/.travis/travis.sh ] && source /home/jpdemory/.travis/travis.sh
