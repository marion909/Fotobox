#!/bin/bash

# 📸 Photobox Camera USB Fix Script
# Behebt "Could not claim the USB device" Fehler
# Für Canon EOS Kameras mit gphoto2

echo "🔧 Photobox Camera USB Fix Script"
echo "================================="
echo "Behebt USB-Probleme mit Canon EOS Kameras"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Prüfung ob Script als Root läuft
if [[ $EUID -eq 0 ]]; then
    log_warning "Script läuft als Root. Das ist OK für System-Fixes."
    IS_ROOT=true
else
    log_info "Script läuft als normaler Benutzer. Sudo wird bei Bedarf gefragt."
    IS_ROOT=false
fi

# Schritt 1: Aktuelle Situation prüfen
log_info "1. Prüfe aktuelle Kamera-Verbindung..."
echo ""

# USB-Geräte anzeigen
log_info "USB-Geräte (Canon Kameras):"
lsusb | grep -i canon || log_warning "Keine Canon-Kamera per USB erkannt"
echo ""

# Laufende gphoto2 Prozesse
log_info "Laufende gphoto2 Prozesse:"
ps aux | grep gphoto | grep -v grep || log_info "Keine gphoto2 Prozesse aktiv"
echo ""

# Schritt 2: Alle gphoto2 und GVFS Prozesse beenden
log_info "2. Beende alle Kamera-Prozesse..."

# gphoto2 Prozesse beenden
if pgrep gphoto2 > /dev/null; then
    log_info "Beende gphoto2 Prozesse..."
    sudo killall gphoto2 2>/dev/null
    log_success "gphoto2 Prozesse beendet"
else
    log_info "Keine gphoto2 Prozesse aktiv"
fi

# GVFS Prozesse beenden (Hauptverursacher des Problems)
if pgrep gvfs-gphoto2-volume-monitor > /dev/null; then
    log_info "Beende GVFS Volume Monitor..."
    sudo killall gvfs-gphoto2-volume-monitor 2>/dev/null
    log_success "GVFS Volume Monitor beendet"
else
    log_info "GVFS Volume Monitor nicht aktiv"
fi

# Alle gphoto-bezogenen Prozesse beenden
sudo pkill -f gphoto 2>/dev/null
log_success "Alle gphoto-Prozesse beendet"

# Schritt 3: GVFS Daemon temporär stoppen
log_info "3. Stoppe GVFS Daemon temporär..."
sudo systemctl stop gvfs-daemon 2>/dev/null
log_success "GVFS Daemon gestoppt"

# Schritt 4: USB-Module neu laden (optional)
log_info "4. USB-Module prüfen..."
if lsmod | grep -q uvcvideo; then
    log_info "Entferne uvcvideo Modul..."
    sudo modprobe -r uvcvideo 2>/dev/null
    log_success "uvcvideo Modul entfernt"
fi

# Schritt 5: Warte auf Benutzer-Aktion
echo ""
log_warning "WICHTIG: Jetzt die Kamera USB-Verbindung neu herstellen!"
echo ""
echo "Bitte folgende Schritte durchführen:"
echo "1. USB-Kabel von der Kamera abziehen"
echo "2. 10 Sekunden warten"
echo "3. USB-Kabel wieder anschließen"
echo "4. Sicherstellen dass Kamera eingeschaltet ist"
echo "5. Kamera-Modus auf 'PC Connect' oder 'PTP' stellen (nicht 'Mass Storage')"
echo ""
read -p "Drücken Sie Enter wenn die Kamera neu verbunden wurde..."

# Schritt 6: Kamera-Erkennung testen
log_info "6. Teste Kamera-Erkennung..."
echo ""

# USB-Erkennung prüfen
log_info "USB-Erkennung:"
if lsusb | grep -i canon; then
    log_success "Canon-Kamera per USB erkannt!"
else
    log_error "Keine Canon-Kamera per USB erkannt"
    echo "Mögliche Ursachen:"
    echo "- Kamera nicht eingeschaltet"
    echo "- USB-Kabel defekt"
    echo "- Kamera im falschen USB-Modus"
    echo "- USB-Port defekt"
fi
echo ""

# gphoto2 Erkennung testen
log_info "gphoto2 Erkennung:"
if timeout 10 gphoto2 --auto-detect | grep -q Canon; then
    log_success "Kamera von gphoto2 erkannt!"
    gphoto2 --auto-detect | grep Canon
else
    log_error "Kamera nicht von gphoto2 erkannt"
fi
echo ""

# Schritt 7: Test-Foto aufnehmen
log_info "7. Teste Foto-Aufnahme..."
if gphoto2 --capture-image 2>/dev/null; then
    log_success "Test-Foto erfolgreich aufgenommen!"
else
    log_warning "Test-Foto fehlgeschlagen - siehe Debugging-Schritte unten"
fi
echo ""

# Schritt 8: Permanente Lösung anbieten
log_info "8. Permanente Lösung installieren (optional)..."
echo ""
echo "Möchten Sie eine permanente Lösung installieren?"
echo "Dies verhindert, dass GVFS automatisch die Kamera beansprucht."
echo ""
read -p "Permanente Lösung installieren? (j/N): " install_permanent

if [[ $install_permanent =~ ^[Jj]$ ]]; then
    log_info "Installiere permanente udev-Regel..."
    
    # udev-Regel erstellen
    cat << 'EOF' | sudo tee /etc/udev/rules.d/40-gphoto2-disable-gvfs.rules > /dev/null
# Deaktiviert GVFS Auto-Mount für gphoto2-kompatible Kameras
# Verhindert "Could not claim USB device" Fehler
ENV{ID_GPHOTO2}=="1", ENV{UDISKS_IGNORE}="1"

# Canon-spezifische Regel (EOS Serie)
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{idProduct}=="*", MODE="0666", GROUP="plugdev"
EOF
    
    # udev-Regeln neu laden
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    log_success "Permanente Lösung installiert!"
    log_info "Die Lösung wird nach einem Neustart aktiv."
else
    log_info "Permanente Lösung übersprungen."
fi

# Schritt 9: Debugging-Informationen
echo ""
log_info "9. Debugging-Informationen (falls Probleme bestehen):"
echo ""
echo "Wenn die Kamera immer noch nicht funktioniert:"
echo ""
echo "1. Detailliertes Debugging:"
echo "   env LANG=C gphoto2 --debug --debug-logfile=camera-debug.txt --auto-detect"
echo "   cat camera-debug.txt | grep -i error"
echo ""
echo "2. USB-Permissions prüfen:"
echo "   ls -la /dev/bus/usb/*/"
echo "   groups \$USER | grep -E 'plugdev|dialout'"
echo ""
echo "3. Kamera-Einstellungen prüfen:"
echo "   - USB-Verbindung auf 'PC Connect' oder 'PTP'"
echo "   - Auto-Power-Off deaktiviert"
echo "   - Kamera im manuellen oder Av/Tv Modus"
echo ""
echo "4. Hardware prüfen:"
echo "   - Anderes USB-Kabel testen"
echo "   - Anderen USB-Port testen"
echo "   - Kamera-Akku voll geladen"
echo ""
echo "5. GVFS vollständig deaktivieren (falls nötig):"
echo "   sudo systemctl disable gvfs-daemon"
echo "   sudo systemctl mask gvfs-daemon"
echo ""

# Zusammenfassung
echo ""
log_info "=== ZUSAMMENFASSUNG ==="
if lsusb | grep -i canon > /dev/null && timeout 5 gphoto2 --auto-detect | grep -q Canon; then
    log_success "✅ Kamera erfolgreich repariert!"
    echo ""
    echo "Die Kamera sollte jetzt mit der Photobox funktionieren."
    echo "Starten Sie die Photobox-App und testen Sie die Foto-Funktion."
else
    log_warning "⚠️  Kamera-Problem noch nicht vollständig gelöst"
    echo ""
    echo "Bitte führen Sie die Debugging-Schritte durch oder:"
    echo "- Prüfen Sie die Kamera-Einstellungen"
    echo "- Testen Sie ein anderes USB-Kabel"
    echo "- Kontaktieren Sie den Support"
fi

echo ""
echo "📸 Viel Erfolg mit Ihrer Photobox!"