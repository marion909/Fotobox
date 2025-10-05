#!/bin/bash

# Photobox Autostart Service Installation Script
# Installiert systemd Service für automatischen Start der Photobox-Anwendung

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="photobox"
USER="pi"

echo "🚀 Photobox Autostart Service Installation"
echo "========================================="

# Prüfung ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then
    echo "❌ Bitte als root ausführen: sudo $0"
    exit 1
fi

# Service-Datei erstellen
echo "📝 Erstelle systemd Service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Photobox Flask Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${SCRIPT_DIR}
Environment=PATH=${SCRIPT_DIR}/.venv/bin
ExecStartPre=/bin/sleep 10
ExecStart=${SCRIPT_DIR}/.venv/bin/python ${SCRIPT_DIR}/app.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=photobox

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren
echo "🔄 Aktiviere Service..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service

# Kiosk-Mode Script erstellen
echo "🖥️ Erstelle Kiosk-Mode Script..."
cat > /home/${USER}/start_kiosk.sh << 'EOF'
#!/bin/bash

# Photobox Kiosk Mode Starter
# Startet Chromium im Vollbild-Modus

# Warten auf X-Server
while ! pgrep -x "X" > /dev/null; do
    sleep 1
done

# Weitere 5 Sekunden warten für Desktop-Initialisierung
sleep 5

# Bildschirmschoner deaktivieren
xset s off
xset -dpms
xset s noblank

# Chromium im Kiosk-Modus starten
chromium-browser \
    --kiosk \
    --no-first-run \
    --disable-translate \
    --disable-infobars \
    --disable-suggestions-service \
    --disable-save-password-bubble \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --disable-new-avatar-menu \
    --disable-new-profile-management \
    --disable-guest-view-cross-process-frames \
    --disable-background-mode \
    --disable-add-to-shelf \
    --disable-first-run-ui \
    --disable-domain-reliability \
    --disable-component-update \
    --no-default-browser-check \
    --no-pings \
    --media-cache-size=1 \
    --disk-cache-dir=/tmp/chrome-cache \
    --aggressive-cache-discard \
    --memory-pressure-off \
    --max_old_space_size=100 \
    --force-device-scale-factor=1.25 \
    --touch-events=enabled \
    --pull-to-refresh=1 \
    --overscroll-history-navigation=0 \
    --enable-pinch \
    --app=http://localhost:5000
EOF

# Script ausführbar machen
chmod +x /home/${USER}/start_kiosk.sh
chown ${USER}:${USER} /home/${USER}/start_kiosk.sh

# Autostart für Desktop-Session erstellen
mkdir -p /home/${USER}/.config/autostart
cat > /home/${USER}/.config/autostart/photobox-kiosk.desktop << EOF
[Desktop Entry]
Type=Application
Name=Photobox Kiosk
Exec=/home/${USER}/start_kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown ${USER}:${USER} /home/${USER}/.config/autostart/photobox-kiosk.desktop

# Boot-Konfiguration anpassen
echo "⚙️ Konfiguriere Boot-Verhalten..."

# Auto-Login aktivieren (falls nicht bereits aktiviert)
if ! grep -q "autologin-user=${USER}" /etc/lightdm/lightdm.conf; then
    sed -i "s/^#autologin-user=.*/autologin-user=${USER}/" /etc/lightdm/lightdm.conf
    echo "✅ Auto-Login für ${USER} aktiviert"
fi

# Desktop-Session für Kiosk optimieren
cat > /home/${USER}/.xsessionrc << 'EOF'
#!/bin/bash
# Photobox Desktop Session Konfiguration

# Mauszeiger nach 10 Sekunden verstecken
unclutter -display :0 -noevents -grab -idle 10 &

# Bildschirmschoner permanent deaktivieren
xset s off
xset -dpms
xset s noblank

# Touch-Kalibrierung (falls erforderlich)
# xinput set-prop "pointer" "libinput Accel Profile Enabled" 0, 1

# Virtuelle Tastatur (falls Touch-Eingaben benötigt)
# onboard &
EOF

chown ${USER}:${USER} /home/${USER}/.xsessionrc
chmod +x /home/${USER}/.xsessionrc

# Watchdog-Script erstellen
echo "🐕 Erstelle Watchdog-Script..."
cat > /home/${USER}/photobox_watchdog.sh << 'EOF'
#!/bin/bash

# Photobox Watchdog - Überwacht Service und startet bei Bedarf neu

FLASK_URL="http://localhost:5000"
SERVICE_NAME="photobox"
LOG_FILE="/var/log/photobox_watchdog.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> ${LOG_FILE}
}

check_service() {
    if ! systemctl is-active --quiet ${SERVICE_NAME}; then
        log_message "❌ Service ${SERVICE_NAME} nicht aktiv - starte neu"
        systemctl restart ${SERVICE_NAME}
        sleep 5
        return 1
    fi
    return 0
}

check_web_interface() {
    if ! curl -s --connect-timeout 5 ${FLASK_URL} > /dev/null; then
        log_message "❌ Web-Interface nicht erreichbar - starte Service neu"
        systemctl restart ${SERVICE_NAME}
        sleep 10
        return 1
    fi
    return 0
}

# Service-Status prüfen
if check_service; then
    # Web-Interface prüfen
    if check_web_interface; then
        log_message "✅ Photobox läuft normal"
    fi
else
    log_message "🔄 Service-Neustart ausgeführt"
fi
EOF

chmod +x /home/${USER}/photobox_watchdog.sh
chown ${USER}:${USER} /home/${USER}/photobox_watchdog.sh

# Crontab für Watchdog
echo "⏰ Füge Watchdog zu Crontab hinzu..."
(crontab -u ${USER} -l 2>/dev/null; echo "*/2 * * * * /home/${USER}/photobox_watchdog.sh") | crontab -u ${USER} -

# Network-Fallback Script
cat > /home/${USER}/network_fallback.sh << 'EOF'
#!/bin/bash

# Network Fallback für Offline-Betrieb
# Startet lokalen Hotspot falls kein Internet verfügbar

check_internet() {
    ping -c 1 8.8.8.8 &> /dev/null
}

start_hotspot() {
    sudo systemctl start hostapd
    sudo systemctl start dnsmasq
}

stop_hotspot() {
    sudo systemctl stop hostapd
    sudo systemctl stop dnsmasq
}

if ! check_internet; then
    echo "Kein Internet - starte Hotspot"
    start_hotspot
else
    echo "Internet verfügbar - stoppe Hotspot"
    stop_hotspot
fi
EOF

chmod +x /home/${USER}/network_fallback.sh
chown ${USER}:${USER} /home/${USER}/network_fallback.sh

echo ""
echo "✅ Installation abgeschlossen!"
echo ""
echo "📋 Zusammenfassung:"
echo "   • Service: ${SERVICE_NAME} (systemd)"
echo "   • Kiosk-Mode: Chromium Vollbild"
echo "   • Auto-Login: ${USER}"
echo "   • Watchdog: alle 2 Minuten"
echo "   • Logs: /var/log/photobox_watchdog.log"
echo ""
echo "🎮 Befehle:"
echo "   sudo systemctl start ${SERVICE_NAME}    # Service starten"
echo "   sudo systemctl stop ${SERVICE_NAME}     # Service stoppen" 
echo "   sudo systemctl status ${SERVICE_NAME}   # Service-Status"
echo "   sudo journalctl -u ${SERVICE_NAME} -f   # Live-Logs"
echo ""
echo "🔄 Neustart empfohlen für vollständige Aktivierung:"
echo "   sudo reboot"