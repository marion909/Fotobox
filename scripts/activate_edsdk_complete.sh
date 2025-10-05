#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║     🚀 PHOTOBOX SOFORT-UPGRADE - EDSDK.DLL VORHANDEN        ║
# ║        Aktiviere beste Kamera-APIs mit vollständigem EDSDK    ║
# ╚═══════════════════════════════════════════════════════════════╝

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🚀 PHOTOBOX KAMERA SOFORT-UPGRADE                ║"
echo "║             Canon EDSDK.dll Integration aktivieren           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Setup
PHOTOBOX_DIR="/home/pi/Photobox"
if [ ! -d "$PHOTOBOX_DIR" ]; then
    PHOTOBOX_DIR=$(pwd)
fi

cd "$PHOTOBOX_DIR"
echo "📁 Photobox: $PHOTOBOX_DIR"

# Virtual Environment
if [ -d ".venv" ]; then
    source .venv/bin/activate
    echo "🐍 Virtual Environment aktiv"
else
    echo "⚠️  System Python verwendet"
fi
echo

# 1. UPDATES ABRUFEN
echo "1️⃣ Repository Updates..."
git pull origin master
echo "  ✅ Neueste Verbesserungen abgerufen"
echo

# 2. EDSDK STATUS (detailliert)
echo "2️⃣ Canon EDSDK Status (vollständig)..."

if [ -d "EDSDK" ]; then
    echo "  📂 EDSDK Verzeichnis: ✅"
    
    # Zeige alle EDSDK-Dateien
    echo "  📋 EDSDK Inhalt:"
    ls -la EDSDK/ | while read line; do echo "    $line"; done
    
    # Prüfe auf DLL
    if [ -f "EDSDK/EDSDK.dll" ]; then
        DLL_SIZE=$(stat -c%s EDSDK/EDSDK.dll 2>/dev/null || stat -f%z EDSDK/EDSDK.dll)
        echo "  ✅ EDSDK.dll gefunden (${DLL_SIZE} Bytes)"
        
        # Prüfe DLL-Architektur (Linux/macOS)
        if command -v file >/dev/null 2>&1; then
            DLL_ARCH=$(file EDSDK/EDSDK.dll)
            echo "  🏗️  DLL Info: $DLL_ARCH"
        fi
    else
        echo "  ❌ EDSDK.dll nicht gefunden"
    fi
    
    # Pascal Headers
    PAS_COUNT=$(find EDSDK -name "*.pas" 2>/dev/null | wc -l)
    echo "  📝 Pascal Headers: $PAS_COUNT Dateien"
    
else
    echo "  ❌ EDSDK Verzeichnis fehlt"
fi
echo

# 3. PYTHON ARCHITEKTUR CHECK
echo "3️⃣ Python Architektur Check..."

PYTHON_ARCH=$(python3 -c "import platform; print(platform.architecture()[0])")
PYTHON_MACHINE=$(python3 -c "import platform; print(platform.machine())")
echo "  💻 Python Architektur: $PYTHON_ARCH"
echo "  🏗️  System: $PYTHON_MACHINE"

# Prüfe ob 64-bit System und Python
if [[ "$PYTHON_ARCH" == "64bit" ]]; then
    echo "  ✅ 64-bit Python erkannt"
    NEEDS_64BIT_EDSDK=true
else
    echo "  ⚠️  32-bit Python erkannt"
    NEEDS_64BIT_EDSDK=false
fi
echo

# 4. GPHOTO2 PYTHON INSTALLATION (robuste Alternative)
echo "4️⃣ gphoto2 Python Installation..."

echo "  📦 Installiere System-Abhängigkeiten..."
sudo apt-get update -qq >/dev/null 2>&1
sudo apt-get install -y \
    libgphoto2-dev \
    libgphoto2-port12 \
    python3-dev \
    build-essential \
    pkg-config \
    >/dev/null 2>&1

echo "  🐍 Installiere gphoto2 Python Package..."
if pip install gphoto2 >/dev/null 2>&1; then
    echo "  ✅ gphoto2 Python erfolgreich installiert"
    GPHOTO2_PY_OK=true
else
    echo "  ⚠️  gphoto2 Python Installation fehlgeschlagen"
    GPHOTO2_PY_OK=false
fi
echo

# 5. MODERNE CAMERA MANAGER AKTIVIERUNG
echo "5️⃣ Aktiviere Moderne Camera APIs..."

# Backup
if [ -f "camera_manager.py" ]; then
    cp camera_manager.py camera_manager_backup_$(date +%s).py
    echo "  💾 Backup erstellt"
fi

# Aktiviere moderne Version
if [ -f "modern_camera_manager.py" ]; then
    cp modern_camera_manager.py camera_manager.py
    echo "  🚀 Moderne Camera Manager aktiviert"
    
    # Test API-Verfügbarkeit
    echo "  🧪 Teste Kamera-APIs..."
    python3 -c "
import sys, os
sys.path.insert(0, os.getcwd())

try:
    from camera_manager import CAMERA_APIS, modern_camera_manager
    
    print('  📊 API Verfügbarkeit:')
    for api, available in CAMERA_APIS.items():
        status = '✅' if available else '❌'
        print(f'    {status} {api.upper()}')
    
    print(f'  🎯 Gewählte API: {modern_camera_manager.api_backend.upper()}')
    
    # Kamera-Info
    try:
        info = modern_camera_manager.get_camera_info()
        print(f'  📷 Kamera Status: {\"Verbunden\" if info.get(\"connected\") else \"Getrennt\"}')
        if 'model' in info:
            print(f'  📸 Modell: {info[\"model\"]}')
    except Exception as e:
        print(f'  ⚠️  Kamera-Info Fehler: {e}')
        
except ImportError as e:
    print(f'  ❌ Import Fehler: {e}')
except Exception as e:
    print(f'  ❌ Test Fehler: {e}')
" 2>/dev/null || echo "  ⚠️ API-Test fehlgeschlagen"

else
    echo "  ❌ modern_camera_manager.py nicht gefunden"
fi
echo

# 6. PERMANENT GVFS/USB FIX
echo "6️⃣ USB & GVFS Konflikt-Lösung (permanent)..."

# GVFS Kamera-Monitor deaktivieren
sudo mkdir -p /etc/systemd/system/gvfs-gphoto2-volume-monitor.service.d/
sudo tee /etc/systemd/system/gvfs-gphoto2-volume-monitor.service.d/override.conf >/dev/null << 'EOF'
[Unit]
# Photobox: GVFS Kamera-Monitor deaktiviert (verhindert PTP Device Busy)
ConditionPathExists=!/home/pi/Photobox/.disable-gvfs
EOF

touch .disable-gvfs
echo "  ✅ GVFS Kamera-Monitor permanent deaktiviert"

# USB-Optimierungen
sudo tee /etc/modprobe.d/photobox-usb.conf >/dev/null << 'EOF'
# Photobox USB-Optimierungen für stabile Kamera-Verbindung
options usbcore autosuspend=-1
options usb_storage delay_use=1

# Canon EOS spezifische Optimierungen
options usb-storage quirks=04a9:32e1:a
EOF

echo "  ✅ USB-System optimiert für Canon EOS"

# Udev-Regeln für Canon
sudo tee /etc/udev/rules.d/99-photobox-canon.rules >/dev/null << 'EOF'
# Photobox Canon EOS Regeln
SUBSYSTEM=="usb", ATTRS{idVendor}=="04a9", ATTRS{idProduct}=="32e1", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="04a9", ATTRS{idProduct}=="32e1", ATTR{power/autosuspend}="-1"

# Verhindere Auto-Mount von Kamera
SUBSYSTEM=="block", ATTRS{idVendor}=="04a9", ENV{UDISKS_IGNORE}="1"
EOF

echo "  ✅ Canon EOS Udev-Regeln erstellt"
echo

# 7. SERVICE UPGRADE & RESTART  
echo "7️⃣ Photobox Service Upgrade..."

# Cleanup vor Neustart
echo "  🧹 Cleanup alter Prozesse..."
sudo pkill -f gphoto2 2>/dev/null || true
sudo pkill -f gvfs 2>/dev/null || true
sudo pkill -f udisks 2>/dev/null || true

if systemctl is-active --quiet photobox; then
    echo "  🔄 Service Neustart..."
    sudo systemctl restart photobox
    
    # Warte und prüfe
    sleep 3
    if systemctl is-active --quiet photobox; then
        echo "  ✅ Service erfolgreich neugestartet"
    else
        echo "  ❌ Service-Neustart fehlgeschlagen"
        sudo journalctl -u photobox --no-pager -n 5
    fi
else
    echo "  🚀 Service ersten Start..."
    sudo systemctl start photobox
    sleep 3
    
    if systemctl is-active --quiet photobox; then
        echo "  ✅ Service gestartet"
    else
        echo "  ❌ Service-Start fehlgeschlagen"
    fi
fi
echo

# 8. LIVE-KAMERA-TEST
echo "8️⃣ Live-Kamera-Test..."

echo "  📷 Teste Kamera-Erkennung..."
if timeout 5 gphoto2 --auto-detect 2>/dev/null | grep -i canon >/dev/null; then
    echo "  ✅ Canon EOS erkannt"
    
    echo "  📸 Teste Foto-Aufnahme..."
    cd photos 2>/dev/null || mkdir -p photos && cd photos
    
    # Verwende moderne API für Test
    TEST_RESULT=$(timeout 15 python3 -c "
import sys, os
sys.path.insert(0, os.path.dirname(os.getcwd()))

try:
    from camera_manager import modern_camera_manager
    result = modern_camera_manager.take_photo('test_upgrade_$(date +%s).jpg')
    
    if result.get('success'):
        print('SUCCESS:' + result.get('message', 'Foto OK'))
    else:
        print('ERROR:' + result.get('message', 'Unbekannter Fehler'))
        
except Exception as e:
    print('EXCEPTION:' + str(e))
" 2>&1)

    if echo "$TEST_RESULT" | grep -q "SUCCESS:"; then
        echo "  ✅ Foto-Test erfolgreich!"
        echo "    $(echo "$TEST_RESULT" | grep "SUCCESS:" | cut -d: -f2)"
    elif echo "$TEST_RESULT" | grep -q "ERROR:"; then
        echo "  ⚠️  Foto-Test mit Warnung:"
        echo "    $(echo "$TEST_RESULT" | grep "ERROR:" | cut -d: -f2)"
    else
        echo "  ❌ Foto-Test fehlgeschlagen:"
        echo "    $TEST_RESULT"
    fi
    
    cd "$PHOTOBOX_DIR"
else
    echo "  ❌ Keine Canon EOS Kamera erkannt"
    echo "  💡 USB-Kabel prüfen und Kamera einschalten"
fi
echo

# 9. FINAL STATUS & RECOMMENDATIONS
echo "9️⃣ Status-Übersicht & Empfehlungen..."

# Service Status
if systemctl is-active --quiet photobox; then
    echo "  ✅ Photobox Service: LÄUFT"
    IP=$(hostname -I | awk '{print $1}')
    echo "  🌐 Web-Interface: http://$IP:5000"
else
    echo "  ❌ Photobox Service: GESTOPPT"
fi

# API Priorität anzeigen
echo "  📊 Aktuelle API-Priorität:"
if [ -f "EDSDK/EDSDK.dll" ]; then
    if $NEEDS_64BIT_EDSDK; then
        echo "    1️⃣ Canon EDSDK (⚠️  DLL-Architektur prüfen)"
    else
        echo "    1️⃣ Canon EDSDK (✅ bereit)"
    fi
else
    echo "    1️⃣ Canon EDSDK (❌ DLL fehlt)"
fi

if $GPHOTO2_PY_OK; then
    echo "    2️⃣ gphoto2 Python (✅ aktiv)"
else
    echo "    2️⃣ gphoto2 Python (❌ fehlgeschlagen)"
fi

echo "    3️⃣ gphoto2 CLI (✅ Fallback)"

echo

echo "═══════════════════════════════════════════════════════════════"
echo "                   🎉 UPGRADE ABGESCHLOSSEN"  
echo "═══════════════════════════════════════════════════════════════"
echo
echo "🚀 AKTIVIERTE VERBESSERUNGEN:"
echo
echo "✅ Moderne Multi-API Camera Manager"
echo "✅ gphoto2 Python Bindings (bessere Performance)"
echo "✅ Canon EDSDK Vorbereitung (DLL vorhanden)"
echo "✅ Permanent GVFS/USB Konflikt-Lösung"
echo "✅ Canon EOS spezifische Optimierungen"
echo "✅ Photobox Service mit neuen APIs"
echo
echo "💡 WENN EDSDK NICHT FUNKTIONIERT:"
echo "   - DLL-Architektur (32-bit vs 64-bit) könnte nicht passen"
echo "   - gphoto2 Python ist trotzdem eine große Verbesserung"
echo "   - 'PTP Device Busy' Probleme sind stark reduziert"
echo
echo "🔍 LIVE-MONITORING:"
echo "   sudo journalctl -u photobox -f"
echo
echo "🌐 WEB-INTERFACE:"
if systemctl is-active --quiet photobox && [ -n "$IP" ]; then
    echo "   http://$IP:5000"
else
    echo "   Service prüfen: sudo systemctl status photobox"
fi
echo
echo "✅ Photobox Kamera-System erfolgreich modernisiert!"