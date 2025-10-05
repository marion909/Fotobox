#!/bin/bash

# Canon EOS Kamera Diagnose und Fix Script
# Speziell für "Could not claim device" und andere Canon-Probleme

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   📷 KAMERA DIAGNOSE & FIX                   ║"
echo "║               Canon EOS Troubleshooting                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Funktionen
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

print_fix() {
    echo -e "${YELLOW}🔧 $1${NC}"
}

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Bitte als root ausführen: sudo $0${NC}"
    exit 1
fi

echo ""

# 1. Kamera-Erkennung
print_check "USB-Kamera Erkennung"
USB_CAMERAS=$(lsusb | grep -i canon)
if [ -n "$USB_CAMERAS" ]; then
    print_ok "Canon Kamera per USB gefunden:"
    echo "$USB_CAMERAS" | while IFS= read -r line; do
        print_info "$line"
    done
else
    print_error "Keine Canon Kamera per USB gefunden!"
    print_info "Prüfe USB-Kabel und Kamera-Einstellungen"
    exit 1
fi

# 2. gphoto2 Erkennung
print_check "gphoto2 Kamera-Erkennung"
GPHOTO_DETECT=$(timeout 10 gphoto2 --auto-detect 2>/dev/null)
GPHOTO_CAMERAS=$(echo "$GPHOTO_DETECT" | grep -i canon | wc -l)

if [ "$GPHOTO_CAMERAS" -gt 0 ]; then
    print_ok "gphoto2 erkennt $GPHOTO_CAMERAS Canon Kamera(s):"
    echo "$GPHOTO_DETECT" | grep -i canon | while IFS= read -r line; do
        print_info "$line"
    done
else
    print_error "gphoto2 erkennt keine Canon Kameras!"
fi

# 3. Störende Prozesse prüfen
print_check "Störende Prozesse"
GPHOTO_PROCS=$(ps aux | grep -v grep | grep gphoto2 | wc -l)
GVFS_PROCS=$(ps aux | grep -v grep | grep gvfs | wc -l)

if [ "$GPHOTO_PROCS" -gt 0 ]; then
    print_warning "$GPHOTO_PROCS gphoto2 Prozesse laufen"
    ps aux | grep -v grep | grep gphoto2 | while IFS= read -r line; do
        print_info "$line"
    done
else
    print_ok "Keine störenden gphoto2 Prozesse"
fi

if [ "$GVFS_PROCS" -gt 0 ]; then
    print_warning "$GVFS_PROCS GVFS Prozesse laufen (können stören)"
else
    print_ok "Keine störenden GVFS Prozesse"
fi

# 4. Kamera-Status Test
print_check "Kamera-Status Test"
CAMERA_STATUS=$(timeout 15 gphoto2 --get-config /main/status/serialnumber 2>&1)
if echo "$CAMERA_STATUS" | grep -q "Choice"; then
    print_ok "Kamera antwortet auf Konfigurationsabfrage"
    SERIAL=$(echo "$CAMERA_STATUS" | grep "Current:" | cut -d: -f2 | xargs)
    if [ -n "$SERIAL" ]; then
        print_info "Seriennummer: $SERIAL"
    fi
else
    print_error "Kamera antwortet nicht auf Konfigurationsabfrage"
    print_info "Fehler: $CAMERA_STATUS"
fi

# 5. Test-Foto Versuch
print_check "Test-Foto Aufnahme"
echo -e "${YELLOW}Versuche Test-Foto (kann bis zu 30 Sekunden dauern)...${NC}"

# Alle störenden Prozesse beenden
killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true
sleep 2

TEST_CAPTURE=$(timeout 30 gphoto2 --capture-image 2>&1)
CAPTURE_EXIT_CODE=$?

if [ $CAPTURE_EXIT_CODE -eq 0 ]; then
    print_ok "Test-Foto erfolgreich aufgenommen"
else
    print_error "Test-Foto fehlgeschlagen (Exit Code: $CAPTURE_EXIT_CODE)"
    print_info "Fehler: $TEST_CAPTURE"
    
    # Spezifische Fehler analysieren
    if echo "$TEST_CAPTURE" | grep -q "Could not claim"; then
        print_warning "Typischer 'Could not claim device' Fehler erkannt"
    elif echo "$TEST_CAPTURE" | grep -q "Device busy"; then
        print_warning "Device Busy Fehler (0x2019) erkannt"
    elif echo "$TEST_CAPTURE" | grep -q "Out of Focus"; then
        print_warning "Fokus-Problem erkannt - Kamera auf manuellen Fokus stellen"
    fi
fi

# 6. Kamera-Einstellungen prüfen
print_check "Kamera-Einstellungen"

# Capture Target
CAPTURE_TARGET=$(timeout 10 gphoto2 --get-config capturetarget 2>/dev/null | grep "Current:" | cut -d: -f2 | xargs)
if [ "$CAPTURE_TARGET" = "Memory card" ]; then
    print_warning "Capture Target: Memory card (sollte 'Internal RAM' sein)"
    print_info "Ändere zu Internal RAM für bessere Performance"
elif [ "$CAPTURE_TARGET" = "Internal RAM" ]; then
    print_ok "Capture Target: Internal RAM (optimal)"
else
    print_info "Capture Target: $CAPTURE_TARGET"
fi

# Image Format
IMAGE_FORMAT=$(timeout 10 gphoto2 --get-config imageformat 2>/dev/null | grep "Current:" | cut -d: -f2 | xargs)
if [ -n "$IMAGE_FORMAT" ]; then
    print_info "Image Format: $IMAGE_FORMAT"
    if echo "$IMAGE_FORMAT" | grep -q "RAW"; then
        print_warning "RAW Format kann langsam sein - JPEG empfohlen"
    fi
fi

echo ""
print_fix "AUTOMATISCHE PROBLEMLÖSUNG"

# Fix 1: Prozesse beenden
echo -e "${YELLOW}1. Beende störende Prozesse...${NC}"
killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true
if systemctl --quiet is-active gvfs-daemon; then
    systemctl stop gvfs-daemon
    print_ok "GVFS Daemon gestoppt"
fi

# Fix 2: USB zurücksetzen
echo -e "${YELLOW}2. USB-Module zurücksetzen...${NC}"
modprobe -r uvcvideo 2>/dev/null || true
sleep 2
modprobe uvcvideo 2>/dev/null || true
print_ok "USB-Module zurückgesetzt"

# Fix 3: udev-Regeln prüfen
echo -e "${YELLOW}3. Prüfe udev-Regeln...${NC}"
if [ -f "/etc/udev/rules.d/40-gphoto2-disable-gvfs.rules" ]; then
    print_ok "gphoto2 udev-Regeln vorhanden"
else
    print_warning "Erstelle gphoto2 udev-Regeln..."
    cat > /etc/udev/rules.d/40-gphoto2-disable-gvfs.rules << 'EOF'
# Deaktiviert GVFS Auto-Mount für gphoto2-kompatible Kameras
ENV{ID_GPHOTO2}=="1", ENV{UDISKS_IGNORE}="1"

# Canon-spezifische Regel (EOS Serie)
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{idProduct}=="*", MODE="0666", GROUP="plugdev"

# Weitere Canon-Geräte
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", MODE="0666", GROUP="plugdev"
EOF
    udevadm control --reload-rules
    print_ok "udev-Regeln erstellt und geladen"
fi

# Fix 4: Kamera-Einstellungen optimieren
echo -e "${YELLOW}4. Optimiere Kamera-Einstellungen...${NC}"
sleep 3

# Setze Capture Target auf Internal RAM
if timeout 15 gphoto2 --set-config capturetarget=0 2>/dev/null; then
    print_ok "Capture Target auf Internal RAM gesetzt"
else
    print_warning "Konnte Capture Target nicht setzen"
fi

# Fix 5: Test nach Fixes
echo -e "${YELLOW}5. Test nach Optimierung...${NC}"
sleep 2

FINAL_TEST=$(timeout 20 gphoto2 --capture-image 2>&1)
FINAL_EXIT_CODE=$?

if [ $FINAL_EXIT_CODE -eq 0 ]; then
    print_ok "✨ Test-Foto nach Fix erfolgreich!"
    
    # Lösche Test-Foto
    rm -f capt*.jpg 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}🎉 KAMERA FUNKTIONIERT JETZT!${NC}"
    echo ""
    echo -e "${BLUE}📋 Empfohlene Kamera-Einstellungen (Canon EOS):${NC}"
    echo "   • USB-Modus: 'PC Connect' oder 'PTP'"
    echo "   • Auto Power Off: Deaktivieren oder 30min"
    echo "   • Shooting Mode: Manual (M) oder Av"
    echo "   • Image Quality: JPEG Large Fine"
    echo "   • Fokus: Manuell oder One-Shot AF"
    
else
    print_error "Test-Foto nach Fix immer noch fehlgeschlagen"
    print_info "Fehler: $FINAL_TEST"
    
    echo ""
    echo -e "${YELLOW}🔧 WEITERE SCHRITTE:${NC}"
    echo ""
    echo -e "${BLUE}1. Kamera-Einstellungen prüfen:${NC}"
    echo "   • Kamera auf 'PC Connect' Modus stellen"
    echo "   • Auto Power Off deaktivieren"
    echo "   • USB-Kabel fest angeschlossen?"
    echo ""
    echo -e "${BLUE}2. Häufige Canon EOS Probleme:${NC}"
    echo "   • Kamera im 'Mass Storage' Modus → Auf 'PTP' ändern"
    echo "   • SD-Karte voll → Platz schaffen oder entfernen"
    echo "   • Akku schwach → Vollständig laden"
    echo "   • Objektiv nicht angeschlossen → Objektiv prüfen"
    echo ""
    echo -e "${BLUE}3. Manuelle Tests:${NC}"
    echo "   gphoto2 --auto-detect"
    echo "   gphoto2 --capture-image"
    echo "   gphoto2 --get-config /main/status/serialnumber"
fi

# Fix 6: Photobox Service neu starten
if systemctl list-unit-files | grep -q photobox.service; then
    echo -e "${YELLOW}6. Starte Photobox Service neu...${NC}"
    systemctl restart photobox
    if systemctl is-active --quiet photobox; then
        print_ok "Photobox Service läuft wieder"
    else
        print_warning "Photobox Service Problem - manuell prüfen"
    fi
fi

echo ""
echo -e "${GREEN}✅ Kamera-Diagnose und Fix abgeschlossen!${NC}"
echo ""
echo -e "${PURPLE}💡 Tipp: Bei weiterhin Problemen Kamera kurz aus- und einschalten${NC}"