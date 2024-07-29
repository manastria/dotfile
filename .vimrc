" Set 'nocompatible' to ward off unexpected things that your distro might
" have made, as well as sanely reset options when re-sourcing .vimrc
set nocompatible

" Initialisation de pathogen
call pathogen#infect()
call pathogen#helptags()

" Attempt to determine the type of a file based on its name and possibly its
" contents. Use this to allow intelligent auto-indenting for each filetype,
" and for plugins that are filetype specific.
filetype indent plugin on

" Enable syntax highlighting
if has('syntax') && (&t_Co > 2)
    syntax on
endif

" have fifty lines of command-line (etc) history:
set history=50

" One such option is the 'hidden' option, which allows you to re-use the same
" window and switch from an unsaved buffer without saving it first. Also allows
" you to keep an undo history for multiple files when re-using the same window
" in this way. Note that using persistent undo also lets you undo in multiple
" files even in the same window, but is less efficient and is actually designed
" for keeping undo history after closing Vim entirely. Vim will complain if you
" try to quit without saving, and swap files will keep you safe if your computer
" crashes.
set hidden

" Note that not everyone likes working this way (with the hidden option).
" Alternatives include using tabs or split windows instead of re-using the same
" window as mentioned above, and/or either of the following options:
" set confirm
" set autowriteall

" Better command-line completion
set wildmenu

" have command-line completion <Tab> (for filenames, help topics, option names)
" first list the available options and complete the longest common part, then
" have further <Tab>s cycle through the possibilities:
set wildmode=list:longest,full

" when using list, keep tabs at their full width and display `arrows':
execute 'set listchars+=tab:' . nr2char(187) . nr2char(183)
" (Character 187 is a right double-chevron, and 183 a mid-dot.)


" Show partial commands and current mode in the last line of the screen
set showcmd
set showmode

" Highlight searches (use <C-L> to temporarily turn off highlighting; see the
" mapping of <C-L> below)
set hlsearch

" Modelines have historically been a source of security vulnerabilities. As
" such, it may be a good idea to disable them and use the securemodelines
" script, <http://www.vim.org/scripts/script.php?script_id=1876>.
set modeline
set modelines=10

" Use case insensitive search, except when using capital letters
set ignorecase
set smartcase

" Search options
set incsearch
set hlsearch

" Allow backspacing over autoindent, line breaks and start of insert action
set backspace=indent,eol,start

" When opening a new line and no filetype-specific indenting is enabled, keep
" the same indent as the line you're currently on. Useful for READMEs, etc.
set autoindent

" Stop certain movements from always going to the first character of a line.
" While this behaviour deviates from that of Vi, it does what most users
" coming from other editors would expect.
set nostartofline

" Display the cursor position on the last line of the screen or in the status
" line of a window
set ruler

" Always display the status line, even if only one window is displayed
" http://vimdoc.sourceforge.net/htmldoc/options.html#%27statusline%27
" m F   Modified flag, text is "[+]"; "[-]" if 'modifiable' is off.
" M F   Modified flag, text is ",+" or ",-".
" r F   Readonly flag, text is "[RO]".
" R F   Readonly flag, text is ",RO".
" h F   Help buffer flag, text is "[help]".
" H F   Help buffer flag, text is ",HLP".
" w F   Preview window flag, text is "[Preview]".
" W F   Preview window flag, text is ",PRV".
" y F   Type of file in the buffer, e.g., "[vim]".  See 'filetype'.
" Y F   Type of file in the buffer, e.g., ",VIM".  See 'filetype'.
" n N   Buffer number.
" F S   Full path to the file in the buffer.
" a S   Argument list status as in default title.  ({current} of {max}) Empty if the argument file count is zero or one.
" = -   Separation point between left and right aligned items.
" l N   Line number.
" L N   Number of lines in buffer.
" v N   Virtual column number.
" V N   Virtual column number as -{num}.  Not displayed if equal to 'c'.
" p N   Percentage through file in lines as in |CTRL-G|.
" P S   Percentage through file of displayed window.  This is like the percentage described for 'ruler'.  Always 3 in length.
" b N   Value of character under cursor.
" B N   As above, in hexadecimal.
set laststatus=2
set statusline=%<[%02n]
set statusline+=\ %{HasPaste()}%F
set statusline+=\ %w%h%m%r
set statusline+=\ [%(%M%H%W%R%)]
set statusline+=\ CWD:\ %{getcwd()}
set statusline+=\ [%{&ff}/%Y]
set statusline+=\ %a%=
set statusline+=\ %4.8l,%c%V/%L\ (%P)
set statusline+=\ [%04.8b:%04B]

"set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%04.8b]\ [HEX=\%04.4B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L] 
"set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L] 

" use "[RO]" for "[readonly]" to save space in the message line:
set shortmess+=r

" Instead of failing a command because of unsaved changes, instead raise a
" dialogue asking if you wish to save changed files.
set confirm

" Use visual bell instead of beeping when doing something wrong
set visualbell

" And reset the terminal code for the visual bell. If visualbell is set, and
" this line is also included, vim will neither flash nor beep. If visualbell
" is unset, this does nothing.
set t_vb=

" Enable use of the mouse for all modes
"set mouse=a

" Set the command window height to 2 lines, to avoid many cases of having to
" "press <Enter> to continue"
set cmdheight=2

" Display line numbers on the left
set nonumber

" Quickly time out on keycodes, but never time out on mappings
set notimeout ttimeout ttimeoutlen=200

" Utiliser Ctrl + p pour basculer entre 'paste' et 'nopaste' en mode normal et insertion
nnoremap <C-p> :set invpaste paste?<CR>
inoremap <C-p> <C-O>:set invpaste paste?<CR>
set pastetoggle=<C-p>

" Utiliser Ctrl + w pour basculer 'wrap' en mode normal et insertion
nnoremap <C-w> :set wrap!<CR>
inoremap <C-w> <Esc>:set wrap!<CR>i


" Indentation settings for using 4 spaces instead of tabs.
" Do not change 'tabstop' from its default value of 8 with this setup.
set shiftwidth=4
set softtabstop=4
set noexpandtab
set shiftround
set tabstop=4

" normally don't automatically format `text' as it is typed, IE only do this
" with comments, at 79 characters:
set formatoptions-=t
set textwidth=79

" get rid of the default style of C comments, and define a style with two stars
" at the start of `middle' rows which (looks nicer and) avoids asterisks used
" for bullet lists being treated like C comments; then define a bullet list
" style for single stars (like already is for hyphens):
set comments-=s1:/*,mb:*,ex:*/
set comments+=s:/*,mb:**,ex:*/
set comments+=fb:*

" treat lines starting with a quote mark as comments (for `Vim' files, such as
" this very one!), and colons as well so that reformatting usenet messages from
" `Tin' users works OK:
set comments+=b:\"
set comments+=n::




" Map Y to act like D and C, i.e. to yank until EOL, rather than act as yy,
" which is the default
"map Y y$

" Map <C-L> (redraw screen) to also turn off search highlighting until the
" next search
"nnoremap <C-L> :nohl<CR><C-L>


"------------------------------------------------------------


" * Text Formatting -- Specific File Formats

" enable filetype detection:
filetype on

" recognize anything in my .Postponed directory as a news article, and anything
" at all with a .txt extension as being human-language text [this clobbers the
" `help' filetype, but that doesn't seem to prevent help from working
" properly]:
augroup filetype
  autocmd BufNewFile,BufRead */.Postponed/* set filetype=mail
  autocmd BufNewFile,BufRead *.txt set filetype=human
augroup END

" in human-language files, automatically format everything at 72 chars:
autocmd FileType mail,human set formatoptions+=t textwidth=72

" for C-like programming, have automatic indentation:
autocmd FileType c,cpp,slang set cindent

" for actual C (not C++) programming where comments have explicit end
" characters, if starting a new line in the middle of a comment automatically
" insert the comment leader characters:
autocmd FileType c set formatoptions+=ro

" for Perl programming, have things in braces indenting themselves:
autocmd FileType perl set smartindent

" for CSS, also have things in braces indented:
autocmd FileType css set smartindent

" for HTML, generally format text, but if a long line has been created leave it
" alone when editing:
autocmd FileType html set formatoptions+=tl

" for both CSS and HTML, use genuine tab characters for indentation, to make
" files a few bytes smaller:
autocmd FileType html,css set noexpandtab tabstop=2

" in makefiles, don't expand tabs to spaces, since actual tab characters are
" needed, and have indentation at 8 chars to be sure that all indents are tabs
" (despite the mappings later):
autocmd FileType make set noexpandtab shiftwidth=8



" assume the /g flag on :s substitutions to replace all matches in a line:
set gdefault

"To have the numeric keypad working with putty / vim
:imap <Esc>Oq 1
:imap <Esc>Or 2
:imap <Esc>Os 3
:imap <Esc>Ot 4
:imap <Esc>Ou 5
:imap <Esc>Ov 6
:imap <Esc>Ow 7
:imap <Esc>Ox 8
:imap <Esc>Oy 9
:imap <Esc>Op 0
:imap <Esc>On .
:imap <Esc>OQ /
:imap <Esc>OR *
:imap <Esc>Ol +
:imap <Esc>OS -



"the cursor will briefly jump to the matching brace when you insert one. 
set showmatch

"set autowrite






""""""""""""""""""""""""""""""""""""""""""""""""""
"              Function Key maps                 "
""""""""""""""""""""""""""""""""""""""""""""""""""
let mapleader=","



""""""""""""""""""""""""""""""""""""""""""""""""""
"              Custom functions                  "
""""""""""""""""""""""""""""""""""""""""""""""""""

" Re-source the rc files
:function! Re_source(file_name)
: let path_file_name = g:VIM_CUSTOM . a:file_name
:  if filereadable(path_file_name)
:  	execute 'source ' . path_file_name
:  	echo path_file_name . " Loaded sucessfully"
:  else
:  	echo path_file_name . " does NOT exist"
:  	return 0
:  endif
:endfunction

" This function allows me to quickly remove extra tabs and whitespace
" from the beginning of lines.  This seems to be a problem when I cut
" and paste or when people don't use resizeable tabs.
" TODO The only problem with this is after you execute it it jumps to the 
" beginning of the file.  I need to figure out how to fix that.
:function! Dump_extra_whitespace(rows)
:	let com = ".,+" . a:rows . "s/^[ 	]*//g"
:	execute com
:endfunction

" This function was created by Dillon Jones 
" it reverses the background color for switching between vim/gvim which have
" different defaults.
" TODO The only problem with this is after you execute it it jumps to the 
" beginning of the file.  I need to figure out how to fix that.
:function! ReverseBackground()
: let Mysyn=&syntax
: if &bg=="light"
: se bg=dark
: else
: se bg=light
: endif
: syn on
: exe "set syntax=" . Mysyn
":   echo "now syntax is "&syntax
:endfunction


" Cleanup
:function! Clean_up()
:set visualbell&
:set background&
:set tabstop&
:set showmatch&
:set showcmd&
:set autowrite&
:endfunction

" Returns true if paste mode is enabled
function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    endif
    return ''
endfunction


" Use perl compiler for all *.pl and *.pm files.
autocmd BufNewFile,BufRead *.p? compiler perl

function! ShowColourSchemeName()
    try
        echo g:colors_name
    catch /^Vim:E121/
        echo "default
    endtry
endfunction





" Include user's local vim config
if filereadable(expand("~/.vimrc.local"))
  source ~/.vimrc.local
endif

