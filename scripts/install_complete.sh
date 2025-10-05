#!/bin/bash

# Photobox Komplette Installation & Konfiguration  
# Dieses Script installiert und konfiguriert die gesamte Photobox-Anwendung
# Version: 4.1.0-fixed-cache-clear

set -e  # Exit bei Fehlern

# Debug: Script-Start bestätigen  
echo "📸 Photobox Installer v4.1.0 gestartet..."

# Konfiguration
INSTALL_DIR="/home/pi/Photobox"
SERVICE_USER="pi"
REPO_URL="https://github.com/marion909/Fotobox.git"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Funktionen definieren ZUERST
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

# Debug: Funktionen definiert
echo "✅ Funktionen erfolgreich definiert"

# Non-Interactive Mode für automatische Installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Debconf-Konfigurationen für non-interactive Installation
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# Weitere debconf-Konfigurationen für automatische Installation
echo "postfix postfix/mailname string raspberry" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'No configuration'" | debconf-set-selections

# CUPS-Konfiguration ohne Prompts
echo "cupsys cupsys/raw-print boolean true" | debconf-set-selections
echo "cupsys cupsys/backend note" | debconf-set-selections

print_status "Non-Interactive Mode konfiguriert für automatische Installation"

# APT-Konfiguration für non-interactive und robuste Installation
cat > /etc/apt/apt.conf.d/99photobox-noninteractive << 'EOF'
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
DPkg::Options "--force-confdef";
DPkg::Options "--force-confold";
Dpkg::Use-Pty "0";
EOF

print_status "APT non-interactive Konfiguration gesetzt"

# Header
clear
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     📸 PHOTOBOX INSTALLER                    ║"
echo "║              Komplette Installation & Konfiguration          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Root-Check
if [ "$EUID" -ne 0 ]; then
    print_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

# Raspberry Pi Check (skip in non-interactive mode)
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    print_warning "Dieses Script ist für Raspberry Pi optimiert!"
    
    # Prüfe ob interaktiver Modus (Terminal verfügbar)
    if [ -t 0 ] && [ -z "$DEBIAN_FRONTEND" ]; then
        read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "Non-interactive Modus - automatisches Fortfahren auf Non-Raspberry-Pi System"
    fi
fi

print_step "System-Update"
print_status "Aktualisiere Paketlisten..."
apt update -q

print_status "Installiere System-Updates (non-interactive)..."
apt upgrade -y -q

print_step "Basis-Pakete Installation"
print_status "Installiere Entwicklungstools..."
apt install -y -q -q \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    vim \
    htop \
    screen \
    tmux

print_status "Installiere Python und Entwicklungsumgebung..."
apt install -y -q \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools

print_step "Kamera-Unterstützung"
print_status "Installiere gphoto2 und Abhängigkeiten..."
apt install -y -q \
    gphoto2 \
    libgphoto2-dev \
    libgphoto2-port12 \
    libexif12 \
    libexif-dev \
    libusb-1.0-0-dev

print_status "Konfiguriere gphoto2 für Photobox..."
# GVFS Auto-Mount für Kameras deaktivieren (verhindert USB-Konflikte)
cat > /etc/udev/rules.d/40-gphoto2-disable-gvfs.rules << 'EOF'
# Deaktiviert GVFS Auto-Mount für gphoto2-kompatible Kameras
# Verhindert "Could not claim USB device" Fehler
ENV{ID_GPHOTO2}=="1", ENV{UDISKS_IGNORE}="1"

# Canon-spezifische Regel (EOS Serie)  
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{idProduct}=="*", MODE="0666", GROUP="plugdev"

# Weitere Canon-Geräte (verschiedene Product IDs)
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", MODE="0666", GROUP="plugdev"
EOF

# udev-Regeln aktivieren
udevadm control --reload-rules
print_success "Kamera-Konfiguration optimiert für Photobox"

print_step "Drucker-System (CUPS)"
print_status "Installiere CUPS und Drucker-Treiber..."

# Basis CUPS-Pakete installieren
apt install -y -q \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    cups-common \
    printer-driver-all \
    printer-driver-hpijs

# Canon-Treiber optional installieren (falls verfügbar)
print_status "Versuche Canon-Treiber zu installieren..."
if apt-cache show printer-driver-canon >/dev/null 2>&1; then
    print_status "Canon-Treiber gefunden - installiere..."
    apt install -y -q printer-driver-canon
    print_success "Canon-Treiber erfolgreich installiert"
else
    print_warning "Canon-Treiber nicht verfügbar - manuell installieren falls benötigt"
    print_status "Alternative: Gutenprint-Treiber installieren..."
    apt install -y -q printer-driver-gutenprint || true
fi

# CUPS für lokalen Zugriff konfigurieren
usermod -a -G lpadmin $SERVICE_USER

# CUPS-Konfiguration optimieren
print_status "Optimiere CUPS-Konfiguration..."
# Netzwerk-Zugriff ermöglichen
sed -i 's/^Listen localhost:631/Listen 631/' /etc/cups/cupsd.conf || true

# Admin-Rechte erweitern
if ! grep -q "Allow @lpadmin" /etc/cups/cupsd.conf; then
    sed -i '/<Location \/admin>/,/<\/Location>/{s/Allow localhost/Allow localhost\n  Allow @lpadmin/}' /etc/cups/cupsd.conf
fi

systemctl enable cups
systemctl start cups

print_success "CUPS erfolgreich konfiguriert - Web-Interface: http://localhost:631"

print_step "Web-Browser für Kiosk-Modus"
print_status "Installiere Chromium Browser..."
apt install -y -q \
    chromium-browser \
    chromium-codecs-ffmpeg \
    unclutter \
    x11-xserver-utils \
    xinput-calibrator

print_step "Netzwerk & Hotspot"
print_status "Installiere Netzwerk-Tools..."
apt install -y -q \
    hostapd \
    dnsmasq \
    iptables-persistent \
    bridge-utils

print_step "Multimedia-Support"
print_status "Installiere Bild- und Video-Bibliotheken..."
apt install -y -q \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    libopenjp2-7-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libharfbuzz-dev \
    libfribidi-dev

print_step "GPIO und Hardware-Support"
print_status "Installiere Raspberry Pi spezifische Pakete..."
apt install -y -q \
    python3-rpi.gpio \
    python3-gpiozero \
    raspi-gpio \
    i2c-tools \
    raspi-config

print_step "Photobox Anwendung"
# Prüfe ob bereits installiert
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Photobox bereits in $INSTALL_DIR installiert"
    
    # Prüfe ob es eine Git-Installation ist
    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        
        # Prüfe auf lokale Änderungen
        if ! sudo -u $SERVICE_USER git diff --quiet || ! sudo -u $SERVICE_USER git diff --cached --quiet; then
            print_warning "Lokale Änderungen erkannt!"
            
            # Automatische Auswahl bei non-interactive Modus
            if [ -t 0 ] && [ "$DEBIAN_FRONTEND" != "noninteractive" ]; then
                echo ""
                echo "Optionen:"
                echo "1) Lokale Änderungen sichern und aktualisieren (empfohlen)"
                echo "2) Lokale Änderungen überschreiben und aktualisieren"  
                echo "3) Komplett neu installieren"
                echo "4) Installation abbrechen"
                echo ""
                read -p "Wählen Sie eine Option (1-4): " -n 1 -r
                echo
                REPLY=$REPLY
            else
                print_status "Non-interactive Modus - automatische Auswahl: Option 1 (Änderungen sichern)"
                REPLY="1"
            fi
            
            case $REPLY in
                1)
                    print_status "Sichere lokale Änderungen..."
                    BACKUP_BRANCH="local-backup-$(date +%Y%m%d-%H%M%S)"
                    sudo -u $SERVICE_USER git checkout -b "$BACKUP_BRANCH"
                    sudo -u $SERVICE_USER git add -A
                    sudo -u $SERVICE_USER git commit -m "Backup vor Update $(date)" || true
                    sudo -u $SERVICE_USER git checkout master
                    sudo -u $SERVICE_USER git reset --hard origin/master
                    sudo -u $SERVICE_USER git pull
                    print_success "Änderungen in Branch '$BACKUP_BRANCH' gesichert"
                    ;;
                2)
                    print_status "Überschreibe lokale Änderungen..."
                    sudo -u $SERVICE_USER git reset --hard HEAD
                    sudo -u $SERVICE_USER git clean -fd
                    sudo -u $SERVICE_USER git pull
                    ;;
                3)
                    print_status "Entferne alte Installation für Neuinstallation..."
                    rm -rf "$INSTALL_DIR"
                    ;;
                4)
                    print_status "Installation abgebrochen"
                    exit 0
                    ;;
                *)
                    print_error "Ungültige Option. Installation abgebrochen."
                    exit 1
                    ;;
            esac
        else
            print_status "Keine lokalen Änderungen - aktualisiere..."
            sudo -u $SERVICE_USER git pull
        fi
        
        # Nach erfolgreichem Update: Continue with installation
        if [ -d "$INSTALL_DIR" ]; then
            print_success "Repository erfolgreich aktualisiert"
            cd "$INSTALL_DIR"
            # Skip cloning since repository already exists and was updated
            REPO_EXISTS=true
        fi
    else
        print_warning "Kein Git-Repository gefunden in $INSTALL_DIR"
        
        # Automatische Auswahl bei non-interactive Modus
        if [ -t 0 ] && [ "$DEBIAN_FRONTEND" != "noninteractive" ]; then
            read -p "Verzeichnis löschen und neu installieren? (y/N): " -n 1 -r
            echo
            REPLY=$REPLY
        else
            print_status "Non-interactive Modus - automatisches Fortfahren: Verzeichnis wird gelöscht"
            REPLY="y"
        fi
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            print_error "Installation abgebrochen"
            exit 1
        fi
    fi
else
    REPO_EXISTS=false
fi

# Clone Repository nur wenn es noch nicht existiert
if [ "$REPO_EXISTS" != "true" ]; then
    print_status "Clone Repository von GitHub..."
    sudo -u $SERVICE_USER git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Python Virtual Environment Setup
print_step "Python Virtual Environment"
print_status "Erstelle Virtual Environment..."

# Prüfe ob Virtual Environment bereits existiert
if [ -d ".venv" ]; then
    print_status "Virtual Environment bereits vorhanden - prüfe Integrität..."
    if [ ! -f ".venv/bin/python" ] && [ ! -f ".venv/bin/pip" ]; then
        print_warning "Virtual Environment beschädigt - erstelle neu..."
        rm -rf .venv
    fi
fi

# Erstelle Virtual Environment falls nicht vorhanden
if [ ! -d ".venv" ]; then
    print_status "Erstelle neues Virtual Environment..."
    sudo -u $SERVICE_USER python3 -m venv .venv
    
    # Prüfe ob Virtual Environment korrekt erstellt wurde
    if [ ! -f ".venv/bin/python" ]; then
        print_error "Virtual Environment konnte nicht erstellt werden!"
        print_status "Prüfe Python3-Installation..."
        python3 --version
        exit 1
    fi
fi

print_status "Aktiviere Virtual Environment und installiere Pakete..."

# Verwende absoluten Pfad für pip
VENV_PIP="$INSTALL_DIR/.venv/bin/pip"
if [ ! -f "$VENV_PIP" ]; then
    print_error "pip nicht gefunden in Virtual Environment: $VENV_PIP"
    ls -la "$INSTALL_DIR/.venv/bin/" || true
    exit 1
fi

sudo -u $SERVICE_USER "$VENV_PIP" install --upgrade pip

# Requirements.txt prüfen und erweitern falls nötig
if [ ! -f "requirements.txt" ]; then
    print_warning "requirements.txt nicht gefunden - erstelle..."
    cat > requirements.txt << 'EOF'
flask==3.0.0
pillow==10.4.0
requests==2.32.3
werkzeug==3.0.1

# Phase 2 Dependencies
paramiko==3.3.1
dataclasses-json==0.6.2

# Additional dependencies für Production
gunicorn==21.2.0
python-dotenv==1.0.0

# QR-Code Generation (Phase 4.2)
qrcode[pil]==7.4.2

# Image processing
opencv-python==4.8.1.78
EOF
    chown $SERVICE_USER:$SERVICE_USER requirements.txt
fi

# Install requirements mit absoluten Pfaden
VENV_PYTHON="$INSTALL_DIR/.venv/bin/python"
sudo -u $SERVICE_USER "$VENV_PIP" install -r requirements.txt

# Test der Installation
print_status "Teste Python-Installation..."
if sudo -u $SERVICE_USER "$VENV_PYTHON" -c "import flask, PIL, requests; print('✅ Alle Python-Pakete erfolgreich installiert')"; then
    print_success "Python-Environment korrekt eingerichtet"
else
    print_error "Fehler bei Python-Paket-Installation"
    print_status "Debug: Virtual Environment Verzeichnisstruktur:"
    ls -la "$INSTALL_DIR/.venv/bin/" || true
    exit 1
fi

print_step "Photobox Konfiguration"
print_status "Erstelle Standard-Konfiguration..."

# Standard config.json erstellen
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

print_step "Systemd Service"
print_status "Erstelle robustes Photobox Service..."

# Pre-Start Script für Umgebungsvorbereitung
cat > $INSTALL_DIR/start_photobox.sh << 'EOF'
#!/bin/bash

# Photobox Startup Script mit Fehlerbehandlung
LOG_FILE="/var/log/photobox_startup.log"
INSTALL_DIR="/home/pi/Fotobox"

echo "$(date): Photobox Startup gestartet" >> $LOG_FILE

# USB-Konflikte beheben
killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true

# GVFS temporär stoppen falls aktiv
systemctl --quiet is-active gvfs-daemon && systemctl stop gvfs-daemon || true

# Kamera-Module zurücksetzen
modprobe -r uvcvideo 2>/dev/null || true
sleep 2
modprobe uvcvideo 2>/dev/null || true

# Verzeichnisse sicherstellen
mkdir -p $INSTALL_DIR/{photos,overlays,temp,backups,logs}
chown -R pi:pi $INSTALL_DIR/{photos,overlays,temp,backups,logs}

# Berechtigungen korrigieren
chmod 755 $INSTALL_DIR/{photos,overlays,temp,backups,logs}

echo "$(date): Umgebung vorbereitet, starte App" >> $LOG_FILE

# Python-App starten
cd $INSTALL_DIR
exec ./.venv/bin/python app.py 2>&1 | tee -a /var/log/photobox_app.log
EOF

chmod +x $INSTALL_DIR/start_photobox.sh
chown $SERVICE_USER:$SERVICE_USER $INSTALL_DIR/start_photobox.sh

# Systemd Service mit verbesserter Konfiguration
cat > /etc/systemd/system/photobox.service << EOF
[Unit]
Description=Photobox Flask Application - Professional Photo Booth System
Documentation=https://github.com/marion909/Fotobox
After=network-online.target graphical-session.target cups.service
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR

# Umgebungsvariablen
Environment=PATH=$INSTALL_DIR/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONPATH=$INSTALL_DIR
Environment=FLASK_ENV=production
Environment=PYTHONUNBUFFERED=1

# Start-Konfiguration
ExecStartPre=/bin/sleep 20
ExecStart=$INSTALL_DIR/start_photobox.sh

# Restart-Verhalten
Restart=always
RestartSec=15
StartLimitBurst=5

# Sicherheit
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR /var/log /tmp

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=photobox

[Install]
WantedBy=multi-user.target graphical.target
EOF

# Service registrieren und konfigurieren
systemctl daemon-reload
systemctl enable photobox.service

print_success "Photobox Service erstellt und aktiviert"

print_step "Kiosk-Modus Konfiguration"
print_status "Erstelle Kiosk-Starter..."
cat > /home/$SERVICE_USER/start_kiosk.sh << 'EOF'
#!/bin/bash

# Photobox Kiosk Startup Script - Robuste Vollbild-Anwendung
LOG_FILE="/var/log/photobox_kiosk.log"

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a $LOG_FILE
}

log_info "🖥️ Kiosk-Modus wird gestartet..."

# Warte auf X-Server mit Timeout
TIMEOUT=120
while ! pgrep -x "Xorg\|X" >/dev/null && [ $TIMEOUT -gt 0 ]; do
    log_info "⏳ Warte auf X-Server... (noch $TIMEOUT Sekunden)"
    sleep 5
    TIMEOUT=$((TIMEOUT - 5))
done

if ! pgrep -x "Xorg\|X" >/dev/null; then
    log_info "❌ FEHLER: X-Server nicht verfügbar"
    exit 1
fi

log_info "✅ X-Server erkannt, konfiguriere Display..."
sleep 10

# Display-Setup
export DISPLAY=:0
xset s off          # Bildschirmschoner deaktivieren
xset -dpms          # Display Power Management deaktivieren
xset s noblank      # Bildschirm nicht schwarz werden lassen

# Mauszeiger nach 1 Sekunde verstecken
unclutter -idle 1 -root &

# Touch-Display Kalibrierung (7" Raspberry Pi Display)
if command -v xinput >/dev/null && xinput list | grep -i touch >/dev/null; then
    log_info "🖱️ Konfiguriere Touch-Display..."
    # Rotation für Portrait-Modus falls nötig
    # xinput --set-prop 'pointer:Goodix Capacitive TouchScreen' 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1 2>/dev/null || true
fi

# Warte auf Photobox-Service
log_info "🔧 Prüfe Photobox-Service..."
SERVICE_TIMEOUT=90
while ! systemctl is-active --quiet photobox.service && [ $SERVICE_TIMEOUT -gt 0 ]; do
    log_info "⚠️ Service nicht aktiv, starte... (noch $SERVICE_TIMEOUT Sekunden)"
    sudo systemctl start photobox.service 2>/dev/null || true
    sleep 5
    SERVICE_TIMEOUT=$((SERVICE_TIMEOUT - 5))
done

# Warte auf HTTP-Verfügbarkeit
log_info "🌐 Prüfe HTTP-Server Verfügbarkeit..."
HTTP_TIMEOUT=60
while ! curl -s --max-time 3 http://localhost:5000 >/dev/null 2>&1 && [ $HTTP_TIMEOUT -gt 0 ]; do
    log_info "⏳ Server noch nicht bereit... (noch $HTTP_TIMEOUT Sekunden)"
    sleep 3
    HTTP_TIMEOUT=$((HTTP_TIMEOUT - 3))
done

if curl -s --max-time 3 http://localhost:5000 >/dev/null 2>&1; then
    log_info "✅ Photobox-Server bereit!"
else
    log_info "⚠️ Server nicht erreichbar, versuche trotzdem Browser-Start..."
fi

# Browser-Profile bereinigen für sauberen Start
rm -rf /home/pi/.config/chromium/Singleton* 2>/dev/null || true
rm -rf /home/pi/.config/chromium/Default/Web\ Data-lock 2>/dev/null || true

# Browser im Kiosk-Modus starten
log_info "🌟 Starte Chromium Kiosk-Modus..."

# Funktion zum Starten von Chromium
start_chromium() {
    chromium-browser \
        --kiosk \
        --start-fullscreen \
        --noerrdialogs \
        --disable-translate \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-restore-session-state \
        --disable-new-tab-first-run \
        --no-first-run \
        --disable-default-apps \
        --disable-popup-blocking \
        --disable-dev-shm-usage \
        --no-sandbox \
        --disable-extensions \
        --disable-notifications \
        --disable-background-timer-throttling \
        --disable-renderer-backgrounding \
        --disable-backgrounding-occluded-windows \
        --autoplay-policy=no-user-gesture-required \
        --touch-events=enabled \
        --force-device-scale-factor=1.0 \
        --app=http://localhost:5000 \
        >/dev/null 2>&1 &
    
    echo $!
}

# Hauptschleife - überwacht Browser und Service
while true; do
    CHROMIUM_PID=$(start_chromium)
    log_info "🚀 Chromium gestartet (PID: $CHROMIUM_PID)"
    
    # Überwache Browser-Prozess
    while kill -0 $CHROMIUM_PID 2>/dev/null; do
        sleep 30
        
        # Prüfe Service-Status
        if ! systemctl is-active --quiet photobox.service; then
            log_info "⚠️ Service gestoppt - neustart..."
            sudo systemctl start photobox.service
        fi
        
        # Prüfe HTTP-Verfügbarkeit
        if ! curl -s --max-time 5 http://localhost:5000 >/dev/null 2>&1; then
            log_info "⚠️ Server nicht erreichbar"
        fi
    done
    
    log_info "❌ Browser beendet - neustart in 10 Sekunden..."
    sleep 10
done
EOF

chmod +x /home/$SERVICE_USER/start_kiosk.sh
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/start_kiosk.sh

# Log-Datei für Kiosk-Modus erstellen
touch /var/log/photobox_kiosk.log
chmod 664 /var/log/photobox_kiosk.log
chown $SERVICE_USER:$SERVICE_USER /var/log/photobox_kiosk.log

print_status "Erstelle automatische Kamera-Fix Script..."
# Automatisches Kamera-Fix beim Boot
cat > /home/$SERVICE_USER/auto_camera_fix.sh << 'EOF'
#!/bin/bash

# Automatische Kamera-Problembehebung beim Boot
# Verhindert "Could not claim USB device" Fehler

LOG_FILE="/var/log/photobox_camera_fix.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> $LOG_FILE
}

log "Auto-Kamera-Fix gestartet"

# Warte kurz nach Boot
sleep 30

# Beende alle gphoto2 und GVFS Prozesse
killall gphoto2 gvfs-gphoto2-volume-monitor 2>/dev/null || true
log "gphoto2 Prozesse beendet"

# GVFS stoppen falls aktiv
if systemctl --quiet is-active gvfs-daemon; then
    systemctl stop gvfs-daemon
    log "GVFS Daemon gestoppt"
fi

# USB-Module zurücksetzen
modprobe -r uvcvideo 2>/dev/null || true
sleep 2
modprobe uvcvideo 2>/dev/null || true
log "USB-Module zurückgesetzt"

# Warte auf USB-Enumeration
sleep 5

# Teste Kamera-Erkennung
if timeout 10 gphoto2 --auto-detect | grep -q Canon; then
    log "✅ Kamera erfolgreich erkannt"
else
    log "⚠️ Keine Kamera erkannt - USB-Verbindung prüfen"
fi

log "Auto-Kamera-Fix abgeschlossen"
EOF

chmod +x /home/$SERVICE_USER/auto_camera_fix.sh
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/auto_camera_fix.sh

# Cronjob für automatisches Kamera-Fix bei Boot
(crontab -u root -l 2>/dev/null; echo "@reboot /home/$SERVICE_USER/auto_camera_fix.sh") | crontab -u root -

# Autostart für Desktop-Session
mkdir -p /home/$SERVICE_USER/.config/autostart
cat > /home/$SERVICE_USER/.config/autostart/photobox-kiosk.desktop << EOF
[Desktop Entry]
Type=Application
Name=Photobox Kiosk
Comment=Photobox Touch Interface
Exec=/home/$SERVICE_USER/start_kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown -R $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/.config

print_step "System-Optimierung"
print_status "Konfiguriere Boot-Verhalten..."

# GPU Memory
if ! grep -q "gpu_mem=" /boot/config.txt; then
    echo "gpu_mem=128" >> /boot/config.txt
fi

# Kamera aktivieren
if ! grep -q "start_x=1" /boot/config.txt; then
    echo "start_x=1" >> /boot/config.txt
fi

# Boot-Optimierung
if ! grep -q "disable_splash=1" /boot/config.txt; then
    echo "disable_splash=1" >> /boot/config.txt
fi

# Auto-Login aktivieren
raspi-config nonint do_boot_behaviour B4

print_step "Backup-System"
print_status "Installiere Backup-Funktionalität..."
cat > /home/$SERVICE_USER/backup_photobox.sh << EOF
#!/bin/bash

BACKUP_DIR="/home/$SERVICE_USER/photobox_backup"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/photobox_backup_\${DATE}.tar.gz"

mkdir -p "\$BACKUP_DIR"

echo "Erstelle Photobox Backup..."
tar -czf "\$BACKUP_FILE" \\
    --exclude="*.pyc" \\
    --exclude="__pycache__" \\
    --exclude=".venv" \\
    --exclude="*.log" \\
    --exclude=".git" \\
    "$INSTALL_DIR"

# Behalte nur die letzten 7 Backups
cd "\$BACKUP_DIR"
ls -t photobox_backup_*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup erstellt: \$BACKUP_FILE"
EOF

chmod +x /home/$SERVICE_USER/backup_photobox.sh
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/backup_photobox.sh

# Crontab für tägliches Backup
(crontab -u $SERVICE_USER -l 2>/dev/null; echo "0 3 * * * /home/$SERVICE_USER/backup_photobox.sh >> /var/log/photobox_backup.log 2>&1") | crontab -u $SERVICE_USER -

print_step "Hardware-Test Script"
cat > /home/$SERVICE_USER/test_hardware.sh << 'EOF'
#!/bin/bash

# Photobox Hardware & Software Test Suite
# Testet alle Komponenten automatisch

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Photobox Vollständiger System-Test${NC}"
echo "====================================="
echo ""

# Funktionen für Tests
test_component() {
    local name="$1"
    local test_cmd="$2"
    local success_msg="$3"
    local error_msg="$4"
    
    echo -n "Testing $name... "
    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $success_msg${NC}"
        return 0
    else
        echo -e "${RED}❌ $error_msg${NC}"
        return 1
    fi
}

# System-Informationen
echo -e "${BLUE}📊 System-Informationen:${NC}"
echo "  • Modell: $(cat /proc/device-tree/model 2>/dev/null || echo "Unbekannt")"
echo "  • OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
echo "  • Kernel: $(uname -r)"
echo "  • Uptime: $(uptime -p)"
echo "  • Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "  • Storage: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo ""

# Python und Virtual Environment
echo -e "${BLUE}🐍 Python Environment:${NC}"
test_component "Python 3" "python3 --version" "Python verfügbar" "Python nicht gefunden"
test_component "Virtual Environment" "[ -f /home/pi/Fotobox/.venv/bin/python ]" "venv gefunden" "venv fehlt"
test_component "Flask" "/home/pi/Fotobox/.venv/bin/python -c 'import flask'" "Flask verfügbar" "Flask fehlt"
test_component "PIL/Pillow" "/home/pi/Fotobox/.venv/bin/python -c 'import PIL'" "PIL verfügbar" "PIL fehlt"
test_component "Requests" "/home/pi/Fotobox/.venv/bin/python -c 'import requests'" "Requests verfügbar" "Requests fehlt"
echo ""

# Kamera-Tests
echo -e "${BLUE}📷 Kamera-System:${NC}"
test_component "gphoto2" "command -v gphoto2" "gphoto2 installiert" "gphoto2 fehlt"

if command -v gphoto2 >/dev/null 2>&1; then
    echo "  🔍 Kamera-Erkennung:"
    CAMERAS=$(timeout 10 gphoto2 --auto-detect 2>/dev/null | grep "usb:" | wc -l)
    if [ $CAMERAS -gt 0 ]; then
        echo -e "    ${GREEN}✅ $CAMERAS Kamera(s) erkannt${NC}"
        gphoto2 --auto-detect | tail -n +3 | while IFS= read -r line; do
            echo "    📸 $line"
        done
        
        # Kamera-Test-Foto
        echo "  📸 Test-Aufnahme:"
        if timeout 15 gphoto2 --capture-image >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ Test-Foto erfolgreich${NC}"
        else
            echo -e "    ${RED}❌ Test-Foto fehlgeschlagen${NC}"
            echo -e "    ${YELLOW}💡 Tipp: Kamera auf 'PC Connect' Modus stellen${NC}"
        fi
    else
        echo -e "    ${RED}❌ Keine Kamera gefunden${NC}"
        echo -e "    ${YELLOW}💡 Prüfe USB-Verbindung und Kamera-Modus${NC}"
    fi
else
    echo -e "  ${RED}❌ gphoto2 nicht installiert${NC}"
fi
echo ""

# USB-System
echo -e "${BLUE}🔌 USB-System:${NC}"
echo "  📱 Erkannte USB-Geräte:"
lsusb | while IFS= read -r line; do
    echo "    • $line"
done
echo ""

# Drucker-System
echo -e "${BLUE}🖨️ Drucker-System:${NC}"
test_component "CUPS" "systemctl is-active cups" "CUPS aktiv" "CUPS nicht aktiv"

if command -v lpstat >/dev/null 2>&1; then
    PRINTERS=$(lpstat -p 2>/dev/null | wc -l)
    if [ $PRINTERS -gt 0 ]; then
        echo -e "  ${GREEN}✅ $PRINTERS Drucker konfiguriert${NC}"
        lpstat -p | while IFS= read -r line; do
            echo "    🖨️  $line"
        done
    else
        echo -e "  ${YELLOW}⚠️  Keine Drucker konfiguriert${NC}"
        echo -e "    ${BLUE}💡 CUPS Web-Interface: http://localhost:631${NC}"
    fi
else
    echo -e "  ${RED}❌ CUPS Tools nicht verfügbar${NC}"
fi
echo ""

# Netzwerk
echo -e "${BLUE}🌐 Netzwerk:${NC}"
echo "  📶 Aktive Verbindungen:"
ip route get 8.8.8.8 >/dev/null 2>&1 && echo -e "    ${GREEN}✅ Internet verfügbar${NC}" || echo -e "    ${RED}❌ Keine Internet-Verbindung${NC}"

# Lokale IP anzeigen
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -n "$LOCAL_IP" ]; then
    echo -e "    ${GREEN}🌍 Lokale IP: $LOCAL_IP${NC}"
    echo -e "    ${BLUE}🔗 Photobox-URL: http://$LOCAL_IP:5000${NC}"
fi
echo ""

# Photobox-App
echo -e "${BLUE}📸 Photobox-Anwendung:${NC}"
test_component "App-Verzeichnis" "[ -d /home/pi/Fotobox ]" "Verzeichnis vorhanden" "Verzeichnis fehlt"
test_component "app.py" "[ -f /home/pi/Fotobox/app.py ]" "Hauptdatei vorhanden" "app.py fehlt"
test_component "Config" "[ -f /home/pi/Fotobox/config.json ]" "Konfiguration vorhanden" "config.json fehlt"

# Service-Status
if systemctl list-unit-files | grep -q photobox.service; then
    if systemctl is-active --quiet photobox.service; then
        echo -e "  ${GREEN}✅ Photobox-Service läuft${NC}"
        SERVICE_PID=$(systemctl show -p MainPID photobox.service | cut -d= -f2)
        if [ "$SERVICE_PID" != "0" ]; then
            echo "    🔧 Process ID: $SERVICE_PID"
        fi
    else
        echo -e "  ${RED}❌ Photobox-Service nicht aktiv${NC}"
        echo -e "    ${YELLOW}💡 Starten mit: sudo systemctl start photobox${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  Photobox-Service nicht installiert${NC}"
fi
echo ""

# Verzeichnisstruktur
echo -e "${BLUE}📁 Verzeichnisse:${NC}"
for dir in photos overlays temp backups logs; do
    if [ -d "/home/pi/Fotobox/$dir" ]; then
        FILE_COUNT=$(find "/home/pi/Fotobox/$dir" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✅ $dir/ ($FILE_COUNT Dateien)${NC}"
    else
        echo -e "  ${RED}❌ $dir/ fehlt${NC}"
    fi
done
echo ""

# Zusammenfassung und Empfehlungen
echo -e "${BLUE}📋 Zusammenfassung & Empfehlungen:${NC}"

# Kritische Probleme
CRITICAL_ISSUES=0

if ! command -v gphoto2 >/dev/null 2>&1; then
    echo -e "  ${RED}🚨 KRITISCH: gphoto2 nicht installiert${NC}"
    ((CRITICAL_ISSUES++))
fi

if [ ! -f /home/pi/Fotobox/.venv/bin/python ]; then
    echo -e "  ${RED}🚨 KRITISCH: Python Virtual Environment fehlt${NC}"
    ((CRITICAL_ISSUES++))
fi

if ! systemctl is-active --quiet photobox.service 2>/dev/null; then
    echo -e "  ${YELLOW}⚠️  Service nicht aktiv - möglicherweise manueller Start nötig${NC}"
fi

if [ $(timeout 10 gphoto2 --auto-detect 2>/dev/null | grep "usb:" | wc -l) -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  Keine Kamera erkannt - USB-Verbindung prüfen${NC}"
fi

if [ $CRITICAL_ISSUES -eq 0 ]; then
    echo -e "  ${GREEN}🎉 System bereit für Photobox-Betrieb!${NC}"
else
    echo -e "  ${RED}❌ $CRITICAL_ISSUES kritische Problem(e) gefunden${NC}"
    echo -e "  ${YELLOW}💡 Installation möglicherweise unvollständig - setup erneut ausführen${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Nützliche Befehle:${NC}"
echo "  • Service starten: sudo systemctl start photobox"
echo "  • Service-Status: sudo systemctl status photobox"
echo "  • Logs anzeigen: sudo journalctl -u photobox -f"
echo "  • Kamera testen: gphoto2 --auto-detect"
echo "  • CUPS öffnen: http://localhost:631"
echo "  • App öffnen: http://localhost:5000"
EOF

chmod +x /home/$SERVICE_USER/test_hardware.sh
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/test_hardware.sh
    if [ $CAMERAS -gt 0 ]; then
        echo "  ✅ $CAMERAS Kamera(s) erkannt"
        gphoto2 --auto-detect | tail -n +3
    else
        echo "  ❌ Keine Kamera gefunden"
    fi
else
    echo "  ❌ gphoto2 nicht installiert"
fi
echo ""

# Display Test
echo "🖥️ Display:"
if [ -n "$DISPLAY" ]; then
    echo "  ✅ Display verfügbar: $DISPLAY"
    if command -v xrandr >/dev/null 2>&1; then
        RESOLUTION=$(xrandr 2>/dev/null | grep '*' | awk '{print $1}')
        echo "  • Auflösung: $RESOLUTION"
    fi
else
    echo "  ⚠️ Kein Display-Server aktiv"
fi
echo ""

# Drucker Test  
echo "🖨️ Drucker:"
if command -v lpstat >/dev/null 2>&1; then
    PRINTERS=$(lpstat -p 2>/dev/null | wc -l)
    if [ $PRINTERS -gt 0 ]; then
        echo "  ✅ $PRINTERS Drucker konfiguriert"
        lpstat -p 2>/dev/null
    else
        echo "  ⚠️ Keine Drucker konfiguriert"
    fi
else
    echo "  ❌ CUPS nicht verfügbar"
fi
echo ""

# Netzwerk Test
echo "🌐 Netzwerk:"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "  ✅ Internet verfügbar"
    IP=$(hostname -I | awk '{print $1}')
    echo "  • IP-Adresse: $IP"
else
    echo "  ⚠️ Kein Internet"
fi
echo ""

# Speicher Test
echo "💾 Speicher:"
df -h / | tail -1 | awk '{print "  • Root: " $3 " / " $2 " (" $5 " belegt)"}'
free -h | grep "^Mem:" | awk '{print "  • RAM: " $3 " / " $2 " (" int($3/$2*100) "% belegt)"}'
echo ""

# Temperatur
echo "🌡️ System:"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$((TEMP / 1000))
    echo "  • CPU-Temperatur: ${TEMP_C}°C"
    if [ $TEMP_C -gt 70 ]; then
        echo "  ⚠️ Hohe Temperatur!"
    fi
fi

# Photobox Service
echo ""
echo "📦 Photobox Service:"
if systemctl is-active --quiet photobox; then
    echo "  ✅ Service läuft"
else
    echo "  ❌ Service nicht aktiv"
fi

if curl -s http://localhost:5000 >/dev/null 2>&1; then
    echo "  ✅ Web-Interface erreichbar"
else
    echo "  ❌ Web-Interface nicht erreichbar"
fi

echo ""
echo "Test abgeschlossen!"
EOF

chmod +x /home/$SERVICE_USER/test_hardware.sh
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/test_hardware.sh

print_step "Hotspot-Konfiguration (Fallback)"
print_status "Konfiguriere Access Point..."

# hostapd Konfiguration  
cat > /etc/hostapd/hostapd.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=Photobox-Setup
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=photobox2024
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# dnsmasq Konfiguration
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
cat > /etc/dnsmasq.conf << 'EOF'
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=photobox.local
address=/photobox.local/192.168.4.1
EOF

print_step "Finalisierung"
print_status "Setze Berechtigungen..."
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh

# Log-Verzeichnis
mkdir -p /var/log/photobox
chown $SERVICE_USER:$SERVICE_USER /var/log/photobox

print_success "Installation erfolgreich abgeschlossen!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║                    🎉 INSTALLATION ABGESCHLOSSEN              ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Installierte Komponenten:${NC}"
echo "   • Photobox Flask-Anwendung"
echo "   • Systemd-Service (photobox)"
echo "   • Kiosk-Modus (Chromium Vollbild)"
echo "   • Kamera-Unterstützung (gphoto2)"
echo "   • Drucker-System (CUPS)"
echo "   • Backup-System (täglich 03:00)"
echo "   • Hotspot-Fallback (WLAN: Photobox-Setup)"
echo ""
echo -e "${BLUE}🎮 Wichtige Befehle:${NC}"
echo "   sudo systemctl start photobox     # Service starten"
echo "   sudo systemctl status photobox    # Service-Status"
echo "   /home/$SERVICE_USER/test_hardware.sh        # Hardware testen"
echo "   /home/$SERVICE_USER/backup_photobox.sh      # Backup erstellen"
echo ""
echo -e "${BLUE}🌐 URLs:${NC}"
echo "   • Photobox-App: http://localhost:5000"
echo "   • CUPS (Drucker): http://localhost:631"
echo "   • Server-Upload Setup: http://your-server.com/photobox/setup.php"
echo ""
echo -e "${BLUE}📁 Wichtige Verzeichnisse:${NC}"
echo "   • Installation: $INSTALL_DIR"
echo "   • Fotos: $INSTALL_DIR/photos"
echo "   • Logs: /var/log/photobox"
echo "   • Backups: /home/$SERVICE_USER/photobox_backup"
echo ""
echo -e "${YELLOW}⚡ NÄCHSTE SCHRITTE:${NC}"
echo "   1. Hardware anschließen (Kamera, Drucker, Touchscreen)"
echo "   2. System neustarten: sudo reboot"
echo "   3. Hardware testen: /home/$SERVICE_USER/test_hardware.sh"
echo "   4. Admin-Panel öffnen: http://localhost:5000/admin"
echo "   5. Server-Upload konfigurieren (optional)"
echo ""
echo -e "${BLUE}🔧 Kamera-Einstellungen (Canon EOS):${NC}"
echo "   • USB-Modus: 'PC Connect' oder 'PTP' (NICHT Mass Storage)"
echo "   • Auto Power Off: Deaktivieren"
echo "   • Shooting Mode: Manual (M) oder Av (Aperture Priority)"
echo "   • Image Quality: JPEG Large Fine"
echo ""
echo -e "${BLUE}📞 Support & Troubleshooting:${NC}"
echo "   • Kamera-Probleme: ./fix_camera_usb.sh ausführen"
echo "   • Service-Logs: sudo journalctl -u photobox -f"
echo "   • Kiosk-Logs: tail -f /var/log/photobox_kiosk.log"
echo "   • GitHub Issues: https://github.com/marion909/Fotobox/issues"
echo ""
echo -e "${BLUE}🎯 Automatische Features aktiviert:${NC}"
echo "   ✅ Kamera-USB-Fix bei jedem Boot"
echo "   ✅ Service-Überwachung und Neustart"
echo "   ✅ Tägliche Backups um 03:00 Uhr"
echo "   ✅ Kiosk-Modus nach Desktop-Start"
echo "   ✅ GVFS-Konflikte automatisch behoben"
echo ""
echo -e "${GREEN}🚀 System ist bereit für den Produktiveinsatz!${NC}"
echo ""
echo -e "${YELLOW}╭─ NEUSTART ERFORDERLICH ─╮${NC}"
echo -e "${YELLOW}│                         │${NC}"
echo -e "${YELLOW}│  sudo reboot            │${NC}"
echo -e "${YELLOW}│                         │${NC}"
echo -e "${YELLOW}╰─────────────────────────╯${NC}"
echo ""
echo -e "${GREEN}Nach dem Neustart:${NC}"
echo -e "  🌟 Photobox startet automatisch im Vollbild-Modus"
echo -e "  📸 Kamera wird automatisch erkannt und konfiguriert"
echo -e "  🖨️ Drucker-Setup über CUPS Web-Interface verfügbar"
echo -e "  ☁️ Server-Upload bereit für Konfiguration"
