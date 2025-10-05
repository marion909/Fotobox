#!/bin/bash

# Photobox Installation Script für Raspberry Pi
# Führt die komplette Einrichtung der Photobox durch

set -e

echo "🚀 Photobox Installation gestartet..."

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Überprüfe ob auf Raspberry Pi
check_platform() {
    if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
        print_warning "Nicht auf Raspberry Pi - Installation fortsetzen? (y/n)"
        read -r response
        if [[ ! $response =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Raspberry Pi erkannt"
    fi
}

# System Update
update_system() {
    print_status "System wird aktualisiert..."
    sudo apt update && sudo apt upgrade -y
    print_success "System aktualisiert"
}

# Abhängigkeiten installieren
install_dependencies() {
    print_status "Installiere System-Abhängigkeiten..."
    
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        git \
        gphoto2 \
        libgphoto2-dev \
        chromium-browser \
        cups \
        cups-client \
        unclutter \
        xdotool
    
    print_success "System-Abhängigkeiten installiert"
}

# Python Virtual Environment
setup_python_env() {
    print_status "Erstelle Python Virtual Environment..."
    
    cd /home/pi
    python3 -m venv photobox-env
    source photobox-env/bin/activate
    
    pip install --upgrade pip
    pip install flask==2.3.3 pillow==10.0.1 requests==2.31.0
    
    print_success "Python Environment erstellt"
}

# Kamera testen
test_camera() {
    print_status "Teste Kamera-Verbindung..."
    
    if gphoto2 --auto-detect | grep -q "Canon"; then
        print_success "Canon Kamera erkannt"
        gphoto2 --summary | head -10
    else
        print_warning "Keine Canon Kamera gefunden"
        print_status "Verfügbare USB-Geräte:"
        lsusb | grep -i canon || true
    fi
}

# Systemd Service einrichten
setup_service() {
    print_status "Richte Systemd Service ein..."
    
    sudo cp photobox.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable photobox.service
    
    print_success "Systemd Service konfiguriert"
}

# Autostart für Kiosk-Modus (optional)
setup_kiosk_mode() {
    print_status "Kiosk-Modus einrichten? (y/n)"
    read -r response
    
    if [[ $response =~ ^[Yy]$ ]]; then
        print_status "Richte Kiosk-Modus ein..."
        
        # Autostart Ordner erstellen
        mkdir -p /home/pi/.config/lxsession/LXDE-pi
        
        # Autostart-Datei erstellen
        cat > /home/pi/.config/lxsession/LXDE-pi/autostart << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash

# Photobox Kiosk-Modus
@unclutter -idle 1
@chromium-browser --noerrdialogs --disable-infobars --kiosk http://localhost:5000
EOF
        
        print_success "Kiosk-Modus konfiguriert"
    fi
}

# Drucker einrichten (optional)
setup_printer() {
    print_status "Drucker einrichten? (y/n)"
    read -r response
    
    if [[ $response =~ ^[Yy]$ ]]; then
        print_status "CUPS Web-Interface verfügbar unter: http://localhost:631"
        print_status "Drucker manuell über Web-Interface hinzufügen"
        
        # CUPS für Netzwerk-Zugriff aktivieren
        sudo usermod -a -G lpadmin pi
        
        print_status "Benutzer 'pi' zu lpadmin Gruppe hinzugefügt"
    fi
}

# Verzeichnisse erstellen
create_directories() {
    print_status "Erstelle Projektverzeichnisse..."
    
    mkdir -p /home/pi/photobox/{photos,overlays,temp,logs}
    chmod 755 /home/pi/photobox/photos
    
    print_success "Verzeichnisse erstellt"
}

# Berechtigungen setzen
set_permissions() {
    print_status "Setze Berechtigungen..."
    
    chown -R pi:pi /home/pi/photobox
    chmod +x /home/pi/photobox/app.py
    
    print_success "Berechtigungen gesetzt"
}

# Service starten
start_service() {
    print_status "Starte Photobox Service..."
    
    sudo systemctl start photobox.service
    sleep 3
    
    if sudo systemctl is-active --quiet photobox.service; then
        print_success "Photobox Service läuft"
        print_status "Status: $(sudo systemctl is-active photobox.service)"
    else
        print_error "Service konnte nicht gestartet werden"
        print_status "Logs anzeigen: sudo journalctl -u photobox.service -f"
    fi
}

# Abschlussmeldung
finish_installation() {
    echo ""
    echo "🎉 Photobox Installation abgeschlossen!"
    echo ""
    echo "📋 Nächste Schritte:"
    echo "  1. Kamera per USB verbinden"
    echo "  2. Browser öffnen: http://localhost:5000"
    echo "  3. Foto-Test durchführen"
    echo ""
    echo "🔧 Verwaltung:"
    echo "  Status prüfen: sudo systemctl status photobox.service"
    echo "  Logs anzeigen: sudo journalctl -u photobox.service -f"
    echo "  Service stoppen: sudo systemctl stop photobox.service"
    echo "  Service starten: sudo systemctl start photobox.service"
    echo ""
    echo "🖨️ Drucker einrichten: http://localhost:631"
    echo "⚙️ Admin-Panel: http://localhost:5000/admin"
    echo ""
    
    if [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
        echo "🔄 Neustart empfohlen für optimale Performance"
        echo "   sudo reboot"
    fi
}

# Hauptinstallation
main() {
    echo "🚀 Photobox Automatische Installation"
    echo "====================================="
    
    check_platform
    update_system
    install_dependencies
    setup_python_env
    create_directories
    set_permissions
    test_camera
    setup_service
    setup_kiosk_mode
    setup_printer
    start_service
    finish_installation
}

# Fehlerbehandlung
trap 'print_error "Installation fehlgeschlagen in Zeile $LINENO"' ERR

# Installation starten
main "$@"