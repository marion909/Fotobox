#!/bin/bash

# Photobox Quick-Fix Script
# Behebt häufige Post-Installation Probleme

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Photobox Quick-Fix${NC}"
echo "================================"

INSTALL_DIR="/home/pi/Photobox"
SERVICE_USER="pi"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Bitte als root ausführen: sudo $0${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Korrigiere Log-Berechtigungen...${NC}"
mkdir -p /var/log/photobox /var/log
touch /var/log/photobox_startup.log /var/log/photobox_app.log
chown pi:pi /var/log/photobox /var/log/photobox_startup.log /var/log/photobox_app.log
chmod 755 /var/log/photobox
chmod 664 /var/log/photobox_startup.log /var/log/photobox_app.log
echo -e "${GREEN}✅ Log-Berechtigungen korrigiert${NC}"

echo -e "${YELLOW}2. Korrigiere start_photobox.sh Pfade...${NC}"
if [ -f "$INSTALL_DIR/start_photobox.sh" ]; then
    # Backup erstellen
    cp "$INSTALL_DIR/start_photobox.sh" "$INSTALL_DIR/start_photobox.sh.backup"
    
    # Neues Script erstellen
    cat > "$INSTALL_DIR/start_photobox.sh" << 'EOF'
#!/bin/bash

# Photobox Startup Script mit Fehlerbehandlung
LOG_FILE="/var/log/photobox_startup.log"
INSTALL_DIR="/home/pi/Photobox"

# Log-Verzeichnis und Berechtigungen sicherstellen
mkdir -p /var/log
touch "$LOG_FILE" /var/log/photobox_app.log
chown pi:pi "$LOG_FILE" /var/log/photobox_app.log
chmod 664 "$LOG_FILE" /var/log/photobox_app.log

echo "$(date): Photobox Startup gestartet" >> "$LOG_FILE"

# USB-Konflikte beheben
killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true

# GVFS temporär stoppen falls aktiv
systemctl --quiet is-active gvfs-daemon && systemctl stop gvfs-daemon || true

# Kamera-Module zurücksetzen
modprobe -r uvcvideo 2>/dev/null || true
sleep 2
modprobe uvcvideo 2>/dev/null || true

# Verzeichnisse sicherstellen
mkdir -p "$INSTALL_DIR"/{photos,overlays,temp,backups,logs}
chown -R pi:pi "$INSTALL_DIR"/{photos,overlays,temp,backups,logs}

# Berechtigungen korrigieren
chmod 755 "$INSTALL_DIR"/{photos,overlays,temp,backups,logs}

echo "$(date): Umgebung vorbereitet, starte App" >> "$LOG_FILE"

# Python-App starten
cd "$INSTALL_DIR"
exec ./.venv/bin/python app.py 2>&1 | tee -a /var/log/photobox_app.log
EOF

    chmod +x "$INSTALL_DIR/start_photobox.sh"
    chown pi:pi "$INSTALL_DIR/start_photobox.sh"
    echo -e "${GREEN}✅ start_photobox.sh korrigiert${NC}"
else
    echo -e "${RED}❌ start_photobox.sh nicht gefunden${NC}"
fi

echo -e "${YELLOW}3. Korrigiere Virtual Environment Pfad...${NC}"
if [ -d "$INSTALL_DIR/.venv" ]; then
    echo -e "${GREEN}✅ Virtual Environment gefunden${NC}"
else
    echo -e "${YELLOW}⚠️  Virtual Environment nicht gefunden - erstelle...${NC}"
    cd "$INSTALL_DIR"
    sudo -u pi python3 -m venv .venv
    sudo -u pi ./.venv/bin/pip install --upgrade pip
    sudo -u pi ./.venv/bin/pip install -r requirements.txt
    echo -e "${GREEN}✅ Virtual Environment erstellt${NC}"
fi

echo -e "${YELLOW}4. Korrigiere Dateiberechtigungen...${NC}"
chown -R pi:pi "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh
echo -e "${GREEN}✅ Berechtigungen korrigiert${NC}"

echo -e "${YELLOW}5. Service neu laden und starten...${NC}"
systemctl daemon-reload
systemctl enable photobox
systemctl restart photobox

echo -e "${YELLOW}6. Warte auf Service-Start...${NC}"
sleep 5

if systemctl is-active --quiet photobox; then
    echo -e "${GREEN}✅ Service läuft erfolgreich${NC}"
    
    # Teste HTTP-Verbindung
    if curl -s --max-time 10 http://localhost:5000 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTP-Server antwortet${NC}"
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        echo -e "${BLUE}🌐 Zugriff über: http://localhost:5000 oder http://$LOCAL_IP:5000${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTP-Server noch nicht bereit (normal bei erstem Start)${NC}"
    fi
else
    echo -e "${RED}❌ Service start fehlgeschlagen${NC}"
    echo -e "${YELLOW}Logs anzeigen mit: journalctl -u photobox -f${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Quick-Fix abgeschlossen!${NC}"
echo -e "${BLUE}Nützliche Befehle:${NC}"
echo "• Service Status: systemctl status photobox"
echo "• Service Logs: journalctl -u photobox -f"
echo "• App manuell testen: cd $INSTALL_DIR && .venv/bin/python app.py"