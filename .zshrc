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
# Debian
##
# Use apt or aptitude if installed, fallback is apt-get
# You can just set apt_pref='apt-get' to override it.

if [[ -z $apt_pref || -z $apt_upgr ]]; then
    if [[ -e $commands[apt] ]]; then
        apt_pref='apt'
        apt_upgr='upgrade'
    elif [[ -e $commands[aptitude] ]]; then
        apt_pref='aptitude'
        apt_upgr='safe-upgrade'
    else
        apt_pref='apt-get'
        apt_upgr='upgrade'
    fi
fi

# Use sudo by default if it's installed
if [[ -e $commands[sudo] ]]; then
    use_sudo=1
fi

# Aliases ###################################################################
# These are for more obscure uses of apt-get and aptitude that aren't covered
# below.
alias age='apt-get'
alias api='aptitude'

# Some self-explanatory aliases
alias acs="apt-cache search"
alias aps='aptitude search'
alias as="aptitude -F '* %p -> %d \n(%v/%V)' --no-gui --disable-columns search"

# apt-file
alias afs='apt-file search --regexp'


# These are apt-get only
alias asrc='apt-get source'
alias app='apt-cache policy'

# superuser operations ######################################################
if [[ $use_sudo -eq 1 ]]; then
# commands using sudo #######
    alias aac="sudo $apt_pref autoclean"
    alias abd="sudo $apt_pref build-dep"
    alias ac="sudo $apt_pref clean"
    alias ad="sudo $apt_pref update"
    alias adg="sudo $apt_pref update && sudo $apt_pref $apt_upgr"
    alias adu="sudo $apt_pref update && sudo $apt_pref dist-upgrade"
    alias afu="sudo apt-file update"
    alias au="sudo $apt_pref $apt_upgr"
    alias ai="sudo $apt_pref install"
    # Install all packages given on the command line while using only the first word of each line:
    # acs ... | ail
    alias ail="sed -e 's/  */ /g' -e 's/ *//' | cut -s -d ' ' -f 1 | xargs sudo $apt_pref install"
    alias ap="sudo $apt_pref purge"
    alias ar="sudo $apt_pref remove"

    # apt-get only
    alias ads="sudo apt-get dselect-upgrade"

    # Install all .deb files in the current directory.
    # Warning: you will need to put the glob in single quotes if you use:
    # glob_subst
    alias dia="sudo dpkg -i ./*.deb"
    alias di="sudo dpkg -i"

    # Remove ALL kernel images and headers EXCEPT the one in use
    alias kclean='sudo aptitude remove -P ?and(~i~nlinux-(ima|hea) ?not(~n$(uname -r)))'


# commands using su #########
else
    alias aac="su -ls '$apt_pref autoclean' root"
    function abd() {
        cmd="su -lc '$apt_pref build-dep $@' root"
        print "$cmd"
        eval "$cmd"
    }
    alias ac="su -ls '$apt_pref clean' root"
    alias ad="su -lc '$apt_pref update' root"
    alias adg="su -lc '$apt_pref update && aptitude $apt_upgr' root"
    alias adu="su -lc '$apt_pref update && aptitude dist-upgrade' root"
    alias afu="su -lc '$apt-file update'"
    alias au="su -lc '$apt_pref $apt_upgr' root"
    function ai() {
        cmd="su -lc 'aptitude -P install $@' root"
        print "$cmd"
        eval "$cmd"
    }
    function ap() {
        cmd="su -lc '$apt_pref -P purge $@' root"
        print "$cmd"
        eval "$cmd"
    }
    function ar() {
        cmd="su -lc '$apt_pref -P remove $@' root"
        print "$cmd"
        eval "$cmd"
    }

    # Install all .deb files in the current directory
    # Assumes glob_subst is off
    alias dia='su -lc "dpkg -i ./*.deb" root'
    alias di='su -lc "dpkg -i" root'

    # Remove ALL kernel images and headers EXCEPT the one in use
    alias kclean='su -lc "aptitude remove -P ?and(~i~nlinux-(ima|hea) ?not(~n$(uname -r)))" root'
fi

# Completion ################################################################

#
# Registers a compdef for $1 that calls $apt_pref with the commands $2
# To do that it creates a new completion function called _apt_pref_$2
#
function apt_pref_compdef() {
    local f fb
    f="_apt_pref_${2}"

    eval "function ${f}() {
        shift words;
        service=\"\$apt_pref\";
        words=(\"\$apt_pref\" '$2' \$words);
        ((CURRENT++))
        test \"\${apt_pref}\" = 'aptitude' && _aptitude || _apt
    }"

    compdef "$f" "$1"
}

apt_pref_compdef aac "autoclean"
apt_pref_compdef abd "build-dep"
apt_pref_compdef ac  "clean"
apt_pref_compdef ad  "update"
apt_pref_compdef afu "update"
apt_pref_compdef au  "$apt_upgr"
apt_pref_compdef ai  "install"
apt_pref_compdef ail "install"
apt_pref_compdef ap  "purge"
apt_pref_compdef ar  "remove"
apt_pref_compdef ads "dselect-upgrade"

# Misc. #####################################################################
# print all installed packages
alias allpkgs='aptitude search -F "%p" --disable-columns ~i'

# Create a basic .deb package
alias mydeb='time dpkg-buildpackage -rfakeroot -us -uc'


# Functions #################################################################
# create a simple script that can be used to 'duplicate' a system
function apt-copy() {
    print '#!/bin/sh'"\n" > apt-copy.sh

    cmd='$apt_pref install'

    for p in ${(f)"$(aptitude search -F "%p" --disable-columns \~i)"}; {
        cmd="${cmd} ${p}"
    }

    print $cmd "\n" >> apt-copy.sh

    chmod +x apt-copy.sh
}

# Prints apt history
# Usage:
#   apt-history install
#   apt-history upgrade
#   apt-history remove
#   apt-history rollback
#   apt-history list
# Based On: https://linuxcommando.blogspot.com/2008/08/how-to-show-apt-log-history.html
function apt-history() {
  case "$1" in
    install)
      zgrep --no-filename 'install ' $(ls -rt /var/log/dpkg*)
      ;;
    upgrade|remove)
      zgrep --no-filename $1 $(ls -rt /var/log/dpkg*)
      ;;
    rollback)
      zgrep --no-filename upgrade $(ls -rt /var/log/dpkg*) | \
        grep "$2" -A10000000 | \
        grep "$3" -B10000000 | \
        awk '{print $4"="$5}'
      ;;
    list)
      zgrep --no-filename '' $(ls -rt /var/log/dpkg*)
      ;;
    *)
      echo "Parameters:"
      echo " install - Lists all packages that have been installed."
      echo " upgrade - Lists all packages that have been upgraded."
      echo " remove - Lists all packages that have been removed."
      echo " rollback - Lists rollback information."
      echo " list - Lists all contains of dpkg logs."
      ;;
  esac
}

# Kernel-package building shortcut
function kerndeb() {
    # temporarily unset MAKEFLAGS ( '-j3' will fail )
    MAKEFLAGS=$( print - $MAKEFLAGS | perl -pe 's/-j\s*[\d]+//g' )
    print '$MAKEFLAGS set to '"'$MAKEFLAGS'"
    appendage='-custom' # this shows up in $(uname -r )
    revision=$(date +"%Y%m%d") # this shows up in the .deb file name

    make-kpkg clean

    time fakeroot make-kpkg --append-to-version "$appendage" --revision \
        "$revision" kernel_image kernel_headers
}

# List packages by size
function apt-list-packages() {
    dpkg-query -W --showformat='${Installed-Size} ${Package} ${Status}\n' | \
    grep -v deinstall | \
    sort -n | \
    awk '{print $1" "$2}'
}

















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

alias ping='ping -c 5'
alias clr='clear; echo Currently logged in on $TTY, as $USER in directory $PWD.'
alias path='print -l $path'
alias mkdir='mkdir -pv'





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
