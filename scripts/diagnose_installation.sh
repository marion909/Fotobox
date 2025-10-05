#!/bin/bash

# Photobox Post-Installation Diagnose Script
# Prüft warum das Frontend nach der Installation nicht lädt

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                  📋 PHOTOBOX DIAGNOSE                         ║"
echo "║                Post-Installation Check                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Funktionen
print_check() {
    echo -e "${BLUE}🔍 Prüfe: $1${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "  ${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "  ${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "  ${PURPLE}ℹ️  $1${NC}"
}

INSTALL_DIR="/home/pi/Photobox"
SERVICE_USER="pi"

echo ""

# 1. Installation vorhanden?
print_check "Installation Verzeichnis"
if [ -d "$INSTALL_DIR" ]; then
    print_ok "Photobox Verzeichnis gefunden: $INSTALL_DIR"
    cd "$INSTALL_DIR"
else
    print_error "Photobox Verzeichnis nicht gefunden!"
    exit 1
fi

# 2. Wichtige Dateien
print_check "Wichtige Dateien"
if [ -f "app.py" ]; then
    print_ok "app.py vorhanden"
else
    print_error "app.py fehlt!"
fi

if [ -f "config.json" ]; then
    print_ok "config.json vorhanden"
else
    print_error "config.json fehlt!"
fi

if [ -f "requirements.txt" ]; then
    print_ok "requirements.txt vorhanden"
else
    print_warning "requirements.txt fehlt"
fi

# 3. Virtual Environment
print_check "Python Virtual Environment"
if [ -d ".venv" ]; then
    print_ok "Virtual Environment gefunden"
    
    if [ -f ".venv/bin/python" ]; then
        print_ok "Python executable vorhanden"
        PYTHON_VERSION=$(.venv/bin/python --version 2>&1)
        print_info "Python Version: $PYTHON_VERSION"
    else
        print_error "Python executable fehlt in venv"
    fi
    
    if [ -f ".venv/bin/pip" ]; then
        print_ok "pip executable vorhanden"
    else
        print_error "pip executable fehlt in venv"
    fi
else
    print_error "Virtual Environment nicht gefunden!"
fi

# 4. Python Dependencies
print_check "Python Dependencies"
if [ -f ".venv/bin/python" ]; then
    echo -e "  ${BLUE}Teste wichtige Module:${NC}"
    
    if .venv/bin/python -c "import flask" 2>/dev/null; then
        FLASK_VERSION=$(.venv/bin/python -c "import flask; print(flask.__version__)" 2>/dev/null)
        print_ok "Flask installiert (Version: $FLASK_VERSION)"
    else
        print_error "Flask nicht installiert oder fehlerhaft"
    fi
    
    if .venv/bin/python -c "import PIL" 2>/dev/null; then
        print_ok "PIL/Pillow installiert"
    else
        print_error "PIL/Pillow nicht installiert"
    fi
    
    if .venv/bin/python -c "import requests" 2>/dev/null; then
        print_ok "Requests installiert"
    else
        print_error "Requests nicht installiert"
    fi
fi

# 5. App-Syntax prüfen
print_check "App Syntax"
if [ -f ".venv/bin/python" ] && [ -f "app.py" ]; then
    SYNTAX_CHECK=$(.venv/bin/python -m py_compile app.py 2>&1)
    if [ $? -eq 0 ]; then
        print_ok "app.py Syntax korrekt"
    else
        print_error "app.py Syntax-Fehler:"
        echo -e "  ${RED}$SYNTAX_CHECK${NC}"
    fi
fi

# 6. Systemd Service
print_check "Systemd Service"
if systemctl list-unit-files | grep -q "photobox.service"; then
    print_ok "photobox.service registriert"
    
    if systemctl is-enabled photobox >/dev/null 2>&1; then
        print_ok "Service aktiviert (startet bei Boot)"
    else
        print_warning "Service nicht aktiviert"
        print_info "Lösung: sudo systemctl enable photobox"
    fi
    
    if systemctl is-active photobox >/dev/null 2>&1; then
        print_ok "Service läuft"
        
        # Service-Details
        SERVICE_PID=$(systemctl show -p MainPID photobox | cut -d= -f2)
        if [ "$SERVICE_PID" != "0" ] && [ -n "$SERVICE_PID" ]; then
            print_info "Process ID: $SERVICE_PID"
        fi
        
    else
        print_error "Service läuft nicht!"
        print_info "Status prüfen: sudo systemctl status photobox"
        
        # Versuche Service zu starten
        echo -e "  ${YELLOW}Versuche Service zu starten...${NC}"
        if sudo systemctl start photobox 2>/dev/null; then
            sleep 3
            if systemctl is-active photobox >/dev/null 2>&1; then
                print_ok "Service erfolgreich gestartet"
            else
                print_error "Service start fehlgeschlagen"
            fi
        fi
    fi
else
    print_error "photobox.service nicht gefunden!"
fi

# 7. Netzwerk & Port
print_check "Netzwerk Connectivity"

# Lokale IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -n "$LOCAL_IP" ]; then
    print_ok "Lokale IP: $LOCAL_IP"
else
    print_warning "Keine IP-Adresse gefunden"
fi

# Port 5000 Test
echo -e "  ${BLUE}Teste Port 5000:${NC}"
if netstat -tln 2>/dev/null | grep -q ":5000 "; then
    print_ok "Port 5000 ist gebunden"
else
    print_error "Port 5000 nicht aktiv"
fi

# HTTP Test
if command -v curl >/dev/null 2>&1; then
    echo -e "  ${BLUE}Teste HTTP Response:${NC}"
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:5000 2>/dev/null)
    
    if [ "$HTTP_RESPONSE" = "200" ]; then
        print_ok "HTTP 200 - Webserver antwortet korrekt"
    elif [ "$HTTP_RESPONSE" = "000" ]; then
        print_error "Keine HTTP-Antwort (Verbindung fehlgeschlagen)"
    else
        print_warning "HTTP $HTTP_RESPONSE - Unerwartete Antwort"
    fi
else
    print_warning "curl nicht verfügbar für HTTP-Test"
fi

# 8. Logs prüfen
print_check "Service Logs"
echo -e "  ${BLUE}Letzte 10 Log-Einträge:${NC}"
if journalctl -u photobox --no-pager -n 10 2>/dev/null | grep -q "photobox"; then
    journalctl -u photobox --no-pager -n 10 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q -i "error\|fail\|exception"; then
            echo -e "  ${RED}$line${NC}"
        elif echo "$line" | grep -q -i "warn"; then
            echo -e "  ${YELLOW}$line${NC}"
        else
            echo -e "  ${BLUE}$line${NC}"
        fi
    done
else
    print_warning "Keine photobox logs gefunden"
fi

# 9. Kiosk-Mode
print_check "Kiosk Mode Setup"
if [ -f "/home/$SERVICE_USER/start_kiosk.sh" ]; then
    print_ok "Kiosk Script vorhanden"
    
    if [ -f "/home/$SERVICE_USER/.config/autostart/photobox-kiosk.desktop" ]; then
        print_ok "Autostart konfiguriert"
    else
        print_warning "Autostart nicht konfiguriert"
    fi
else
    print_warning "Kiosk Script fehlt"
fi

# 10. Berechtigungen
print_check "Dateiberechtigungen"
OWNER=$(stat -c %U "$INSTALL_DIR" 2>/dev/null)
if [ "$OWNER" = "$SERVICE_USER" ]; then
    print_ok "Installationsverzeichnis gehört $SERVICE_USER"
else
    print_error "Falsche Berechtigung: $OWNER (sollte $SERVICE_USER sein)"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                            EMPFEHLUNGEN                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Empfehlungen basierend auf Findings
if ! systemctl is-active photobox >/dev/null 2>&1; then
    echo -e "${YELLOW}🔧 Service Problem:${NC}"
    echo "   1. Status prüfen: sudo systemctl status photobox"
    echo "   2. Logs anzeigen: sudo journalctl -u photobox -f"
    echo "   3. Service starten: sudo systemctl start photobox"
    echo "   4. Service aktivieren: sudo systemctl enable photobox"
    echo ""
fi

if ! netstat -tln 2>/dev/null | grep -q ":5000 "; then
    echo -e "${YELLOW}🌐 Port Problem:${NC}"
    echo "   1. Prüfe ob Port 5000 frei ist: sudo netstat -tlnp | grep :5000"
    echo "   2. Firewall prüfen: sudo ufw status"
    echo "   3. App manuell starten: cd $INSTALL_DIR && .venv/bin/python app.py"
    echo ""
fi

if [ ! -f ".venv/bin/python" ] || ! .venv/bin/python -c "import flask" 2>/dev/null; then
    echo -e "${YELLOW}🐍 Python Problem:${NC}"
    echo "   1. Virtual Environment neu erstellen:"
    echo "      cd $INSTALL_DIR"
    echo "      rm -rf .venv"
    echo "      python3 -m venv .venv"
    echo "      .venv/bin/pip install -r requirements.txt"
    echo ""
fi

echo -e "${PURPLE}🔧 Manuelle Tests:${NC}"
echo "   • Service Status: sudo systemctl status photobox"
echo "   • Live Logs: sudo journalctl -u photobox -f"
echo "   • App testen: cd $INSTALL_DIR && .venv/bin/python app.py"
echo "   • Browser: http://localhost:5000 oder http://$LOCAL_IP:5000"
echo ""

echo -e "${GREEN}✅ Diagnose abgeschlossen!${NC}"