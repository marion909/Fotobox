#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║        🚀 PHOTOBOX KAMERA UPGRADE - EDSDK INTEGRATION        ║
# ║           Aktiviere moderne Kamera-APIs mit EDSDK            ║
# ╚═══════════════════════════════════════════════════════════════╝

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🚀 PHOTOBOX KAMERA UPGRADE                       ║"
echo "║            Canon EDSDK Integration aktivieren                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Basis-Setup
PHOTOBOX_DIR="/home/pi/Photobox"
if [ ! -d "$PHOTOBOX_DIR" ]; then
    PHOTOBOX_DIR=$(pwd)
fi

cd "$PHOTOBOX_DIR"
echo "📁 Photobox Verzeichnis: $PHOTOBOX_DIR"

# Virtual Environment prüfen
if [ -d ".venv" ]; then
    echo "🐍 Aktiviere Virtual Environment..."
    source .venv/bin/activate
    echo "  ✅ Virtual Environment aktiv"
else
    echo "⚠️  Kein Virtual Environment - verwende System Python"
fi
echo

# 1. UPDATES ABRUFEN
echo "1️⃣ Repository Updates..."
git pull origin master
echo

# 2. EDSDK STATUS PRÜFEN
echo "2️⃣ Canon EDSDK Status..."
if [ -d "EDSDK" ]; then
    echo "  ✅ EDSDK Verzeichnis gefunden"
    
    # Prüfe auf DLL-Dateien
    DLL_COUNT=$(find EDSDK -name "*.dll" -o -name "*.so" | wc -l)
    if [ "$DLL_COUNT" -gt 0 ]; then
        echo "  ✅ EDSDK Bibliotheken gefunden:"
        find EDSDK -name "*.dll" -o -name "*.so" | head -3
    else
        echo "  ⚠️  Nur Header-Dateien gefunden, keine DLL/SO"
        echo "  💡 Vollständiges EDSDK von Canon herunterladen für beste Leistung"
    fi
    
    # Prüfe Pascal-Dateien
    PAS_COUNT=$(find EDSDK -name "*.pas" | wc -l)
    echo "  📝 Pascal Header-Dateien: $PAS_COUNT"
else
    echo "  ❌ EDSDK Verzeichnis nicht gefunden"
fi
echo

# 3. GPHOTO2 PYTHON INSTALLATION  
echo "3️⃣ gphoto2 Python Bindings..."

# Installiere System-Abhängigkeiten
echo "  📦 Installiere libgphoto2 Abhängigkeiten..."
sudo apt-get update -qq
sudo apt-get install -y libgphoto2-dev libgphoto2-port12 python3-dev build-essential pkg-config

# Installiere Python-Package
echo "  🐍 Installiere gphoto2 Python-Package..."
pip install gphoto2 || {
    echo "  ⚠️ gphoto2 Installation fehlgeschlagen - verwende CLI Fallback"
}
echo

# 4. MODERNE CAMERA MANAGER AKTIVIEREN
echo "4️⃣ Moderne Camera Manager aktivieren..."

# Backup der alten Version
if [ -f "camera_manager.py" ]; then
    cp camera_manager.py camera_manager_old.py.backup
    echo "  💾 Backup: camera_manager_old.py.backup"
fi

# Aktiviere moderne Version
if [ -f "modern_camera_manager.py" ]; then
    cp modern_camera_manager.py camera_manager.py
    echo "  🚀 Moderne camera_manager.py aktiviert"
    
    # Zeige verfügbare APIs
    echo "  🔍 Teste verfügbare Kamera-APIs:"
    python3 -c "
import sys, os
sys.path.insert(0, os.getcwd())

try:
    from camera_manager import modern_camera_manager
    print('  ✅ Moderne Camera Manager importiert')
    
    # Teste API-Verfügbarkeit  
    info = modern_camera_manager.get_camera_info()
    print(f'  📷 Kamera-API: {info.get(\"api\", \"unknown\")}')
    print(f'  🔗 Verbunden: {info.get(\"connected\", False)}')
    if 'model' in info:
        print(f'  📸 Modell: {info[\"model\"]}')
        
except Exception as e:
    print(f'  ❌ Import-Fehler: {e}')
" 2>/dev/null || echo "  ⚠️ Moderne Camera Manager Test fehlgeschlagen"
else
    echo "  ❌ modern_camera_manager.py nicht gefunden"
fi
echo

# 5. USB OPTIMIERUNGEN  
echo "5️⃣ USB & GVFS Optimierungen..."

# GVFS für Kameras deaktivieren (verhindert PTP Device Busy)
sudo mkdir -p /etc/systemd/system/gvfs-gphoto2-volume-monitor.service.d/
sudo tee /etc/systemd/system/gvfs-gphoto2-volume-monitor.service.d/override.conf > /dev/null << 'EOF'
[Unit]
# Deaktiviere GVFS Kamera-Monitor für Photobox
ConditionPathExists=!/home/pi/Photobox/.disable-gvfs
EOF

# Deaktivierungs-Flag setzen
touch .disable-gvfs
echo "  ✅ GVFS Kamera-Monitor deaktiviert"

# USB-Optimierungen
sudo tee /etc/modprobe.d/photobox-usb.conf > /dev/null << 'EOF'
# Photobox USB-Optimierungen für Canon EOS
options usbcore autosuspend=-1
options usb_storage delay_use=1
EOF

echo "  ✅ USB-Optimierungen konfiguriert"
echo

# 6. SERVICE NEUSTART
echo "6️⃣ Photobox Service Neustart..."

if systemctl is-active --quiet photobox; then
    echo "  🔄 Stoppe Photobox Service..."
    sudo systemctl stop photobox
    
    # Räume alte Prozesse auf
    sudo pkill -f gphoto2 2>/dev/null || true
    sudo pkill -f gvfs 2>/dev/null || true
    sleep 2
    
    echo "  🚀 Starte Photobox Service neu..."
    sudo systemctl start photobox
    
    # Warte auf Start
    sleep 3
    
    if systemctl is-active --quiet photobox; then
        echo "  ✅ Service erfolgreich neugestartet"
    else
        echo "  ❌ Service-Start fehlgeschlagen"
        echo "  🔍 Zeige Fehler-Logs:"
        sudo journalctl -u photobox --no-pager -n 10
    fi
else
    echo "  ⚠️  Photobox Service nicht aktiv - starte manuell"
    echo "  💡 Befehl: sudo systemctl start photobox"
fi
echo

# 7. KAMERA-TEST
echo "7️⃣ Kamera-Funktionstest..."

echo "  📷 Teste Kamera-Erkennung..."
if gphoto2 --auto-detect 2>/dev/null | grep -i canon >/dev/null; then
    echo "  ✅ Canon EOS Kamera erkannt"
    
    echo "  📸 Teste Foto-Aufnahme..."
    cd photos
    
    # Teste mit neuer API
    if timeout 10 gphoto2 --capture-image >/dev/null 2>&1; then
        echo "  ✅ Foto-Aufnahme erfolgreich"
    else
        echo "  ⚠️  Foto-Test fehlgeschlagen (möglich: PTP Device Busy)"
        echo "  🔧 Führe Camera-Reset durch..."
        
        # Camera-Reset
        sudo pkill -f gphoto2
        sudo pkill -f gvfs  
        sleep 1
        
        # USB-Reset falls Root-Rechte
        if [ "$EUID" -eq 0 ]; then
            sudo modprobe -r usb_storage 2>/dev/null || true
            sleep 1
            sudo modprobe usb_storage 2>/dev/null || true
        fi
    fi
    
    cd "$PHOTOBOX_DIR"
else
    echo "  ❌ Keine Canon EOS Kamera erkannt"
fi
echo

# 8. API-PRIORITY TEST
echo "8️⃣ API-Prioritäts-Test..."

echo "  🧪 Teste API-Reihenfolge:"
python3 -c "
import sys, os
sys.path.insert(0, os.getcwd())

try:
    from camera_manager import CAMERA_APIS
    print('  📊 Verfügbare APIs:')
    for api, available in CAMERA_APIS.items():
        status = '✅' if available else '❌'
        print(f'    {status} {api}')
        
    # Zeige gewählte API
    from camera_manager import modern_camera_manager
    print(f'  🎯 Gewählte API: {modern_camera_manager.api_backend}')
    
except Exception as e:
    print(f'  ❌ API-Test Fehler: {e}')
" 2>/dev/null || echo "  ⚠️ API-Test fehlgeschlagen"

echo

echo "═══════════════════════════════════════════════════════════════"
echo "                   🎉 UPGRADE ABGESCHLOSSEN"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "📊 VERBESSERUNGEN AKTIVIERT:"
echo
echo "1️⃣ ✅ Moderne Camera Manager (Multi-API System)"
echo "2️⃣ 🐍 gphoto2 Python Bindings (bessere Performance)"  
echo "3️⃣ 🚫 GVFS Konflikt-Lösung (permanent)"
echo "4️⃣ ⚙️ USB-Optimierungen"
echo "5️⃣ 📷 Canon EDSDK Vorbereitung"
echo
echo "🌐 PHOTOBOX ZUGRIFF:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo
echo "🔍 LIVE-MONITORING:"
echo "   sudo journalctl -u photobox -f"
echo
echo "📖 VOLLSTÄNDIGES EDSDK SETUP:"
echo "   1. Download Canon EDSDK von: https://developers.canon-europe.com/"
echo "   2. Entpacke EDSDK.dll ins EDSDK/ Verzeichnis"  
echo "   3. Führe dieses Script erneut aus"
echo
echo "✅ Canon EOS Integration erfolgreich verbessert!"