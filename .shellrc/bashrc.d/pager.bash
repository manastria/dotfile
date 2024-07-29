# -*- mode: bash -*-

# les pages de man en couleur, necessite le paquet most
if [ -x /usr/bin/most ]
then
    export PAGER=most
fi



export PAGER="/usr/bin/less -FRXKS"

