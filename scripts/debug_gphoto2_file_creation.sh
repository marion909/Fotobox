#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║            🔍 GPHOTO2 DATEI-ERSTELLUNG DEBUG                  ║
# ║         "Foto-Datei nicht erstellt oder zu klein"            ║
# ╚═══════════════════════════════════════════════════════════════╝

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               📸 GPHOTO2 DATEI-CREATION DEBUG                 ║"
echo "║           Foto-Datei nicht erstellt oder zu klein            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Konfiguration
PHOTO_DIR="/home/pi/Photobox/photos"
TEST_FILE="$PHOTO_DIR/debug_test_$(date +%Y%m%d_%H%M%S).jpg"
DOWNLOAD_DIR="/tmp/photobox_debug"

# Erstelle Test-Verzeichnisse
mkdir -p "$PHOTO_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "🔍 Kamera-Hardware Tests"
echo "  📍 Photo Dir: $PHOTO_DIR"
echo "  📍 Test File: $TEST_FILE"
echo

# 1. Basis-Kamera-Erkennung
echo "1️⃣ Kamera-Erkennung..."
gphoto2 --auto-detect
echo

# 2. Kamera-Konfiguration anzeigen
echo "2️⃣ Kamera-Konfiguration (kritische Einstellungen)..."
gphoto2 --get-config capturetarget 2>/dev/null || echo "  ⚠️ capturetarget nicht verfügbar"
gphoto2 --get-config imageformat 2>/dev/null || echo "  ⚠️ imageformat nicht verfügbar"
gphoto2 --get-config imagequality 2>/dev/null || echo "  ⚠️ imagequality nicht verfügbar"
echo

# 3. Aktuelle Dateien auf Kamera
echo "3️⃣ Dateien auf Kamera vor Test..."
gphoto2 --list-files 2>/dev/null | head -10
echo

# 4. Test 1: Standard capture-image (nur auf Kamera)
echo "4️⃣ Test 1: Standard Foto-Aufnahme (nur auf Kamera)..."
CAPTURE_RESULT=$(gphoto2 --capture-image 2>&1)
echo "$CAPTURE_RESULT"
if echo "$CAPTURE_RESULT" | grep -q "New file is in location"; then
    echo "  ✅ Foto auf Kamera erstellt"
    CAMERA_FILE=$(echo "$CAPTURE_RESULT" | grep "New file is in location" | awk '{print $NF}')
    echo "  📁 Kamera-Datei: $CAMERA_FILE"
else
    echo "  ❌ Foto-Aufnahme fehlgeschlagen"
fi
echo

# 5. Test 2: Capture + Download mit spezifischem Dateinamen
echo "5️⃣ Test 2: Foto aufnehmen und herunterladen..."
cd "$DOWNLOAD_DIR"
DOWNLOAD_RESULT=$(gphoto2 --capture-image-and-download --filename "$TEST_FILE" 2>&1)
echo "$DOWNLOAD_RESULT"

# Überprüfe Ergebnis-Datei
if [ -f "$TEST_FILE" ]; then
    FILE_SIZE=$(stat -f%z "$TEST_FILE" 2>/dev/null || stat -c%s "$TEST_FILE" 2>/dev/null)
    echo "  ✅ Datei erstellt: $TEST_FILE"
    echo "  📏 Dateigröße: $FILE_SIZE Bytes"
    
    if [ "$FILE_SIZE" -gt 1000 ]; then
        echo "  ✅ Dateigröße OK (> 1KB)"
    else
        echo "  ❌ Datei zu klein (< 1KB)"
    fi
    
    # Zeige erste Bytes (sollte JPEG-Header sein)
    echo "  🔍 Datei-Header (erste 20 Bytes):"
    hexdump -C "$TEST_FILE" | head -2
else
    echo "  ❌ Datei nicht erstellt: $TEST_FILE"
fi
echo

# 6. Test 3: Verzeichnis-Berechtigungen
echo "6️⃣ Verzeichnis-Berechtigungen Check..."
echo "  📂 $PHOTO_DIR:"
ls -la "$PHOTO_DIR" | head -5
echo "  🔐 Schreibrechte für pi:"
if [ -w "$PHOTO_DIR" ]; then
    echo "  ✅ pi kann in $PHOTO_DIR schreiben"
else
    echo "  ❌ pi kann NICHT in $PHOTO_DIR schreiben"
fi
echo

# 7. Test 4: Verschiedene Download-Methoden
echo "7️⃣ Alternative Download-Methoden..."

# Test A: Download ohne Capture
echo "  A) Download letzte Datei von Kamera:"
LAST_FILE=$(gphoto2 --list-files 2>/dev/null | grep -E '\.(jpg|JPG)' | tail -1 | awk '{print $1}')
if [ -n "$LAST_FILE" ]; then
    echo "    📁 Letzte Datei: $LAST_FILE"
    gphoto2 --get-file "$LAST_FILE" --filename "${DOWNLOAD_DIR}/downloaded_$(date +%s).jpg" 2>&1
else
    echo "    ⚠️ Keine JPEG-Dateien auf Kamera gefunden"
fi

# Test B: Capture zu anderem Ziel
echo "  B) Capture mit anderem Zielverzeichnis:"
cd /tmp
gphoto2 --capture-image-and-download --filename "/tmp/test_capture_$(date +%s).jpg" 2>&1
echo

# 8. Kamera-Reset für nächste Tests
echo "8️⃣ Kamera-Reset..."
pkill -f gphoto2 2>/dev/null || true
sleep 1
echo "  ✅ gphoto2-Prozesse beendet"
echo

# 9. Systeminfo
echo "9️⃣ System-Info..."
echo "  💾 Freier Speicher in $PHOTO_DIR:"
df -h "$PHOTO_DIR"
echo "  🔄 USB-Geräte:"
lsusb | grep -i canon || echo "    ⚠️ Keine Canon-Geräte in lsusb"
echo

echo "═══════════════════════════════════════════════════════════════"
echo "                     🔧 LÖSUNGSVORSCHLÄGE"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "📝 Häufige Ursachen für 'Datei nicht erstellt':"
echo
echo "1️⃣ KAMERA-KONFIGURATION:"
echo "   gphoto2 --set-config capturetarget=0  # Speichere auf Kamera"
echo "   gphoto2 --set-config imageformat=0    # JPEG Format"
echo
echo "2️⃣ BERECHTIGUNGS-FIX:"
echo "   sudo chown -R pi:pi $PHOTO_DIR"
echo "   sudo chmod -R 755 $PHOTO_DIR"
echo
echo "3️⃣ ALTERNATIVE CAPTURE-METHODE (in camera_manager.py):"
echo "   # Erst auf Kamera speichern, dann herunterladen:"
echo "   # gphoto2 --capture-image"
echo "   # gphoto2 --get-all-files --delete-after"
echo
echo "4️⃣ VERZEICHNIS-WECHSEL:"
echo "   # cd in Ziel-Verzeichnis vor gphoto2-Aufruf"
echo
echo "5️⃣ USB-RESET bei wiederholten Problemen:"
echo "   sudo modprobe -r usb_storage"
echo "   sudo modprobe usb_storage"
echo
echo "✅ Debug-Analyse abgeschlossen!"