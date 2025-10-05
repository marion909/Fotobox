#!/bin/bash

# Photobox App Kamera-Debug Script
# Speziell für "Unerwarteter Fehler" beim Foto-Button

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              📱 PHOTOBOX APP KAMERA DEBUG                     ║"
echo "║           Unerwarteter Fehler beim Foto-Button               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

INSTALL_DIR="/home/pi/Photobox"
SERVICE_USER="pi"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Bitte als root ausführen: sudo $0${NC}"
    exit 1
fi

print_check() {
    echo -e "${BLUE}🔍 $1${NC}"
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

echo ""

# 1. Photobox Service Status
print_check "Photobox Service Status"
if systemctl is-active --quiet photobox; then
    print_ok "Service läuft"
    SERVICE_PID=$(systemctl show -p MainPID photobox | cut -d= -f2)
    print_info "Process ID: $SERVICE_PID"
else
    print_error "Service läuft nicht!"
fi

# 2. HTTP-Erreichbarkeit
print_check "HTTP-Server Test"
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:5000 2>/dev/null)
if [ "$HTTP_RESPONSE" = "200" ]; then
    print_ok "Photobox App antwortet (HTTP $HTTP_RESPONSE)"
else
    print_error "Photobox App antwortet nicht (HTTP $HTTP_RESPONSE)"
fi

# 3. Python-App Logs (letzte 20 Zeilen)
print_check "App-Logs (letzte Fehler)"
echo -e "${BLUE}Aktuelle Photobox Logs:${NC}"
if journalctl -u photobox --no-pager -n 20 2>/dev/null | tail -10; then
    true
else
    print_warning "Keine aktuellen Logs gefunden"
fi

# 4. Kamera-Module Test in Python-App
print_check "Python Kamera-Module Test"
cd "$INSTALL_DIR" || exit 1

echo -e "${YELLOW}Teste Kamera-Import in Python...${NC}"
PYTHON_TEST=$(sudo -u $SERVICE_USER ./.venv/bin/python -c "
try:
    import camera_manager
    print('✅ camera_manager Import erfolgreich')
except ImportError as e:
    print(f'❌ camera_manager Import fehler: {e}')
except Exception as e:
    print(f'❌ Unbekannter Fehler: {e}')

try:
    from camera_manager import CameraManager
    print('✅ CameraManager Klasse verfügbar')
except Exception as e:
    print(f'❌ CameraManager Fehler: {e}')
" 2>&1)

echo "$PYTHON_TEST"

# 5. Kamera-Manager Test
print_check "CameraManager Funktionalität"
echo -e "${YELLOW}Teste CameraManager direkt...${NC}"

CAMERA_TEST=$(sudo -u $SERVICE_USER ./.venv/bin/python -c "
import sys
sys.path.append('$INSTALL_DIR')

try:
    from camera_manager import CameraManager
    cam = CameraManager()
    print('✅ CameraManager Instanz erstellt')
    
    # Test Kamera-Erkennung
    cameras = cam.list_cameras()
    print(f'ℹ️  Erkannte Kameras: {len(cameras) if cameras else 0}')
    if cameras:
        for camera in cameras:
            print(f'📷 Kamera: {camera}')
    
    # Test Foto-Aufnahme
    print('📸 Versuche Foto-Aufnahme...')
    result = cam.capture_photo()
    if result.get('success'):
        print('✅ Foto-Aufnahme erfolgreich!')
        print(f\"ℹ️  Datei: {result.get('filename', 'Unbekannt')}\")
    else:
        print(f'❌ Foto-Aufnahme fehlgeschlagen: {result.get(\"error\", \"Unbekannter Fehler\")}')
        
except ImportError as e:
    print(f'❌ Import Fehler: {e}')
except Exception as e:
    print(f'❌ Kamera Fehler: {e}')
    import traceback
    traceback.print_exc()
" 2>&1)

echo "$CAMERA_TEST"

# 6. Flask App Logs
print_check "Flask App Fehler-Logs"
if [ -f "/var/log/photobox_app.log" ]; then
    echo -e "${BLUE}Letzte App-Logs:${NC}"
    tail -20 /var/log/photobox_app.log | grep -E "(ERROR|Exception|Traceback|camera|photo)" || echo "Keine relevanten Fehler in App-Logs"
else
    print_warning "App-Log-Datei nicht gefunden"
fi

# 7. Browser-Test Simulation
print_check "API Endpoint Test"
echo -e "${YELLOW}Teste /capture API direkt...${NC}"

API_TEST=$(curl -s -X POST http://localhost:5000/capture 2>&1)
if echo "$API_TEST" | grep -q "success"; then
    print_ok "API-Endpoint antwortet"
    echo "$API_TEST" | head -5
else
    print_error "API-Endpoint Fehler"
    print_info "$API_TEST"
fi

# 8. Dateisystem-Berechtigungen
print_check "Dateisystem-Berechtigungen"
PHOTOS_DIR="$INSTALL_DIR/photos"
if [ -d "$PHOTOS_DIR" ]; then
    OWNER=$(stat -c %U "$PHOTOS_DIR")
    PERMS=$(stat -c %a "$PHOTOS_DIR")
    if [ "$OWNER" = "$SERVICE_USER" ]; then
        print_ok "photos/ Verzeichnis gehört $SERVICE_USER"
        print_info "Berechtigungen: $PERMS"
    else
        print_error "photos/ Verzeichnis gehört $OWNER (sollte $SERVICE_USER sein)"
    fi
else
    print_error "photos/ Verzeichnis existiert nicht"
fi

# 9. JavaScript Console Errors (Simulation)
print_check "Frontend-Backend Kommunikation"
echo -e "${YELLOW}Teste Frontend API-Aufruf...${NC}"

JS_TEST=$(curl -s -H "Content-Type: application/json" -X POST http://localhost:5000/capture 2>&1)
if echo "$JS_TEST" | grep -q '"success"'; then
    print_ok "Frontend-API funktioniert"
else
    print_warning "Frontend-API möglicherweise problematisch"
    print_info "Response: $JS_TEST"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                       LÖSUNGSANSÄTZE                         ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo ""
echo -e "${YELLOW}🔧 AUTOMATISCHE FIXES:${NC}"

# Fix 1: Berechtigungen korrigieren
echo -e "${YELLOW}1. Korrigiere Berechtigungen...${NC}"
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/photos" "$INSTALL_DIR/temp"
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR/photos" "$INSTALL_DIR/temp"
chmod 755 "$INSTALL_DIR/photos" "$INSTALL_DIR/temp"
print_ok "Berechtigungen korrigiert"

# Fix 2: Kamera-Prozesse aufräumen
echo -e "${YELLOW}2. Räume Kamera-Prozesse auf...${NC}"
killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true
sleep 2
print_ok "Kamera-Prozesse aufgeräumt"

# Fix 3: Service neustarten
echo -e "${YELLOW}3. Starte Photobox Service neu...${NC}"
systemctl restart photobox
sleep 5

if systemctl is-active --quiet photobox; then
    print_ok "Service erfolgreich neugestartet"
else
    print_error "Service-Neustart fehlgeschlagen"
fi

# Fix 4: Final Test
echo -e "${YELLOW}4. Finaler Test...${NC}"
sleep 3

FINAL_API_TEST=$(curl -s -X POST http://localhost:5000/capture 2>&1)
if echo "$FINAL_API_TEST" | grep -q '"success".*true'; then
    print_ok "🎉 API-Test erfolgreich - Foto-Button sollte jetzt funktionieren!"
elif echo "$FINAL_API_TEST" | grep -q "success"; then
    print_warning "API antwortet, aber möglicherweise mit Fehlern"
    echo "$FINAL_API_TEST"
else
    print_error "API-Test weiterhin fehlgeschlagen"
    echo "$FINAL_API_TEST"
fi

echo ""
echo -e "${GREEN}🎯 MANUELLE DEBUG-SCHRITTE:${NC}"
echo ""
echo -e "${BLUE}1. Live-Logs anzeigen:${NC}"
echo "   sudo journalctl -u photobox -f"
echo ""
echo -e "${BLUE}2. App manuell im Debug-Modus starten:${NC}"
echo "   sudo systemctl stop photobox"
echo "   cd $INSTALL_DIR"
echo "   sudo -u $SERVICE_USER DEBUG=1 .venv/bin/python app.py"
echo ""
echo -e "${BLUE}3. Browser Developer Console öffnen:${NC}"
echo "   F12 → Console Tab → Foto-Button klicken → Fehler notieren"
echo ""
echo -e "${BLUE}4. Direkte gphoto2 Tests:${NC}"
echo "   gphoto2 --capture-image"
echo "   gphoto2 --auto-detect"
echo ""

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${PURPLE}💡 Zugriff: http://localhost:5000 oder http://$LOCAL_IP:5000${NC}"

echo ""
echo -e "${GREEN}✅ Debug-Analyse abgeschlossen!${NC}"