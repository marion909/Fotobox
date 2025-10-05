#!/bin/bash

# Photobox System Setup Script
# Vollständige Systemkonfiguration für Raspberry Pi Photobox

set -e  # Exit bei Fehlern

echo "🍓 Photobox Raspberry Pi Setup"
echo "=============================="
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Root-Check
if [ "$EUID" -ne 0 ]; then
    print_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

# Variablen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_USER="pi"
PYTHON_VERSION="3.9"

print_status "Starte Photobox Setup..."
print_status "Arbeitsverzeichnis: ${SCRIPT_DIR}"

# System Update
print_status "Aktualisiere System..."
apt update && apt upgrade -y

# Basis-Pakete installieren
print_status "Installiere Basis-Pakete..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    curl \
    unzip \
    vim \
    htop \
    screen \
    unclutter \
    x11-xserver-utils \
    xinput-calibrator

# Kamera-Unterstützung
print_status "Installiere Kamera-Unterstützung..."
apt install -y \
    gphoto2 \
    libgphoto2-dev \
    libgphoto2-port12 \
    libexif12 \
    libexif-dev

# Drucker-Unterstützung
print_status "Installiere Drucker-Unterstützung (CUPS)..."
apt install -y \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    cups-common \
    printer-driver-all

# Chromium Browser
print_status "Installiere Chromium Browser..."
apt install -y \
    chromium-browser \
    chromium-codecs-ffmpeg

# Netzwerk-Tools
print_status "Installiere Netzwerk-Tools..."
apt install -y \
    hostapd \
    dnsmasq \
    iptables-persistent

# Python Virtual Environment erstellen
print_status "Erstelle Python Virtual Environment..."
cd "$SCRIPT_DIR"
if [ ! -d ".venv" ]; then
    sudo -u $PI_USER python3 -m venv .venv
    print_success "Virtual Environment erstellt"
else
    print_warning "Virtual Environment existiert bereits"
fi

# Python-Pakete installieren
print_status "Installiere Python-Pakete..."
sudo -u $PI_USER ./.venv/bin/pip install --upgrade pip
sudo -u $PI_USER ./.venv/bin/pip install -r requirements.txt

# GPIO-Unterstützung (falls Hardware-Buttons gewünscht)
print_status "Installiere GPIO-Unterstützung..."
apt install -y \
    python3-rpi.gpio \
    python3-gpiozero \
    raspi-gpio

# System-Konfiguration
print_status "Konfiguriere System..."

# GPU Memory Split für bessere Performance
if ! grep -q "gpu_mem=128" /boot/config.txt; then
    echo "gpu_mem=128" >> /boot/config.txt
    print_success "GPU Memory auf 128MB gesetzt"
fi

# Kamera Interface aktivieren
if ! grep -q "start_x=1" /boot/config.txt; then
    echo "start_x=1" >> /boot/config.txt
    print_success "Kamera Interface aktiviert"
fi

# USB-Kamera Unterstützung
modprobe uvcvideo
echo 'uvcvideo' >> /etc/modules

# CUPS-Konfiguration
print_status "Konfiguriere CUPS..."
usermod -a -G lpadmin $PI_USER
systemctl enable cups
systemctl start cups

# Erstelle CUPS-Konfiguration
cat > /etc/cups/cupsd.conf << 'EOF'
LogLevel warn
MaxLogSize 0
SystemGroup sys root lpadmin
Listen localhost:631
Listen /run/cups/cups.sock
Browsing Off
BrowseLocalProtocols dnssd
DefaultAuthType Basic
WebInterface Yes

<Location />
Order allow,deny
Allow localhost
Allow @LOCAL
</Location>

<Location /admin>
Order allow,deny
Allow localhost
Allow @LOCAL
</Location>

<Location /admin/conf>
AuthType Default
Require user @SYSTEM
Order allow,deny
Allow localhost
Allow @LOCAL
</Location>

<Location /admin/log>
AuthType Default
Require user @SYSTEM
Order allow,deny
Allow localhost
Allow @LOCAL
</Location>

<Policy default>
JobPrivateAccess default
JobPrivateValues default
SubscriptionPrivateAccess default
SubscriptionPrivateValues default

<Limit Create-Job Print-Job Print-URI Validate-Job>
Order deny,allow
</Limit>

<Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Job Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job CUPS-Get-Document>
Require user @OWNER @SYSTEM
Order deny,allow
</Limit>

<Limit All>
Order deny,allow
</Limit>
</Policy>
EOF

# Hotspot-Konfiguration (Fallback für Offline-Betrieb)
print_status "Konfiguriere Hotspot..."

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
wpa_passphrase=photobox123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# dnsmasq Konfiguration
cat > /etc/dnsmasq.conf << 'EOF'
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/photobox.local/192.168.4.1
EOF

# Hotspot-Interface konfigurieren
cat > /etc/dhcpcd.conf.hotspot << 'EOF'
interface wlan0
static ip_address=192.168.4.1/24
nohook wpa_supplicant
EOF

# Boot-Optimierung
print_status "Optimiere Boot-Verhalten..."

# Splash Screen deaktivieren
sed -i 's/$/ splash plymouth.ignore-serial-consoles/' /boot/cmdline.txt

# Boot-Messages reduzieren
sed -i 's/$/ quiet/' /boot/cmdline.txt

# Schnellerer Boot
systemctl disable dphys-swapfile
systemctl disable apt-daily.service
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.service

# X11-Konfiguration für Touch
print_status "Konfiguriere Touch-Display..."
cat > /etc/X11/xorg.conf.d/99-calibration.conf << 'EOF'
Section "InputClass"
    Identifier "calibration"
    MatchProduct "ADS7846 Touchscreen"
    Option "Calibration" "160 3723 3896 181"
    Option "SwapAxes" "1"
EndSection
EOF

# Photobox-spezifische Konfiguration
print_status "Erstelle Photobox-Konfiguration..."

# Log-Verzeichnis
mkdir -p /var/log/photobox
chown $PI_USER:$PI_USER /var/log/photobox

# Backup-Verzeichnis
mkdir -p /home/$PI_USER/photobox_backup
chown $PI_USER:$PI_USER /home/$PI_USER/photobox_backup

# Temporäres Verzeichnis
mkdir -p /tmp/photobox
chown $PI_USER:$PI_USER /tmp/photobox

# Systemd Journal-Konfiguration
print_status "Konfiguriere Logging..."
cat > /etc/systemd/journald.conf.d/photobox.conf << 'EOF'
[Journal]
Storage=persistent
Compress=yes
SplitMode=uid
RateLimitInterval=30s
RateLimitBurst=1000
SystemMaxUse=100M
SystemKeepFree=500M
SystemMaxFileSize=50M
EOF

# Backup-Script erstellen
print_status "Erstelle Backup-Script..."
cat > /home/$PI_USER/backup_photobox.sh << 'EOF'
#!/bin/bash

# Photobox Backup Script
BACKUP_DIR="/home/pi/photobox_backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/photobox_backup_${DATE}.tar.gz"

echo "Starte Photobox Backup..."

# Erstelle Backup
tar -czf "$BACKUP_FILE" \
    --exclude="*.pyc" \
    --exclude="__pycache__" \
    --exclude=".venv" \
    --exclude="*.log" \
    /home/pi/Photobox/

# Behalte nur die letzten 10 Backups
cd "$BACKUP_DIR"
ls -t photobox_backup_*.tar.gz | tail -n +11 | xargs -r rm

echo "Backup erstellt: $BACKUP_FILE"
EOF

chmod +x /home/$PI_USER/backup_photobox.sh
chown $PI_USER:$PI_USER /home/$PI_USER/backup_photobox.sh

# Tägliches Backup via Cron
(crontab -u $PI_USER -l 2>/dev/null; echo "0 2 * * * /home/$PI_USER/backup_photobox.sh >> /var/log/photobox/backup.log 2>&1") | crontab -u $PI_USER -

# Hardware-Test Script
print_status "Erstelle Hardware-Test Script..."
cat > /home/$PI_USER/test_hardware.sh << 'EOF'
#!/bin/bash

echo "🔧 Photobox Hardware Test"
echo "========================"

# Kamera-Test
echo -n "Kamera: "
if gphoto2 --auto-detect | grep -q "Canon"; then
    echo "✅ Canon EOS erkannt"
else
    echo "❌ Keine Canon EOS gefunden"
fi

# USB-Geräte
echo -n "USB-Geräte: "
lsusb | wc -l
lsusb

# Display-Test
echo -n "Display: "
if xrandr > /dev/null 2>&1; then
    echo "✅ X11 Display verfügbar"
    xrandr | grep connected
else
    echo "❌ Kein Display erkannt"
fi

# Drucker-Test
echo -n "Drucker: "
if lpstat -p > /dev/null 2>&1; then
    lpstat -p
else
    echo "❌ Keine Drucker konfiguriert"
fi

# Netzwerk-Test
echo -n "Netzwerk: "
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Internet verfügbar"
else
    echo "⚠️ Kein Internet"
fi

# Speicher-Test
echo "Speicher:"
df -h /
free -h

# Temperatur
echo -n "CPU-Temperatur: "
vcgencmd measure_temp

echo "Test abgeschlossen!"
EOF

chmod +x /home/$PI_USER/test_hardware.sh
chown $PI_USER:$PI_USER /home/$PI_USER/test_hardware.sh

# Performance-Tuning
print_status "Optimiere Performance..."

# Swappiness reduzieren
echo 'vm.swappiness=10' >> /etc/sysctl.conf

# I/O Scheduler optimieren
echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="deadline"' > /etc/udev/rules.d/60-ioschedulers.rules

# tmpfs für temporäre Dateien
echo 'tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0' >> /etc/fstab
echo 'tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=30m 0 0' >> /etc/fstab

print_success "Photobox System Setup abgeschlossen!"
echo ""
echo "📋 Setup-Zusammenfassung:"
echo "   • System-Pakete installiert und konfiguriert"
echo "   • Python Virtual Environment erstellt"
echo "   • Kamera-Unterstützung (gphoto2) installiert"
echo "   • Drucker-System (CUPS) konfiguriert"
echo "   • Chromium Browser für Kiosk-Mode installiert"
echo "   • Hotspot-Fallback konfiguriert"
echo "   • Hardware-Tests und Backup-Scripte erstellt"
echo "   • Performance-Optimierungen angewendet"
echo ""
echo "🎯 Nächste Schritte:"
echo "   1. Hardware anschließen (Kamera, Drucker, Display)"
echo "   2. Autostart-Service installieren: sudo ./install_autostart.sh"
echo "   3. Hardware testen: ./test_hardware.sh"
echo "   4. System neustarten: sudo reboot"
echo ""
echo "🔧 Nützliche Befehle:"
echo "   • Hardware-Test: /home/$PI_USER/test_hardware.sh"
echo "   • Backup erstellen: /home/$PI_USER/backup_photobox.sh"
echo "   • CUPS-Webinterface: http://localhost:631"
echo "   • Photobox-App: http://localhost:5000"
echo ""
print_warning "Neustart erforderlich für vollständige Aktivierung!"
print_status "Führen Sie 'sudo reboot' aus, um das Setup abzuschließen."