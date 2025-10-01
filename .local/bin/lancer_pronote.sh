#!/bin/bash

# Se déplace dans le répertoire de l'exécutable pour éviter les problèmes de chemin
cd ~/.wine/drive_c/Program\ Files/Index\ Education/Pronote\ 2025/Réseau/Client/

# Lance Pronote en supprimant les messages de débogage "nls"
WINEDEBUG=-nls wine "Client PRONOTE.exe"

