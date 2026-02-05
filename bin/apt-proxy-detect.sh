#!/bin/bash

# --- CONFIGURATION ---
STATIC_IP="172.25.253.25"
STATIC_PORT="3142"
# Domaine de recherche DNS (laisser vide pour utiliser le domaine système par défaut)
DNS_DOMAIN="edgand.fr" # ex: ".labo.sio" 

# --- GESTION DU DEBUG ---
DEBUG=0
if [[ "$1" == "-d" || "$1" == "--debug" ]]; then
    DEBUG=1
fi

log() {
    if [ $DEBUG -eq 1 ]; then
        echo -e "\033[0;33m[DEBUG] $1\033[0m" >&2
    fi
}

success() {
    if [ $DEBUG -eq 1 ]; then
        echo -e "\033[0;32m[SUCCESS] Trouvé via : $1\033[0m" >&2
        echo -e "URL renvoyée : \033[1m$2\033[0m" >&2
    else
        echo "$2"
    fi
    exit 0
}

# --- ETAPE 1 : STATIC IP (Priorité Absolue) ---
log "Test de l'IP statique : $STATIC_IP..."
if ping -c 1 -W 1 "$STATIC_IP" > /dev/null 2>&1; then
    success "STATIC (Ping OK)" "http://$STATIC_IP:$STATIC_PORT"
else
    log "IP statique ne répond pas."
fi

# --- ETAPE 2 : DNS SRV (Infrastructure) ---
# On cherche _apt_proxy._tcp
SERVICE_DNS="_apt_proxy._tcp${DNS_DOMAIN}"
log "Interrogation DNS SRV pour $SERVICE_DNS..."

# On utilise dig. +short donne un format simplifié : "priorité poids port cible"
# On trie par priorité (colonne 1)
SRV_RECORD=$(dig +short -t SRV "$SERVICE_DNS" | sort -n -k1 | head -n 1)

if [ -n "$SRV_RECORD" ]; then
    # Extraction du port ($3) et de la cible ($4)
    # Note: dig met un point final à la cible (server.labo.), on peut le garder ou l'enlever.
    SRV_PORT=$(echo "$SRV_RECORD" | awk '{print $3}')
    SRV_HOST=$(echo "$SRV_RECORD" | awk '{print $4}' | sed 's/\.$//')
    
    # Petit check de sécurité : est-ce que ça répond au ping ?
    if ping -c 1 -W 1 "$SRV_HOST" > /dev/null 2>&1; then
        success "DNS SRV ($SRV_HOST)" "http://$SRV_HOST:$SRV_PORT"
    else
        log "Enregistrement DNS trouvé ($SRV_HOST) mais ne répond pas au ping."
    fi
else
    log "Aucun enregistrement SRV trouvé."
fi

# --- ETAPE 3 : AVAHI / ZEROCONF (Découverte Locale) ---
log "Lancement de la découverte Avahi..."
SERVICE_AVAHI="_apt_proxy._tcp"

# -t: termine, -r: résout, -p: parsable
PROXIES=$(avahi-browse -r -t -p $SERVICE_AVAHI 2>/dev/null | grep "^=;")

if [ -n "$PROXIES" ]; then
    # Format Avahi parsable : =;eth0;IPv4;Nom;Type;Domaine;Hote;IP;Port;Txt
    # On trie par IP (champ 8) pour le déterminisme
    BEST_PROXY=$(echo "$PROXIES" | awk -F';' '{print $8":"$9}' | sort -V | head -n 1)
    
    if [ -n "$BEST_PROXY" ]; then
        success "AVAHI (Zeroconf)" "http://$BEST_PROXY/"
    fi
else
    log "Aucun service Avahi trouvé."
fi

# --- ECHEC TOTAL ---
log "Aucun proxy trouvé. Passage en DIRECT."
echo "DIRECT"
exit 0
