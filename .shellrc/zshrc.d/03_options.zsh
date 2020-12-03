# -*- mode: shell-script -*-

## clobber
## Allows > redirection to truncate existing files, and >> to create files. Otherwise >! must be used to truncate a file, and >>! to create a file.
setopt clobber

## Autorise un globbing qui ne renvoie aucun fichier
unsetopt NOMATCH