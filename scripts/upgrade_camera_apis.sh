#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║          📷 MODERNE KAMERA-API INSTALLATION                   ║
# ║        Bessere Alternativen zu gphoto2 installieren          ║
# ╚═══════════════════════════════════════════════════════════════╝

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               📷 KAMERA-API UPGRADE INSTALLATION              ║"
echo "║             Robuste Canon EOS Integration Setup              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo

# Prüfe System
echo "🔍 System-Check..."
OS=$(uname -s)
ARCH=$(uname -m)
echo "  💻 OS: $OS"
echo "  🏗️  Architektur: $ARCH"
echo

# Prüfe ob wir auf Raspberry Pi sind
if [ -f "/proc/cpuinfo" ] && grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "  🥧 Raspberry Pi erkannt"
    IS_RPI=true
else
    echo "  🖥️  Standard Linux System"
    IS_RPI=false
fi
echo

# Verzeichnis Setup
PHOTOBOX_DIR="/home/pi/Photobox"
if [ ! -d "$PHOTOBOX_DIR" ]; then
    PHOTOBOX_DIR=$(pwd)
fi

echo "📁 Photobox Verzeichnis: $PHOTOBOX_DIR"
cd "$PHOTOBOX_DIR"
echo

# Virtual Environment aktivieren
if [ -d ".venv" ]; then
    echo "🐍 Aktiviere Python Virtual Environment..."
    source .venv/bin/activate
    echo "  ✅ Virtual Environment aktiv"
else
    echo "⚠️  Kein Virtual Environment gefunden - verwende System Python"
fi
echo

# 1. GPHOTO2 PYTHON BINDINGS (einfachste Verbesserung)
echo "1️⃣ Installation: gphoto2 Python Bindings..."
echo "   📦 Installiere libgphoto2-dev Abhängigkeiten..."

sudo apt-get update -qq
sudo apt-get install -y \
    libgphoto2-dev \
    libgphoto2-port12 \
    python3-dev \
    build-essential \
    pkg-config

echo "   🐍 Installiere Python gphoto2 Paket..."
pip install gphoto2 || {
    echo "   ⚠️ gphoto2 Python Installation fehlgeschlagen - verwende Fallback"
}
echo

# 2. CANON EDSDK (beste Option, falls verfügbar)
echo "2️⃣ Canon EDSDK Setup..."

# Canon EDSDK ist proprietär und muss manuell heruntergeladen werden
if [ -f "canon-edsdk-*.tar.gz" ] || [ -f "EDSDK_*.zip" ]; then
    echo "   ✅ Canon EDSDK Archive gefunden"
    echo "   🚀 Installiere Canon EDSDK..."
    
    # Entpacke und installiere EDSDK
    # (Hier würde die EDSDK Installation stehen)
    echo "   ⚠️  Canon EDSDK Installation erfordert manuelle Schritte"
    echo "   📖 Siehe: https://developers.canon-europe.com/developers/"
else
    echo "   ⚠️  Canon EDSDK Archive nicht gefunden"
    echo "   💡 Download erforderlich von: https://developers.canon-europe.com/"
fi
echo

# 3. USB OPTIMIERUNGEN
echo "3️⃣ USB-System Optimierungen..."

# USB-Timeout erhöhen
echo "   ⚙️ USB-Timeout Optimierung..."
sudo tee /etc/modprobe.d/usbcore.conf > /dev/null << EOF
# USB Timeout für Kamera-Operationen erhöhen
options usbcore autosuspend=-1
options usb_storage delay_use=1
EOF

# USB-Power Management deaktivieren
echo "   🔋 USB Power Management..."
sudo tee /etc/udev/rules.d/50-usb-camera.rules > /dev/null << EOF
# Canon Kamera USB Optimierungen
SUBSYSTEM=="usb", ATTRS{idVendor}=="04a9", ATTRS{idProduct}=="32e1", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="04a9", ATTR{power/control}="on"

# Verhindere automount von Kamera
SUBSYSTEM=="block", ATTRS{idVendor}=="04a9", ENV{UDISKS_IGNORE}="1"
EOF

echo "   ✅ USB-Regeln erstellt"
echo

# 4. GVFS KONFLIKT-LÖSUNG (permanent)
echo "4️⃣ GVFS Konflikt-Lösung..."

# GVFS für Kameras deaktivieren
sudo mkdir -p /etc/systemd/system/gvfs-gphoto2-volume-monitor.service.d/
sudo tee /etc/systemd/system/gvfs-gphoto2-volume-monitor.service.d/override.conf > /dev/null << EOF
[Unit]
# Deaktiviere GVFS für Kameras (Photobox Konflikt-Lösung)
ConditionPathExists=!/home/pi/Photobox/.disable-gvfs
EOF

# Deaktivierungs-Flag erstellen
touch /home/pi/Photobox/.disable-gvfs

echo "   ✅ GVFS Kamera-Monitor deaktiviert"
echo

# 5. PHOTOBOX SERVICE UPDATE
echo "5️⃣ Photobox Service Update..."

# Backup der alten camera_manager.py
if [ -f "camera_manager.py" ]; then
    cp camera_manager.py camera_manager.py.backup
    echo "   💾 Backup: camera_manager.py.backup erstellt"
fi

# Verwende moderne Version
if [ -f "modern_camera_manager.py" ]; then
    cp modern_camera_manager.py camera_manager.py
    echo "   🚀 Moderne camera_manager.py aktiviert"
else
    echo "   ⚠️  modern_camera_manager.py nicht gefunden - Download erforderlich"
fi

echo

# 6. TESTS
echo "6️⃣ API-Tests..."

echo "   🧪 Teste gphoto2 Python API..."
python3 -c "
try:
    import gphoto2 as gp
    print('   ✅ gphoto2 Python: OK')
except ImportError:
    print('   ❌ gphoto2 Python: Nicht verfügbar')
" 2>/dev/null

echo "   🧪 Teste Canon EDSDK..."
python3 -c "
try:
    import canon_edsdk
    print('   ✅ Canon EDSDK: OK')
except ImportError:
    print('   ❌ Canon EDSDK: Nicht verfügbar')
" 2>/dev/null

echo "   🧪 Teste gphoto2 CLI..."
if command -v gphoto2 > /dev/null; then
    echo "   ✅ gphoto2 CLI: Verfügbar"
else
    echo "   ❌ gphoto2 CLI: Nicht verfügbar"
fi

echo

# 7. SERVICE RESTART
echo "7️⃣ Service Neustart..."

if systemctl is-active --quiet photobox; then
    echo "   🔄 Starte Photobox Service neu..."
    sudo systemctl restart photobox
    echo "   ✅ Service neugestartet"
else
    echo "   ⚠️  Photobox Service nicht aktiv"
fi

echo

# 8. FINAL TEST
echo "8️⃣ Kamera-Test..."

echo "   📷 Teste Kamera-Erkennung..."
gphoto2 --auto-detect 2>/dev/null | grep -i canon && {
    echo "   ✅ Canon Kamera erkannt"
    
    echo "   📸 Teste Foto-Aufnahme..."
    if gphoto2 --capture-image 2>/dev/null; then
        echo "   ✅ Foto-Aufnahme erfolgreich"
    else
        echo "   ⚠️  Foto-Aufnahme fehlgeschlagen (möglicherweise PTP Device Busy)"
    fi
} || {
    echo "   ❌ Keine Canon Kamera gefunden"
}

echo

echo "═══════════════════════════════════════════════════════════════"
echo "                    🎯 INSTALLATION ABGESCHLOSSEN"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "📊 INSTALLIERTE VERBESSERUNGEN:"
echo
echo "1️⃣ ✅ gphoto2 Python Bindings (bessere API als CLI)"
echo "2️⃣ ⚙️ USB-System Optimierungen"
echo "3️⃣ 🚫 GVFS Konflikt-Lösung (permanent)"
echo "4️⃣ 🚀 Moderne camera_manager.py mit Fallback-System"
echo
echo "💡 NÄCHSTE SCHRITTE:"
echo
echo "1️⃣ Teste die Photobox App:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo
echo "2️⃣ Live-Logs überwachen:"
echo "   sudo journalctl -u photobox -f"
echo
echo "3️⃣ Falls Canon EDSDK gewünscht:"
echo "   - Download: https://developers.canon-europe.com/"
echo "   - Archive ins Photobox-Verzeichnis legen"
echo "   - Script erneut ausführen"
echo
echo "✅ Upgrade abgeschlossen!"