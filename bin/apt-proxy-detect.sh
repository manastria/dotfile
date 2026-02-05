#!/bin/bash
# Configuration
# L'IP de ton serveur apt-cacher-ng principal (le plus probable)
STATIC_IP="192.168.X.Y" 
PORT="3142"

# 1. Tentative "Éclair" via Ping
# -c 1 : un seul paquet
# -W 1 : timeout de 1 seconde max
if ping -c 1 -W 1 "$STATIC_IP" > /dev/null 2>&1; then
    echo "http://$STATIC_IP:$PORT"
    exit 0
fi

# 2. Fallback : Découverte dynamique (Avahi)
# On cherche le service _apt_proxy._tcp
SERVICE="_apt_proxy._tcp"

# Récupération des proxys via Avahi
# -r : résout les IPs, -t : termine après dump, -p : parsable
PROXIES=$(avahi-browse -r -t -p $SERVICE 2>/dev/null | grep "^=;")

if [ -z "$PROXIES" ]; then
    echo "DIRECT"
    exit 0
fi

# Tri : On prend l'IP la plus petite pour le déterminisme
CHOSEN_PROXY=$(echo "$PROXIES" | awk -F';' '{print $8":"$9}' | sort -V | head -n 1)

if [ -n "$CHOSEN_PROXY" ]; then
    echo "http://$CHOSEN_PROXY/"
else
    echo "DIRECT"
fi