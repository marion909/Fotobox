#!/bin/bash

# Photobox Komplette Installation & Konfiguration
# Dieses Script installiert und konfiguriert die gesamte Photobox-Anwendung

set -e  # Exit bei Fehlern

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

# Header
clear
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     📸 PHOTOBOX INSTALLER                    ║"
echo "║              Komplette Installation & Konfiguration          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

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

# Root-Check
if [ "$EUID" -ne 0 ]; then
    print_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

# Raspberry Pi Check
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    print_warning "Dieses Script ist für Raspberry Pi optimiert!"
    read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_step "System-Update"
print_status "Aktualisiere Paketlisten..."
apt update

print_status "Installiere System-Updates..."
apt upgrade -y

print_step "Basis-Pakete Installation"
print_status "Installiere Entwicklungstools..."
apt install -y \
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
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools

print_step "Kamera-Unterstützung"
print_status "Installiere gphoto2 und Abhängigkeiten..."
apt install -y \
    gphoto2 \
    libgphoto2-dev \
    libgphoto2-port12 \
    libexif12 \
    libexif-dev \
    libusb-1.0-0-dev

print_step "Drucker-System (CUPS)"
print_status "Installiere CUPS und Drucker-Treiber..."
apt install -y \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    cups-common \
    printer-driver-all \
    printer-driver-hpijs \
    printer-driver-canon

# CUPS für lokalen Zugriff konfigurieren
usermod -a -G lpadmin $SERVICE_USER
systemctl enable cups
systemctl start cups

print_step "Web-Browser für Kiosk-Modus"
print_status "Installiere Chromium Browser..."
apt install -y \
    chromium-browser \
    chromium-codecs-ffmpeg \
    unclutter \
    x11-xserver-utils \
    xinput-calibrator

print_step "Netzwerk & Hotspot"
print_status "Installiere Netzwerk-Tools..."
apt install -y \
    hostapd \
    dnsmasq \
    iptables-persistent \
    bridge-utils

print_step "Multimedia-Support"
print_status "Installiere Bild- und Video-Bibliotheken..."
apt install -y \
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
apt install -y \
    python3-rpi.gpio \
    python3-gpiozero \
    raspi-gpio \
    i2c-tools \
    raspi-config

print_step "Photobox Anwendung"
# Prüfe ob bereits installiert
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Photobox bereits in $INSTALL_DIR installiert"
    read -p "Neu installieren? Dies löscht alle lokalen Änderungen! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Entferne alte Installation..."
        rm -rf "$INSTALL_DIR"
    else
        print_status "Aktualisiere bestehende Installation..."
        cd "$INSTALL_DIR"
        sudo -u $SERVICE_USER git pull
        goto_venv_setup
    fi
fi

print_status "Clone Repository von GitHub..."
sudo -u $SERVICE_USER git clone "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

goto_venv_setup() {
print_step "Python Virtual Environment"
print_status "Erstelle Virtual Environment..."
sudo -u $SERVICE_USER python3 -m venv .venv

print_status "Aktiviere Virtual Environment und installiere Pakete..."
sudo -u $SERVICE_USER ./.venv/bin/pip install --upgrade pip
sudo -u $SERVICE_USER ./.venv/bin/pip install -r requirements.txt

print_step "Systemd Service"
print_status "Erstelle Photobox Service..."
cat > /etc/systemd/system/photobox.service << EOF
[Unit]
Description=Photobox Flask Application
After=network.target multi-user.target graphical.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/.venv/bin
ExecStartPre=/bin/sleep 15
ExecStart=$INSTALL_DIR/.venv/bin/python $INSTALL_DIR/app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=photobox

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable photobox.service
}

goto_venv_setup

print_step "Kiosk-Modus Konfiguration"
print_status "Erstelle Kiosk-Starter..."
cat > /home/$SERVICE_USER/start_kiosk.sh << 'EOF'
#!/bin/bash

# Warte auf X-Server
while ! pgrep -x "X" > /dev/null; do
    sleep 1
done
sleep 10

# Bildschirmschoner deaktivieren
export DISPLAY=:0
xset s off
xset -dpms
xset s noblank

# Mauszeiger verstecken
unclutter -idle 5 -root &

# Chromium im Kiosk-Modus starten
chromium-browser \
    --kiosk \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --no-default-browser-check \
    --disable-translate \
    --disable-features=TranslateUI \
    --disable-ipc-flooding-protection \
    --memory-pressure-off \
    --touch-events=enabled \
    --force-device-scale-factor=1.0 \
    --app=http://localhost:5000 &

# Warte und starte neu falls Chromium abstürzt
while true; do
    if ! pgrep -f "chromium.*localhost:5000" > /dev/null; then
        sleep 5
        chromium-browser --kiosk --app=http://localhost:5000 &
    fi
    sleep 30
done
EOF

chmod +x /home/$SERVICE_USER/start_kiosk.sh
chown $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/start_kiosk.sh

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

echo "🔧 Photobox Hardware Test"
echo "========================="
echo ""

# System Info
echo "📊 System:"
echo "  • Modell: $(cat /proc/device-tree/model 2>/dev/null || echo "Unbekannt")"
echo "  • Kernel: $(uname -r)"
echo "  • Uptime: $(uptime -p)"
echo ""

# Kamera Test
echo "📷 Kamera:"
if command -v gphoto2 >/dev/null 2>&1; then
    CAMERAS=$(gphoto2 --auto-detect 2>/dev/null | grep -c "usb:")
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
echo -e "${GREEN}🚀 System bereit für Neustart!${NC}"
echo -e "${YELLOW}Führen Sie 'sudo reboot' aus, um die Installation zu finalisieren.${NC}"