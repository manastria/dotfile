#!/bin/bash

# Définir les variables pour le proxy
PROXY_HTTP="http://172.16.0.1:3128"
PROXY_HTTPS="http://172.16.0.1:3128"

# Fonction pour configurer le proxy
configure_proxy() {
    sudo snap set system proxy.http="$PROXY_HTTP"
    sudo snap set system proxy.https="$PROXY_HTTPS"
    echo "Proxy configuré avec succès."
}

# Fonction pour désactiver le proxy
disable_proxy() {
    sudo snap unset system proxy.http
    sudo snap unset system proxy.https
    echo "Proxy désactivé avec succès."
}

# Fonction pour installer les logiciels snap
install_snaps() {
    snap refresh
    snap find 1password
    sudo snap install 1password
    sudo snap install --classic code
    sudo snap install --classic obsidian
    echo "Logiciels snap installés avec succès."
}

# Vérifier les arguments passés au script
if [ "$1" == "--no-proxy" ]; then
    disable_proxy
else
    configure_proxy
fi

# Installer les logiciels snap
install_snaps