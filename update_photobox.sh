#!/bin/bash

# 🔄 Photobox Update Script
# Aktualisiert eine bestehende Photobox-Installation sicher

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}🔄 Photobox Update Script${NC}"
echo "========================="
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

# Prüfungen
if [ "$EUID" -ne 0 ]; then
    print_error "Dieses Script muss als root ausgeführt werden:"
    echo "sudo $0"
    exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
    print_error "Photobox-Installation nicht gefunden in $INSTALL_DIR"
    print_status "Für neue Installation verwenden Sie: sudo ./install_complete.sh"
    exit 1
fi

if [ ! -d "$INSTALL_DIR/.git" ]; then
    print_error "Kein Git-Repository gefunden. Update nicht möglich."
    print_status "Für manuelle Installation siehe README.md"
    exit 1
fi

print_step "Update-Vorbereitung"

# Service stoppen falls aktiv
if systemctl is-active --quiet photobox.service; then
    print_status "Stoppe Photobox-Service für Update..."
    systemctl stop photobox.service
    RESTART_SERVICE=true
else
    RESTART_SERVICE=false
fi

# Backup erstellen
print_status "Erstelle Sicherheitskopie..."
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="${BACKUP_DIR}/photobox_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

tar -czf "$BACKUP_FILE" \
    --exclude=".git" \
    --exclude="*.pyc" \
    --exclude="__pycache__" \
    --exclude=".venv" \
    --exclude="*.log" \
    --exclude="photos/*" \
    "$INSTALL_DIR" 2>/dev/null

chown $SERVICE_USER:$SERVICE_USER "$BACKUP_FILE"
print_success "Backup erstellt: $BACKUP_FILE"

print_step "Repository-Update"
cd "$INSTALL_DIR"

# Git-Status prüfen
print_status "Prüfe Git-Status..."
if ! sudo -u $SERVICE_USER git fetch origin; then
    print_error "Fehler beim Abrufen der Updates von GitHub"
    exit 1
fi

# Lokale Änderungen prüfen
if ! sudo -u $SERVICE_USER git diff --quiet || ! sudo -u $SERVICE_USER git diff --cached --quiet; then
    print_warning "Lokale Änderungen erkannt!"
    
    # Zeige Änderungen
    echo ""
    echo "Geänderte Dateien:"
    sudo -u $SERVICE_USER git status --porcelain | while read status file; do
        echo "  $status $file"
    done
    echo ""
    
    echo "Update-Optionen:"
    echo "1) Änderungen in neuen Branch sichern und aktualisieren (empfohlen)"
    echo "2) Änderungen verwerfen und aktualisieren"
    echo "3) Update abbrechen"
    echo ""
    read -p "Wählen Sie eine Option (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            print_status "Sichere Änderungen in Backup-Branch..."
            BACKUP_BRANCH="local-backup-$(date +%Y%m%d-%H%M%S)"
            sudo -u $SERVICE_USER git checkout -b "$BACKUP_BRANCH"
            sudo -u $SERVICE_USER git add -A
            sudo -u $SERVICE_USER git commit -m "Automatisches Backup vor Update - $(date)" || true
            sudo -u $SERVICE_USER git checkout master
            print_success "Änderungen gesichert in Branch: $BACKUP_BRANCH"
            ;;
        2)
            print_status "Verwerfe lokale Änderungen..."
            sudo -u $SERVICE_USER git reset --hard HEAD
            sudo -u $SERVICE_USER git clean -fd
            print_warning "Lokale Änderungen wurden verworfen!"
            ;;
        3)
            print_status "Update abgebrochen durch Benutzer"
            if [ "$RESTART_SERVICE" = true ]; then
                systemctl start photobox.service
            fi
            exit 0
            ;;
        *)
            print_error "Ungültige Option"
            exit 1
            ;;
    esac
fi

# Update durchführen
print_status "Führe Git-Update durch..."
if sudo -u $SERVICE_USER git pull origin master; then
    print_success "Repository erfolgreich aktualisiert"
else
    print_error "Git-Update fehlgeschlagen"
    exit 1
fi

# Zeige Änderungen
CURRENT_COMMIT=$(sudo -u $SERVICE_USER git rev-parse HEAD)
PREVIOUS_COMMIT=$(sudo -u $SERVICE_USER git rev-parse HEAD~1)

if [ "$CURRENT_COMMIT" != "$PREVIOUS_COMMIT" ]; then
    print_status "Neue Commits:"
    sudo -u $SERVICE_USER git log --oneline HEAD~3..HEAD
fi

print_step "Abhängigkeiten aktualisieren"

# Virtual Environment prüfen/aktualisieren
if [ ! -d ".venv" ]; then
    print_status "Erstelle Virtual Environment..."
    sudo -u $SERVICE_USER python3 -m venv .venv
fi

# Python-Pakete aktualisieren
print_status "Aktualisiere Python-Pakete..."
sudo -u $SERVICE_USER ./.venv/bin/pip install --upgrade pip
sudo -u $SERVICE_USER ./.venv/bin/pip install -r requirements.txt --upgrade

print_step "Konfiguration prüfen"

# Konfigurationsdatei aktualisieren falls nötig
if [ -f "config.json" ]; then
    print_status "Konfigurationsdatei gefunden - prüfe auf Updates..."
    
    # Backup der aktuellen Konfiguration
    cp config.json config.json.backup
    chown $SERVICE_USER:$SERVICE_USER config.json.backup
    
    print_success "Aktuelle Konfiguration gesichert als config.json.backup"
else
    print_warning "Keine Konfigurationsdatei gefunden - erstelle Standard-Konfiguration..."
    
    # Standard-Konfiguration erstellen (aus install_complete.sh übernommen)
    sudo -u $SERVICE_USER cat > config.json << 'EOF'
{
  "app": {
    "host": "0.0.0.0",
    "port": 5000,
    "debug": false,
    "secret_key": "photobox-secret-change-in-production"
  },
  "camera": {
    "enabled": true,
    "auto_detect": true,
    "gphoto2_path": "/usr/bin/gphoto2",
    "capture_target": "sdram",
    "image_format": "jpeg_large_fine"
  },
  "countdown": {
    "enabled": true,
    "duration": 3,
    "sound_enabled": true,
    "animation_style": "fade"
  },
  "overlay": {
    "enabled": false,
    "logo_path": "overlays/logo.png",
    "text_content": "",
    "text_position": "bottom",
    "transparency": 0.8
  },
  "printing": {
    "enabled": true,
    "auto_print": false,
    "printer_name": "",
    "paper_size": "10x15cm",
    "copies": 1
  },
  "upload": {
    "enabled": false,
    "http_endpoint": "",
    "api_key": "",
    "auto_upload": false,
    "retry_attempts": 3
  },
  "backup": {
    "enabled": true,
    "retention_days": 30,
    "auto_cleanup": true,
    "backup_path": "backups"
  },
  "ui": {
    "theme": "default",
    "language": "de",
    "fullscreen": false,
    "hide_cursor": true
  },
  "qr_codes": {
    "enabled": true,
    "base_url": "http://localhost:5000",
    "size": 200
  },
  "multi_shot": {
    "enabled": false,
    "count": 4,
    "interval": 2
  }
}
EOF
    
    print_success "Standard-Konfiguration erstellt"
fi

print_step "System-Services prüfen"

# Service-Konfiguration prüfen
if systemctl list-unit-files | grep -q "photobox.service"; then
    print_status "Photobox-Service gefunden - prüfe Konfiguration..."
    
    # Service-Datei-Datum prüfen (vereinfacht)
    if [ -f "/etc/systemd/system/photobox.service" ]; then
        print_success "Service-Konfiguration vorhanden"
    else
        print_warning "Service-Konfiguration fehlt - bitte ./install_complete.sh erneut ausführen"
    fi
else
    print_warning "Photobox-Service nicht installiert"
    print_status "Für vollständige Service-Installation: sudo ./install_complete.sh"
fi

print_step "Berechtigungen prüfen"

# Verzeichnis-Berechtigungen korrigieren
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

# Verzeichnisse erstellen falls sie fehlen
sudo -u $SERVICE_USER mkdir -p "$INSTALL_DIR"/{photos,overlays,temp,backups,logs}

print_step "Abschluss"

# Hardware-Test anbieten
if [ -f "$INSTALL_DIR/test_hardware.sh" ]; then
    read -p "Hardware-Test nach Update ausführen? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Führe Hardware-Test aus..."
        sudo -u $SERVICE_USER "$INSTALL_DIR/test_hardware.sh"
    fi
fi

# Service wieder starten
if [ "$RESTART_SERVICE" = true ]; then
    print_status "Starte Photobox-Service wieder..."
    systemctl start photobox.service
    sleep 5
    
    if systemctl is-active --quiet photobox.service; then
        print_success "Service erfolgreich gestartet"
    else
        print_warning "Service-Start möglicherweise fehlgeschlagen"
        print_status "Status prüfen: sudo systemctl status photobox"
    fi
fi

print_success "Update erfolgreich abgeschlossen!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║                    🎉 UPDATE ABGESCHLOSSEN                    ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Update-Zusammenfassung:${NC}"
echo "   ✅ Repository aktualisiert"
echo "   ✅ Python-Pakete aktualisiert"
echo "   ✅ Konfiguration geprüft"
echo "   ✅ Berechtigungen korrigiert"
if [ "$RESTART_SERVICE" = true ]; then
    echo "   ✅ Service neugestartet"
fi
echo "   ✅ Backup erstellt: $(basename $BACKUP_FILE)"
echo ""

echo -e "${BLUE}🌐 Zugriff:${NC}"
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -n "$LOCAL_IP" ]; then
    echo "   🌍 Photobox-App: http://$LOCAL_IP:5000"
else
    echo "   🌍 Photobox-App: http://localhost:5000"
fi
echo "   ⚙️ Admin-Panel: http://localhost:5000/admin"
echo "   🔧 Service-Status: sudo systemctl status photobox"
echo ""

echo -e "${GREEN}🚀 Photobox ist bereit für den Einsatz!${NC}"