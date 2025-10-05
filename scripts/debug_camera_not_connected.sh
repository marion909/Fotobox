#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║        🔧 PHOTOBOX KAMERA LIVE-DEBUG & SOFORT-FIX            ║
# ║       "Kamera nicht verbunden" obwohl angeschlossen          ║
# ╚═══════════════════════════════════════════════════════════════╝

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🔧 KAMERA VERBINDUNGS-DEBUG                      ║"
echo "║           Diagnose: Kamera angeschlossen aber nicht erkannt   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Basis-Setup
PHOTOBOX_DIR="/home/pi/Photobox"
if [ ! -d "$PHOTOBOX_DIR" ]; then
    PHOTOBOX_DIR=$(pwd)
fi

cd "$PHOTOBOX_DIR"
echo "📁 Photobox: $PHOTOBOX_DIR"
echo "🕒 Zeit: $(date)"
echo

# 1. HARDWARE-VERBINDUNG PRÜFEN
echo "1️⃣ Hardware-Verbindung Check..."

echo "  🔌 USB-Geräte (alle):"
lsusb | head -10

echo "  📷 Canon-Geräte spezifisch:"
CANON_USB=$(lsusb | grep -i canon)
if [ -n "$CANON_USB" ]; then
    echo "    ✅ $CANON_USB"
    CANON_VENDOR_ID=$(echo "$CANON_USB" | grep -o "04a9:[0-9a-f]*")
    echo "    🆔 Canon ID: $CANON_VENDOR_ID"
else
    echo "    ❌ Keine Canon-Geräte in lsusb gefunden"
    echo "    💡 Prüfe: USB-Kabel, Kamera eingeschaltet, USB-Port"
fi

echo "  🔋 Kamera-Power-Status:"
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        vendor=$(cat "$dev/idVendor" 2>/dev/null)
        product=$(cat "$dev/idProduct" 2>/dev/null)
        if [ "$vendor" = "04a9" ]; then
            echo "    📱 Canon USB: $vendor:$product"
            if [ -f "$dev/power/autosuspend_delay_ms" ]; then
                delay=$(cat "$dev/power/autosuspend_delay_ms" 2>/dev/null)
                echo "    ⏱️  Autosuspend: $delay ms"
            fi
        fi
    fi
done
echo

# 2. PROZESS-KONFLIKTE PRÜFEN  
echo "2️⃣ Prozess-Konflikte Check..."

echo "  🔍 Aktive gphoto2-Prozesse:"
GPHOTO2_PROCS=$(ps aux | grep gphoto2 | grep -v grep)
if [ -n "$GPHOTO2_PROCS" ]; then
    echo "$GPHOTO2_PROCS" | while read line; do echo "    🟡 $line"; done
else
    echo "    ✅ Keine gphoto2-Prozesse aktiv"
fi

echo "  🔍 GVFS-Prozesse (Konflikt-Verursacher):"
GVFS_PROCS=$(ps aux | grep -E "gvfs.*gphoto|gvfs.*camera" | grep -v grep)
if [ -n "$GVFS_PROCS" ]; then
    echo "$GVFS_PROCS" | while read line; do echo "    🔴 $line"; done
    GVFS_CONFLICT=true
else
    echo "    ✅ Keine GVFS-Kamera-Prozesse"
    GVFS_CONFLICT=false
fi

echo "  🔍 udisks-Prozesse (Auto-Mount):"
UDISKS_PROCS=$(ps aux | grep udisks | grep -v grep)
if [ -n "$UDISKS_PROCS" ]; then
    echo "$UDISKS_PROCS" | while read line; do echo "    🟡 $line"; done
else
    echo "    ✅ Keine udisks-Prozesse"
fi
echo

# 3. GPHOTO2 DIREKTTEST
echo "3️⃣ gphoto2 Direkt-Test..."

echo "  📷 Kamera-Auto-Detect:"
DETECT_RESULT=$(timeout 10 gphoto2 --auto-detect 2>&1)
echo "$DETECT_RESULT" | head -10

if echo "$DETECT_RESULT" | grep -i canon >/dev/null; then
    echo "  ✅ Canon EOS von gphoto2 erkannt"
    GPHOTO2_DETECT_OK=true
else
    echo "  ❌ Canon EOS NICHT von gphoto2 erkannt"
    GPHOTO2_DETECT_OK=false
fi

echo "  📸 Schnell-Capture-Test:"
CAPTURE_RESULT=$(timeout 10 gphoto2 --capture-image 2>&1)
if echo "$CAPTURE_RESULT" | grep -q "New file is in location"; then
    echo "  ✅ Capture-Test erfolgreich"
    GPHOTO2_CAPTURE_OK=true
elif echo "$CAPTURE_RESULT" | grep -q "Device Busy\|0x2019"; then
    echo "  🔴 PTP Device Busy Fehler erkannt"
    GPHOTO2_CAPTURE_OK=false
    PTP_BUSY=true
elif echo "$CAPTURE_RESULT" | grep -q "Could not claim"; then
    echo "  🔴 Kamera bereits beansprucht (Prozess-Konflikt)"
    GPHOTO2_CAPTURE_OK=false
    CLAIMED_ERROR=true
else
    echo "  ❌ Capture-Test fehlgeschlagen:"
    echo "    $(echo "$CAPTURE_RESULT" | head -3)"
    GPHOTO2_CAPTURE_OK=false
fi
echo

# 4. PHOTOBOX SERVICE STATUS
echo "4️⃣ Photobox Service Status..."

if systemctl is-active --quiet photobox; then
    echo "  ✅ Photobox Service läuft"
    
    echo "  📊 Service-Logs (letzte Fehler):"
    sudo journalctl -u photobox --no-pager -n 5 --grep="ERROR\|error\|failed\|❌" || {
        echo "    🔍 Allgemeine Logs:"
        sudo journalctl -u photobox --no-pager -n 3
    }
else
    echo "  ❌ Photobox Service nicht aktiv"
    echo "  🔍 Service-Status:"
    sudo systemctl status photobox --no-pager -l
fi
echo

# 5. SOFORT-FIXES ANWENDEN
echo "5️⃣ Automatische Sofort-Fixes..."

# Fix 1: Prozess-Cleanup
if [ "$GVFS_CONFLICT" = true ] || [ "$PTP_BUSY" = true ] || [ "$CLAIMED_ERROR" = true ]; then
    echo "  🧹 Cleanup störende Prozesse..."
    
    sudo pkill -f gphoto2 2>/dev/null && echo "    ✅ gphoto2-Prozesse beendet" || true
    sudo pkill -f gvfs 2>/dev/null && echo "    ✅ GVFS-Prozesse beendet" || true
    sudo systemctl stop udisks2 2>/dev/null && echo "    ✅ udisks2 gestoppt" || true
    
    sleep 2
else
    echo "  ✅ Keine Prozess-Konflikte erkannt"
fi

# Fix 2: USB-Reset
echo "  🔄 USB-System Reset..."
if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    sudo modprobe -r usb_storage 2>/dev/null && echo "    🔄 USB-Storage Modul entladen"
    sleep 1
    sudo modprobe usb_storage 2>/dev/null && echo "    🔄 USB-Storage Modul geladen"
else
    echo "    ⚠️  Root-Rechte für USB-Reset nicht verfügbar"
fi

# Fix 3: Photobox Service Neustart
echo "  🔄 Photobox Service Neustart..."
if systemctl is-active --quiet photobox; then
    sudo systemctl restart photobox
    sleep 3
    
    if systemctl is-active --quiet photobox; then
        echo "    ✅ Service erfolgreich neugestartet"
    else
        echo "    ❌ Service-Neustart fehlgeschlagen"
    fi
else
    sudo systemctl start photobox
    sleep 3
    echo "    🚀 Service gestartet"
fi
echo

# 6. NACH-FIX VERIFIKATION
echo "6️⃣ Nach-Fix Verifikation..."

echo "  📷 Erneuter Kamera-Test:"
VERIFY_DETECT=$(timeout 5 gphoto2 --auto-detect 2>&1)
if echo "$VERIFY_DETECT" | grep -i canon >/dev/null; then
    echo "  ✅ Kamera jetzt erkannt!"
    
    echo "  📸 Capture-Verifikation:"
    VERIFY_CAPTURE=$(timeout 10 gphoto2 --capture-image 2>&1)
    if echo "$VERIFY_CAPTURE" | grep -q "New file is in location"; then
        echo "  ✅ Foto-Aufnahme funktioniert!"
        FINAL_STATUS="SUCCESS"
    else
        echo "  ⚠️  Erkennung OK, aber Capture-Problem"
        FINAL_STATUS="PARTIAL"
    fi
else
    echo "  ❌ Kamera immer noch nicht erkannt"
    FINAL_STATUS="FAILED"
fi

echo "  🌐 Photobox Web-Test:"
if curl -s http://localhost:5000/api/camera_status | grep -q '"connected".*true'; then
    echo "  ✅ Photobox Web-API: Kamera verbunden"
elif curl -s http://localhost:5000/api/camera_status >/dev/null 2>&1; then
    echo "  ⚠️  Photobox Web-API erreichbar, aber Kamera getrennt"
else
    echo "  ❌ Photobox Web-API nicht erreichbar"
fi
echo

# 7. FINAL REPORT & NEXT STEPS
echo "7️⃣ Diagnose-Bericht & Empfehlungen..."

case "$FINAL_STATUS" in
    "SUCCESS")
        echo "  🎉 PROBLEM GELÖST!"
        echo "  ✅ Kamera erkannt und funktionsfähig"
        echo "  🌐 Web-Interface: http://$(hostname -I | awk '{print $1}'):5000"
        ;;
        
    "PARTIAL")
        echo "  ⚠️  TEILWEISE GELÖST"
        echo "  ✅ Kamera erkannt, aber Capture-Probleme"
        echo "  💡 Empfohlene nächste Schritte:"
        echo "     - Vollständiges EDSDK Upgrade"
        echo "     - gphoto2 Python API Installation"
        ;;
        
    "FAILED")
        echo "  ❌ PROBLEM BESTEHT WEITER"
        echo "  🔧 Erweiterte Diagnose erforderlich:"
        echo "     1. Hardware-Check (anderes USB-Kabel, anderer Port)"
        echo "     2. Kamera-Einstellungen (USB-Modus, PC-Verbindung)"
        echo "     3. Vollständiger System-Neustart"
        ;;
esac

echo

echo "═══════════════════════════════════════════════════════════════"
echo "                      🎯 ZUSAMMENFASSUNG"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "📊 ERKANNTE PROBLEME:"
[ "$GVFS_CONFLICT" = true ] && echo "  🔴 GVFS-Prozess-Konflikte"
[ "$PTP_BUSY" = true ] && echo "  🔴 PTP Device Busy (0x2019)"
[ "$CLAIMED_ERROR" = true ] && echo "  🔴 Kamera bereits beansprucht"
[ "$GPHOTO2_DETECT_OK" = false ] && echo "  🔴 gphoto2 Erkennungs-Problem"

echo
echo "🔧 ANGEWENDETE FIXES:"
echo "  ✅ Prozess-Cleanup (gphoto2, GVFS, udisks2)"
echo "  ✅ USB-System Reset"
echo "  ✅ Photobox Service Neustart"

echo
echo "💡 FALLS PROBLEM WEITERHIN BESTEHT:"
echo
echo "1️⃣ SOFORTIGES API-UPGRADE (empfohlen):"
echo "   curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/upgrade_camera_apis.sh | sudo bash"
echo
echo "2️⃣ HARDWARE-CHECK:"
echo "   - Anderes USB-Kabel verwenden"
echo "   - Anderen USB-Port testen"  
echo "   - Kamera aus/einschalten"
echo
echo "3️⃣ KAMERA-EINSTELLUNGEN:"
echo "   - Canon Menü → USB-Modus → PC-Verbindung"
echo "   - Kamera-Display sollte 'PC' oder 'Computer' zeigen"
echo
echo "4️⃣ SYSTEM-NEUSTART:"
echo "   sudo reboot"
echo
echo "🔍 LIVE-MONITORING:"
echo "   sudo journalctl -u photobox -f"
echo
echo "✅ Debug-Analyse abgeschlossen!"