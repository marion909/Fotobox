#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║                 📸 FOTOBOX MANAGEMENT TOOL                    ║
# ║           Unified Script für alle Fotobox-Operationen        ║
# ║                      Version: 1.0.0                          ║
# ╚═══════════════════════════════════════════════════════════════╝

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Konfiguration
PHOTOBOX_DIR="/home/pi/Fotobox"
SERVICE_USER="pi"
SCRIPT_VERSION="1.0.0"

# Utility-Funktionen
print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 📸 FOTOBOX MANAGEMENT TOOL                    ║${NC}"
    echo -e "${CYAN}║                      Version: $SCRIPT_VERSION                          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_menu() {
    echo -e "${BLUE}📋 Verfügbare Aktionen:${NC}"
    echo ""
    echo -e "${YELLOW}🔧 INSTALLATION & SETUP:${NC}"
    echo "  1) 🚀 Komplette Installation (install_complete.sh)"
    echo "  2) 📸 Optimal Camera Setup (setup_optimal_photobox.sh)"  
    echo "  3) 🖨️  Drucker Setup (setup_printer.sh)"
    echo "  4) ⚡ Autostart konfigurieren (install_autostart.sh)"
    echo ""
    echo -e "${YELLOW}🔍 DIAGNOSE & DEBUG:${NC}"
    echo "  5) 🔍 Vollständige Systemdiagnose"
    echo "  6) 📷 Kamera-Verbindungsprobleme debuggen"
    echo "  7) 🔧 Kamera USB-Probleme beheben"
    echo "  8) ⚠️  Canon EOS Device Busy Fix"
    echo "  9) 📁 Foto-Erstellungsprobleme debuggen"
    echo ""
    echo -e "${YELLOW}🛠️  WARTUNG & UPDATE:${NC}"
    echo "  10) 🔄 Fotobox updaten"
    echo "  11) ⚡ Quick-Fix (häufige Probleme)"
    echo "  12) 🧹 Vollständige Deinstallation"
    echo ""
    echo -e "${YELLOW}ℹ️  INFO & HILFE:${NC}"
    echo "  13) 📊 System-Status anzeigen"
    echo "  14) 📖 Hilfe & Dokumentation"
    echo "  15) 🚪 Beenden"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Root-Check-Funktion
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Diese Aktion benötigt Root-Rechte"
        echo "Bitte ausführen mit: sudo $0"
        exit 1
    fi
}

# Service-Status prüfen
check_service_status() {
    if systemctl is-active --quiet photobox.service 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# System-Status anzeigen
show_system_status() {
    echo -e "${CYAN}📊 FOTOBOX SYSTEM-STATUS${NC}"
    echo "=========================="
    echo ""
    
    # Service-Status
    if check_service_status; then
        print_success "Fotobox Service: Aktiv"
    else
        print_warning "Fotobox Service: Nicht aktiv"
    fi
    
    # Kamera-Status
    if command -v gphoto2 >/dev/null && timeout 5 gphoto2 --auto-detect | grep -q "usb:"; then
        print_success "Kamera: Erkannt"
    else
        print_warning "Kamera: Nicht erkannt"
    fi
    
    # Verzeichnis-Status
    if [ -d "$PHOTOBOX_DIR" ]; then
        print_success "Installation: $PHOTOBOX_DIR gefunden"
    else
        print_error "Installation: Nicht gefunden"
    fi
    
    # Python Environment
    if [ -f "$PHOTOBOX_DIR/.venv/bin/python" ]; then
        print_success "Python venv: Verfügbar"
    else
        print_warning "Python venv: Nicht gefunden"
    fi
    
    echo ""
}

# Komplette Installation
run_complete_installation() {
    check_root
    print_status "Starte komplette Fotobox-Installation..."
    
    # Prüfe ob install_complete.sh existiert
    if [ -f "$(dirname "$0")/install_complete.sh" ]; then
        bash "$(dirname "$0")/install_complete.sh"
    else
        print_status "Lade install_complete.sh von GitHub..."
        curl -fsSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/install_complete.sh | bash
    fi
}

# Optimal Camera Setup
run_optimal_setup() {
    print_status "Starte Optimal Camera Setup..."
    
    if [ -f "$(dirname "$0")/setup_optimal_photobox.sh" ]; then
        bash "$(dirname "$0")/setup_optimal_photobox.sh"
    else
        print_status "Lade setup_optimal_photobox.sh von GitHub..."
        curl -fsSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/setup_optimal_photobox.sh | bash
    fi
}

# Kamera-Diagnose (zusammengefasst)
run_camera_diagnosis() {
    print_status "Führe umfassende Kamera-Diagnose durch..."
    
    echo -e "${BLUE}1. Hardware-Verbindung prüfen...${NC}"
    echo "USB-Geräte:"
    lsusb | grep -i canon || echo "  Keine Canon-Geräte gefunden"
    
    echo -e "\n${BLUE}2. gphoto2 Kamera-Erkennung...${NC}"
    if command -v gphoto2 >/dev/null; then
        gphoto2 --auto-detect
    else
        print_error "gphoto2 nicht installiert"
    fi
    
    echo -e "\n${BLUE}3. USB-Prozesse prüfen...${NC}"
    if pgrep -f gphoto2 >/dev/null; then
        print_warning "gphoto2 Prozesse laufen bereits:"
        pgrep -f gphoto2 | xargs ps -p
    else
        print_success "Keine blockierenden gphoto2 Prozesse"
    fi
    
    echo -e "\n${BLUE}4. GVFS-Konflikte prüfen...${NC}"
    if systemctl is-active --quiet gvfs-daemon 2>/dev/null; then
        print_warning "GVFS-Daemon aktiv (kann USB blockieren)"
        echo "  Tipp: sudo systemctl stop gvfs-daemon"
    else
        print_success "Keine GVFS-Konflikte"
    fi
    
    echo -e "\n${BLUE}5. Test-Foto Aufnahme...${NC}"
    if command -v gphoto2 >/dev/null && gphoto2 --auto-detect | grep -q "usb:"; then
        print_status "Versuche Test-Foto..."
        if timeout 10 gphoto2 --capture-image >/dev/null 2>&1; then
            print_success "Test-Foto erfolgreich!"
        else
            print_error "Test-Foto fehlgeschlagen"
            echo "  Mögliche Ursachen:"
            echo "  - Kamera nicht auf 'PC Connect' Modus"
            echo "  - USB-Kabel defekt"
            echo "  - Kamera-Akku leer"
        fi
    else
        print_warning "Keine Kamera für Test verfügbar"
    fi
}

# USB-Fix (zusammengefasst)
run_usb_fix() {
    check_root
    print_status "Führe USB-Kamera-Fix durch..."
    
    # Stoppe blockierende Prozesse
    print_status "Stoppe blockierende Prozesse..."
    killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true
    
    # GVFS temporär stoppen
    if systemctl is-active --quiet gvfs-daemon; then
        systemctl stop gvfs-daemon
        print_status "GVFS-Daemon gestoppt"
    fi
    
    # USB-Module zurücksetzen
    print_status "Setze USB-Module zurück..."
    modprobe -r uvcvideo 2>/dev/null || true
    sleep 2
    modprobe uvcvideo 2>/dev/null || true
    
    # Warte auf USB-Enumeration
    sleep 5
    
    print_success "USB-Fix abgeschlossen"
    
    # Test
    if timeout 5 gphoto2 --auto-detect | grep -q "usb:"; then
        print_success "Kamera erfolgreich erkannt!"
    else
        print_warning "Kamera noch nicht erkannt - möglicherweise Hardware-Problem"
    fi
}

# Update-Funktion
run_update() {
    check_root
    print_status "Aktualisiere Fotobox..."
    
    cd "$PHOTOBOX_DIR" 2>/dev/null || {
        print_error "Fotobox-Verzeichnis nicht gefunden: $PHOTOBOX_DIR"
        return 1
    }
    
    # Git-Update
    if [ -d ".git" ]; then
        print_status "Aktualisiere Code von GitHub..."
        git pull origin master
    else
        print_warning "Kein Git-Repository - überspringe Code-Update"
    fi
    
    # Service neustarten
    if systemctl is-active --quiet photobox.service; then
        print_status "Starte Service neu..."
        systemctl restart photobox.service
    fi
    
    print_success "Update abgeschlossen"
}

# Quick-Fix
run_quick_fix() {
    check_root
    print_status "Führe Quick-Fix durch..."
    
    # Log-Berechtigungen
    mkdir -p /var/log/photobox
    touch /var/log/photobox_startup.log /var/log/photobox_app.log
    chown pi:pi /var/log/photobox /var/log/photobox_startup.log /var/log/photobox_app.log
    chmod 755 /var/log/photobox
    chmod 664 /var/log/photobox_startup.log /var/log/photobox_app.log
    
    # Verzeichnis-Berechtigungen
    if [ -d "$PHOTOBOX_DIR" ]; then
        chown -R pi:pi "$PHOTOBOX_DIR"
        mkdir -p "$PHOTOBOX_DIR"/{photos,overlays,temp,backups,logs}
        chown -R pi:pi "$PHOTOBOX_DIR"/{photos,overlays,temp,backups,logs}
    fi
    
    # Service-Check
    if systemctl list-unit-files | grep -q photobox.service; then
        if ! systemctl is-active --quiet photobox.service; then
            print_status "Starte Photobox Service..."
            systemctl start photobox.service
        fi
    fi
    
    print_success "Quick-Fix abgeschlossen"
}

# Cleanup-Funktion
run_cleanup() {
    check_root
    print_warning "ACHTUNG: Dies entfernt die komplette Fotobox-Installation!"
    read -p "Wirklich fortfahren? (ja/NEIN): " confirm
    
    if [ "$confirm" = "ja" ]; then
        print_status "Entferne Fotobox..."
        
        # Service stoppen und entfernen
        systemctl stop photobox.service 2>/dev/null || true
        systemctl disable photobox.service 2>/dev/null || true
        rm -f /etc/systemd/system/photobox.service
        
        # Verzeichnisse entfernen
        rm -rf "$PHOTOBOX_DIR"
        rm -rf /var/log/photobox*
        
        # Autostart entfernen
        rm -f /home/pi/.config/autostart/photobox-kiosk.desktop
        
        print_success "Fotobox vollständig entfernt"
    else
        print_status "Abgebrochen"
    fi
}

# Hilfe anzeigen
show_help() {
    echo -e "${CYAN}📖 FOTOBOX MANAGEMENT TOOL - HILFE${NC}"
    echo "===================================="
    echo ""
    echo -e "${YELLOW}VERWENDUNG:${NC}"
    echo "  sudo ./manage_fotobox.sh [OPTION]"
    echo ""
    echo -e "${YELLOW}OPTIONEN:${NC}"
    echo "  --install         Komplette Installation"
    echo "  --camera-setup    Optimal Camera Setup"
    echo "  --diagnose        Kamera-Diagnose"
    echo "  --fix-usb         USB-Probleme beheben"
    echo "  --update          System updaten"
    echo "  --quick-fix       Häufige Probleme beheben"
    echo "  --status          System-Status anzeigen"
    echo "  --cleanup         Vollständige Deinstallation"
    echo "  --help            Diese Hilfe anzeigen"
    echo ""
    echo -e "${YELLOW}BEISPIELE:${NC}"
    echo "  sudo ./manage_fotobox.sh --install"
    echo "  sudo ./manage_fotobox.sh --diagnose"
    echo "  ./manage_fotobox.sh --status"
    echo ""
    echo -e "${YELLOW}WEITERE RESSOURCEN:${NC}"
    echo "  • GitHub: https://github.com/marion909/Fotobox"
    echo "  • Issues: https://github.com/marion909/Fotobox/issues"
    echo "  • Wiki: https://github.com/marion909/Fotobox/wiki"
    echo ""
}

# Hauptmenü-Loop
main_menu() {
    while true; do
        clear
        print_header
        show_system_status
        print_menu
        
        echo -n "Wählen Sie eine Option (1-15): "
        read -r choice
        echo ""
        
        case $choice in
            1) run_complete_installation ;;
            2) run_optimal_setup ;;
            3) bash "$(dirname "$0")/setup_printer.sh" 2>/dev/null || print_error "setup_printer.sh nicht gefunden" ;;
            4) bash "$(dirname "$0")/install_autostart.sh" 2>/dev/null || print_error "install_autostart.sh nicht gefunden" ;;
            5) run_camera_diagnosis ;;
            6) run_camera_diagnosis ;;
            7) run_usb_fix ;;
            8) run_usb_fix ;;  # Device Busy ist meist USB-Problem
            9) run_camera_diagnosis ;;  # Foto-Erstellung ist Teil der Diagnose
            10) run_update ;;
            11) run_quick_fix ;;
            12) run_cleanup ;;
            13) show_system_status ;;
            14) show_help ;;
            15) 
                print_success "Auf Wiedersehen!"
                exit 0
                ;;
            *)
                print_error "Ungültige Auswahl. Bitte 1-15 eingeben."
                ;;
        esac
        
        echo ""
        read -p "Drücken Sie Enter um fortzufahren..." -r
    done
}

# Command-Line Interface
case "${1:-}" in
    --install)
        run_complete_installation
        ;;
    --camera-setup)
        run_optimal_setup
        ;;
    --diagnose)
        run_camera_diagnosis
        ;;
    --fix-usb)
        run_usb_fix
        ;;
    --update)
        run_update
        ;;
    --quick-fix)
        run_quick_fix
        ;;
    --status)
        show_system_status
        ;;
    --cleanup)
        run_cleanup
        ;;
    --help)
        show_help
        ;;
    "")
        # Keine Parameter - starte interaktives Menü
        main_menu
        ;;
    *)
        print_error "Unbekannte Option: $1"
        echo "Verwenden Sie --help für Hilfe"
        exit 1
        ;;
esac