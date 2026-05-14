#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════
# 🚀 INSTALLATION AUTOMATIQUE — Sync Hanvon F710X (v3)
# ═══════════════════════════════════════════════════════════

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# URL du script Python à télécharger
SCRIPT_URL="https://raw.githubusercontent.com/saadaouiaro-sketch/hanvon-sync/main/sync.py"

# 🔧 IMPORTANT : Rediriger l'input vers le terminal
exec < /dev/tty

# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🚀 INSTALLATION SYNC HANVON F710X — TERMUX       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Cette installation va configurer ce téléphone pour"
echo "synchroniser automatiquement les pointages Hanvon."
echo ""
echo -e "${YELLOW}⏱️  Durée : environ 5 minutes${NC}"
echo ""
read -p "Appuyez sur ENTRÉE pour commencer..."

# ═══════════════════════════════════════════════════════════
# ÉTAPE 1 : Mise à jour
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}▶ Étape 1/6 — Mise à jour des paquets...${NC}"
pkg update -y > /dev/null 2>&1
pkg upgrade -y > /dev/null 2>&1
echo -e "${GREEN}✅ Paquets à jour${NC}"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 2 : Installation Python (vérification améliorée)
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}▶ Étape 2/6 — Installation de Python...${NC}"

# Vérifier si Python est déjà installé
if python --version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Python déjà installé : $(python --version 2>&1)${NC}"
else
    # Sinon, on l'installe
    pkg install -y python > /dev/null 2>&1
    
    # Recharger le PATH après installation
    export PATH="/data/data/com.termux/files/usr/bin:$PATH"
    hash -r
    
    # Vérifier à nouveau
    if python --version > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Python installé : $(python --version 2>&1)${NC}"
    else
        echo -e "${RED}❌ Erreur : Python n'a pas pu être installé.${NC}"
        echo -e "${YELLOW}   Essayez manuellement : pkg install python${NC}"
        exit 1
    fi
fi

# Installer curl au passage si pas déjà fait
pkg install -y curl > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════
# ÉTAPE 3 : Installation requests
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}▶ Étape 3/6 — Installation des bibliothèques...${NC}"

# Vérifier si requests est déjà installé
if python -c "import requests" 2>/dev/null; then
    echo -e "${GREEN}✅ Bibliothèque requests déjà installée${NC}"
else
    pip install --upgrade pip > /dev/null 2>&1
    pip install requests > /dev/null 2>&1
    
    if python -c "import requests" 2>/dev/null; then
        echo -e "${GREEN}✅ Bibliothèques installées${NC}"
    else
        echo -e "${RED}❌ Erreur : requests n'a pas pu être installé.${NC}"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════
# ÉTAPE 4 : Téléchargement du script
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}▶ Étape 4/6 — Téléchargement du script sync.py...${NC}"
cd ~

# Si sync.py existe déjà, faire une sauvegarde
if [ -f sync.py ]; then
    cp sync.py sync.py.backup
    echo -e "${BLUE}ℹ️  Ancien sync.py sauvegardé en sync.py.backup${NC}"
fi

curl -sL "$SCRIPT_URL" -o sync.py

if [ ! -s sync.py ]; then
    echo -e "${RED}❌ Échec du téléchargement.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Script téléchargé${NC}"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 5 : Configuration du site
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}▶ Étape 5/6 — Configuration du site${NC}"
echo ""
echo -e "${BLUE}Renseignez les infos de ce site :${NC}"
echo ""

while true; do
    read -p "📍 Nom du site (ex: EXT OFICINA) : " SITE_NAME
    if [ -n "$SITE_NAME" ]; then break; fi
    echo -e "${RED}   Le nom ne peut pas être vide.${NC}"
done

while true; do
    read -p "🆔 ID du site (ex: SITE01) : " SITE_ID
    if [ -n "$SITE_ID" ]; then break; fi
    echo -e "${RED}   L'ID ne peut pas être vide.${NC}"
done

while true; do
    read -p "📡 IP du Hanvon (ex: 192.168.20.214) : " HANVON_IP
    if [ -n "$HANVON_IP" ]; then break; fi
    echo -e "${RED}   L'IP ne peut pas être vide.${NC}"
done

read -p "🔌 Port du Hanvon [9922] : " HANVON_PORT
if [ -z "$HANVON_PORT" ]; then
    HANVON_PORT="9922"
fi

# Test de connexion au Hanvon
echo ""
echo -e "${BLUE}🧪 Test de connexion à $HANVON_IP:$HANVON_PORT...${NC}"
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$HANVON_IP/$HANVON_PORT" 2>/dev/null; then
    echo -e "${GREEN}✅ Hanvon accessible !${NC}"
else
    echo -e "${YELLOW}⚠️  Hanvon non accessible.${NC}"
    echo -e "${YELLOW}   Vérifiez que le téléphone est sur le bon WiFi.${NC}"
    read -p "   Continuer quand même ? (o/n) : " continuer
    if [ "$continuer" != "o" ] && [ "$continuer" != "O" ]; then
        echo -e "${RED}Installation annulée.${NC}"
        exit 1
    fi
fi

# Appliquer la configuration au script
echo ""
echo -e "${BLUE}⚙️  Application de la configuration...${NC}"
sed -i "s|^SITE_NAME = .*|SITE_NAME = \"$SITE_NAME\"|" ~/sync.py
sed -i "s|^SITE_ID = .*|SITE_ID = \"$SITE_ID\"|" ~/sync.py
sed -i "s|^DEFAULT_HOST = .*|DEFAULT_HOST = \"$HANVON_IP\"|" ~/sync.py
sed -i "s|^DEFAULT_PORT = .*|DEFAULT_PORT = $HANVON_PORT|" ~/sync.py
echo -e "${GREEN}✅ Configuration appliquée${NC}"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 6 : Démarrage automatique
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}▶ Étape 6/6 — Configuration du démarrage automatique...${NC}"

mkdir -p ~/.termux/boot

cat > ~/.termux/boot/start-sync.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sleep 30
python ~/sync.py >> ~/sync_boot.log 2>&1
EOF

chmod +x ~/.termux/boot/start-sync.sh
termux-wake-lock 2>/dev/null || true

echo -e "${GREEN}✅ Démarrage automatique configuré${NC}"

# ═══════════════════════════════════════════════════════════
# FIN
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ INSTALLATION TERMINÉE !                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "📋 ${BLUE}Récapitulatif :${NC}"
echo "   • Site    : $SITE_NAME ($SITE_ID)"
echo "   • Hanvon  : $HANVON_IP:$HANVON_PORT"
echo "   • Script  : ~/sync.py"
echo "   • Logs    : ~/sync_log.txt"
echo ""
echo -e "${YELLOW}⚠️  ACTIONS MANUELLES IMPORTANTES :${NC}"
echo ""
echo "   1. Ouvrir l'app Termux:Boot UNE FOIS"
echo ""
echo "   2. Paramètres Android → Applications → Termux"
echo "      → Batterie → Sans restriction"
echo ""
echo "   3. Faire pareil pour Termux:Boot"
echo ""
echo "   4. Garder le téléphone BRANCHÉ en permanence"
echo ""
echo -e "${BLUE}🚀 Commandes utiles :${NC}"
echo "   ▶️  Démarrer        : python ~/sync.py"
echo "   📋 Voir les logs   : tail -f ~/sync_log.txt"
echo "   🛑 Arrêter         : Ctrl+C"
echo ""
read -p "▶ Démarrer le script maintenant ? (o/n) : " start_now

if [ "$start_now" = "o" ] || [ "$start_now" = "O" ]; then
    echo ""
    echo -e "${GREEN}🚀 Démarrage du script... (Ctrl+C pour arrêter)${NC}"
    echo ""
    sleep 2
    python ~/sync.py
else
    echo ""
    echo -e "${BLUE}ℹ️  Pour démarrer plus tard : python ~/sync.py${NC}"
    echo ""
fi
