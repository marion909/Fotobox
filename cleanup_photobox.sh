#!/bin/bash

# 🧹 Photobox Cleanup Script
# Entfernt alle Photobox-Daten und Konfigurationen vollständig

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${RED}🧹 Photobox Cleanup Script${NC}"
echo "=========================="
echo ""
echo -e "${YELLOW}⚠️  WARNUNG: Dieses Script entfernt ALLE Photobox-Daten!${NC}"
echo -e "${YELLOW}    - Alle aufgenommenen Fotos${NC}"
echo -e "${YELLOW}    - Konfigurationsdateien${NC}"
echo -e "${YELLOW}    - Systemd Services${NC}"
echo -e "${YELLOW}    - Autostart-Konfiguration${NC}"
echo -e "${YELLOW}    - System-Optimierungen${NC}"
echo ""

# Funktionen
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

print_step() {
    echo ""
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Variablen
INSTALL_DIR="/home/pi/Fotobox"
SERVICE_USER="pi"
BACKUP_DIR="/home/pi/photobox_backup"

# Bestätigung vom Benutzer
if [ "$1" != "--force" ]; then
    echo -e "${RED}Sind Sie sicher, dass Sie ALLE Photobox-Daten löschen möchten?${NC}"
    echo "Dies kann NICHT rückgängig gemacht werden!"
    echo ""
    echo "Folgende Daten werden gelöscht:"
    echo "  • Photobox-Installation: $INSTALL_DIR"
    echo "  • Alle Fotos und Konfigurationen"
    echo "  • System Services und Autostart"
    echo "  • Boot-Konfigurationen"
    echo "  • Backup-Dateien: $BACKUP_DIR"
    echo ""
    read -p "Zum Bestätigen tippen Sie 'DELETE ALL': " confirmation
    
    if [ "$confirmation" != "DELETE ALL" ]; then
        print_status "Cleanup abgebrochen durch Benutzer"
        exit 0
    fi
fi

# Root-Check
if [ "$EUID" -ne 0 ]; then
    print_error "Dieses Script muss als root ausgeführt werden:"
    echo "sudo $0"
    exit 1
fi

print_step "Photobox Services stoppen"

# Photobox Service stoppen und deaktivieren
if systemctl list-unit-files | grep -q "photobox.service"; then
    print_status "Stoppe Photobox Service..."
    systemctl stop photobox.service 2>/dev/null || true
    systemctl disable photobox.service 2>/dev/null || true
    print_success "Service gestoppt und deaktiviert"
else
    print_status "Photobox Service nicht gefunden"
fi

# Kiosk-Prozesse beenden
print_status "Beende Kiosk-Prozesse..."
pkill -f "chromium.*localhost:5000" 2>/dev/null || true
pkill -f "start_kiosk.sh" 2>/dev/null || true
print_success "Kiosk-Prozesse beendet"

print_step "Service-Dateien entfernen"

# Systemd Service-Dateien entfernen
if [ -f "/etc/systemd/system/photobox.service" ]; then
    print_status "Entferne Systemd Service-Datei..."
    rm -f /etc/systemd/system/photobox.service
    systemctl daemon-reload
    print_success "Service-Datei entfernt"
fi

# PID-Datei entfernen
if [ -f "/var/run/photobox.pid" ]; then
    rm -f /var/run/photobox.pid
fi

print_step "Autostart-Konfiguration entfernen"

# Desktop-Autostart entfernen
if [ -f "/home/$SERVICE_USER/.config/autostart/photobox-kiosk.desktop" ]; then
    print_status "Entferne Desktop-Autostart..."
    rm -f /home/$SERVICE_USER/.config/autostart/photobox-kiosk.desktop
    print_success "Desktop-Autostart entfernt"
fi

# Kiosk-Scripts entfernen
KIOSK_SCRIPTS=(
    "/home/$SERVICE_USER/start_kiosk.sh"
    "/home/$SERVICE_USER/photobox_watchdog.sh"
    "/home/$SERVICE_USER/auto_camera_fix.sh"
    "/home/$SERVICE_USER/backup_photobox.sh"
    "/home/$SERVICE_USER/test_hardware.sh"
    "/home/$SERVICE_USER/network_fallback.sh"
)

for script in "${KIOSK_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        print_status "Entfernt: $(basename $script)"
    fi
done

# .xsessionrc bereinigen
if [ -f "/home/$SERVICE_USER/.xsessionrc" ]; then
    print_status "Bereinige .xsessionrc..."
    # Entferne nur Photobox-spezifische Einträge
    sed -i '/# Photobox/,+10d' "/home/$SERVICE_USER/.xsessionrc" 2>/dev/null || true
fi

print_step "Crontab-Einträge entfernen"

# Root-Crontab bereinigen
print_status "Bereinige Root-Crontab..."
(crontab -l 2>/dev/null | grep -v "photobox\|Photobox" || true) | crontab -

# User-Crontab bereinigen  
print_status "Bereinige Benutzer-Crontab..."
(crontab -u $SERVICE_USER -l 2>/dev/null | grep -v "photobox\|Photobox" || true) | crontab -u $SERVICE_USER -

print_success "Crontab-Einträge entfernt"

print_step "Photobox-Installation entfernen"

# Hauptinstallation entfernen
if [ -d "$INSTALL_DIR" ]; then
    print_status "Entferne Photobox-Installation..."
    
    # Backup erstellen falls gewünscht
    if [ "$1" != "--no-backup" ] && [ "$1" != "--force" ]; then
        read -p "Backup der Fotos vor Löschung erstellen? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            FINAL_BACKUP="/tmp/photobox_final_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            print_status "Erstelle finales Backup..."
            tar -czf "$FINAL_BACKUP" \
                --exclude=".git" \
                --exclude=".venv" \
                --exclude="*.pyc" \
                --exclude="__pycache__" \
                "$INSTALL_DIR" 2>/dev/null || true
            
            chown $SERVICE_USER:$SERVICE_USER "$FINAL_BACKUP"
            print_success "Backup erstellt: $FINAL_BACKUP"
        fi
    fi
    
    rm -rf "$INSTALL_DIR"
    print_success "Photobox-Installation entfernt"
else
    print_status "Photobox-Installation nicht gefunden"
fi

# Backup-Verzeichnis entfernen
if [ -d "$BACKUP_DIR" ]; then
    print_status "Entferne Backup-Verzeichnis..."
    rm -rf "$BACKUP_DIR"
    print_success "Backup-Verzeichnis entfernt"
fi

print_step "System-Konfigurationen zurücksetzen"

# Boot-Konfiguration bereinigen
if [ -f "/boot/config.txt" ]; then
    print_status "Bereinige Boot-Konfiguration..."
    
    # Entferne Photobox-spezifische Einträge (optional, da sie auch für andere Anwendungen nützlich sein können)
    read -p "Boot-Optimierungen (GPU Memory, Kamera) ebenfalls entfernen? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Erstelle Backup der Boot-Konfiguration
        cp /boot/config.txt /boot/config.txt.backup
        
        # Entferne spezifische Einträge
        sed -i '/gpu_mem=128/d' /boot/config.txt 2>/dev/null || true
        sed -i '/start_x=1/d' /boot/config.txt 2>/dev/null || true
        sed -i '/disable_splash=1/d' /boot/config.txt 2>/dev/null || true
        sed -i '/boot_delay=0/d' /boot/config.txt 2>/dev/null || true
        
        print_success "Boot-Konfiguration bereinigt"
        print_status "Backup erstellt: /boot/config.txt.backup"
    fi
fi

# CUPS-Konfiguration (optional)
read -p "CUPS-Drucker-Konfiguration zurücksetzen? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Setze CUPS-Konfiguration zurück..."
    systemctl stop cups 2>/dev/null || true
    
    # Entferne Drucker-Konfigurationen
    rm -rf /etc/cups/printers.conf* 2>/dev/null || true
    rm -rf /etc/cups/classes.conf* 2>/dev/null || true
    
    systemctl start cups 2>/dev/null || true
    print_success "CUPS-Konfiguration zurückgesetzt"
fi

print_step "udev-Regeln entfernen"

# Kamera udev-Regeln entfernen
UDEV_RULES=(
    "/etc/udev/rules.d/40-gphoto2-disable-gvfs.rules"
    "/etc/udev/rules.d/99-canon-camera.rules"
    "/etc/udev/rules.d/99-gphoto2.rules"
)

for rule in "${UDEV_RULES[@]}"; do
    if [ -f "$rule" ]; then
        print_status "Entferne udev-Regel: $(basename $rule)"
        rm -f "$rule"
    fi
done

# udev-Regeln neu laden
if [ ${#UDEV_RULES[@]} -gt 0 ]; then
    udevadm control --reload-rules
    print_success "udev-Regeln aktualisiert"
fi

print_step "Log-Dateien bereinigen"

# Log-Dateien entfernen
LOG_FILES=(
    "/var/log/photobox.log"
    "/var/log/photobox_startup.log"
    "/var/log/photobox_kiosk.log"
    "/var/log/photobox_watchdog.log"
    "/var/log/photobox_camera_fix.log"
    "/var/log/photobox"
)

for log in "${LOG_FILES[@]}"; do
    if [ -e "$log" ]; then
        rm -rf "$log"
        print_status "Entfernt: $log"
    fi
done

print_success "Log-Dateien bereinigt"

print_step "Benutzer-Gruppen bereinigen (optional)"

# Benutzer aus Photobox-relevanten Gruppen entfernen (optional)
read -p "Benutzer '$SERVICE_USER' aus Drucker-/Kamera-Gruppen entfernen? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Entferne Benutzer aus Gruppen..."
    
    # Entferne aus Gruppen (falls sie nur für Photobox hinzugefügt wurden)
    deluser $SERVICE_USER plugdev 2>/dev/null || true
    deluser $SERVICE_USER dialout 2>/dev/null || true
    deluser $SERVICE_USER lpadmin 2>/dev/null || true
    
    print_success "Benutzer-Gruppen bereinigt"
fi

print_step "System-Services prüfen"

# GVFS wieder aktivieren (falls es deaktiviert wurde)
if systemctl list-unit-files | grep -q "gvfs-daemon.*masked"; then
    read -p "GVFS-Daemon wieder aktivieren? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl unmask gvfs-daemon 2>/dev/null || true
        systemctl enable gvfs-daemon 2>/dev/null || true
        print_success "GVFS-Daemon wieder aktiviert"
    fi
fi

print_step "Abschluss"

# Temporäre Dateien bereinigen
print_status "Bereinige temporäre Dateien..."
rm -f /tmp/photobox* 2>/dev/null || true
rm -f /tmp/chrome-cache* 2>/dev/null || true

print_success "Cleanup erfolgreich abgeschlossen!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║                    🧹 CLEANUP ABGESCHLOSSEN                   ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Entfernte Komponenten:${NC}"
echo "   ✅ Photobox-Installation und alle Dateien"
echo "   ✅ Systemd Service und Autostart"
echo "   ✅ Crontab-Einträge und Watchdogs"
echo "   ✅ udev-Regeln für Kameras"
echo "   ✅ Log-Dateien und temporäre Daten"
echo "   ✅ Backup-Verzeichnisse"
echo ""

echo -e "${BLUE}🔄 Verbleibt auf dem System:${NC}"
echo "   • Basis-Pakete (Python, gphoto2, CUPS)"
echo "   • System-Updates und Optimierungen"
echo "   • Andere Benutzer-Konfigurationen"
echo ""

echo -e "${YELLOW}⚡ Empfohlene nächste Schritte:${NC}"
echo "   1. System neustarten: sudo reboot"
echo "   2. Für Neuinstallation: curl ... | sudo bash"
echo "   3. Manuelle Konfiguration falls nötig"
echo ""

# Neustart empfehlen
read -p "System jetzt neustarten um alle Änderungen zu aktivieren? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "System wird in 10 Sekunden neugestartet..."
    print_status "Drücken Sie Ctrl+C zum Abbrechen"
    sleep 10
    reboot
else
    print_warning "Neustart empfohlen: sudo reboot"
fi

echo -e "${GREEN}🚀 System ist bereit für Neuinstallation oder andere Nutzung!${NC}"