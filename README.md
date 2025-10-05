# 📸 Photobox - Professionelle Fotobox für Events & Hochzeiten

[![Python Version](https://img.shields.io/badge/python-3.8%2B-blue)](https://python.org)
[![Flask](https://img.shields.io/badge/flask-2.3%2B-green)](https://flask.palletsprojects.com/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Phase](https://img.shields.io/badge/phase-4.1-orange)](photobox_roadmap.md)

Eine vollständige, anpassbare Fotobox-Lösung für Raspberry Pi mit Canon EOS Kameras, Touch-Display, automatischem Drucken und Server-Upload.

![Photobox Demo](https://via.placeholder.com/800x400/007bff/white?text=Photobox+Demo+Screenshot)

## 🎯 Features

### ✨ **Phase 4.1 - Aktuelle Version**
- 🎬 **Erweiteter Countdown** - Animierte 3-2-1 Anzeige mit konfigurierbarer Dauer
- 📱 **Touch-optimierte UI** - Responsive Design für alle Bildschirmgrößen
- 📸 **Automatische Foto-Aufnahme** - Canon EOS Integration via gphoto2
- 🖼️ **Foto-Galerie** - Elegante Übersicht aller aufgenommenen Bilder
- 🎨 **Overlay-System** - Logos, Texte und Rahmen hinzufügen
- 🖨️ **Automatisches Drucken** - CUPS Integration für sofortigen Fotodruck
- ☁️ **Server-Upload** - Automatischer Upload zu eigenem Server
- ⚙️ **Admin-Interface** - Umfassende Konfigurationsmöglichkeiten
- � **Erweiterte Features** - Konfigurierbare Countdown-Animation
- �️ **Kiosk-Modus** - Vollbild-Betrieb für Events

### 🔧 **Technische Features**
- **REST API** für alle Funktionen
- **Real-time Status** Updates
- **Responsive Design** für Touch-Displays
- **Keyboard Shortcuts** für Entwicklung
- **Automatische Backups** mit konfigurierbarer Retention
- **System-Monitoring** und Hardware-Tests
- **Modular aufgebaut** - Einfach erweiterbar

## 🚀 Schnellstart

### 📋 Voraussetzungen

**Hardware:**
- Raspberry Pi 4 (empfohlen) oder 3B+
- Canon EOS Kamera (getestet mit 2000D)
- 7" Touch-Display oder HDMI-Monitor
- USB-Kabel für Kamera
- Fotodrucker (optional, CUPS-kompatibel)
- 32GB+ SD-Karte (Class 10)

**Software:**
- Python 3.8+
- Git
- gphoto2
- CUPS (für Drucken)

### 📥 Installation

#### Option 1: Schnell-Installation (empfohlen)
```bash
# Repository klonen
git clone https://github.com/marion909/Fotobox.git
cd Fotobox

# Automatische Installation (Raspberry Pi)
chmod +x install_complete.sh
./install_complete.sh
```

#### Option 2: Manuelle Installation
```bash
# Repository klonen
git clone https://github.com/marion909/Fotobox.git
cd Fotobox

# Virtual Environment erstellen
python3 -m venv .venv
source .venv/bin/activate  # Linux/Mac
# oder
.venv\Scripts\activate     # Windows

# Abhängigkeiten installieren
pip install -r requirements.txt

# Kamera-Software installieren (Linux)
sudo apt update
sudo apt install -y gphoto2 libgphoto2-dev

# App starten
python app.py
```

### 🌐 Zugriff
- **Hauptseite:** `http://localhost:5000`
- **Admin-Panel:** `http://localhost:5000/admin`
- **Erweiterte Features:** `http://localhost:5000/features`
- **Foto-Galerie:** `http://localhost:5000/gallery`

## 🔧 Konfiguration

### 📷 Kamera-Setup
```bash
# Kamera-Verbindung testen
gphoto2 --auto-detect
gphoto2 --capture-image-and-download

# USB-Modus der Kamera auf "PC Connect" stellen
# Kamera sollte als "Canon EOS 2000D" erkannt werden
```

### 🖨️ Drucker-Setup (optional)
```bash
# Option 1: Automatisches Drucker-Setup
chmod +x setup_printer.sh
sudo ./setup_printer.sh

# Option 2: Manuelle CUPS-Installation
sudo apt update
sudo apt install cups cups-client printer-driver-all
sudo systemctl enable cups
sudo systemctl start cups

# Web-Interface öffnen: http://localhost:631
# Benutzer zu lpadmin Gruppe hinzufügen
sudo usermod -a -G lpadmin $USER

# Drucker hinzufügen und testen über Web-Interface
```

**Canon-Drucker Tipps:**
- Für Canon PIXMA-Serie: Gutenprint-Treiber verwenden
- Offizielle Canon-Treiber von [canon.de](https://canon.de) herunterladen
- Bei Problemen: Generic PostScript-Treiber probieren

### ☁️ Server-Upload konfigurieren
1. **Admin-Panel öffnen:** `http://localhost:5000/admin`
2. **Upload aktivieren** in den Server-Einstellungen
3. **Endpoint konfigurieren:** `https://your-server.com/upload.php`
4. **API-Key setzen** für Authentifizierung
5. **Verbindung testen** über Admin-Panel

### ⏱️ Erweiterte Features
1. **Features-Seite öffnen:** `http://localhost:5000/features`
2. **Countdown aktivieren/deaktivieren**
3. **Countdown-Dauer einstellen** (1-10 Sekunden)
4. **Countdown testen** über die Test-Funktion

## 🎨 Anpassung

### Themes & Overlays
```bash
# Eigenes Logo hinzufügen
cp your-logo.png overlays/logo.png

# Custom CSS für eigenes Branding
# Datei: static/css/custom.css erstellen
```

### Konfiguration
Alle Einstellungen werden in `config.json` gespeichert:
```json
{
  "countdown_enabled": true,
  "countdown_duration": 3,
  "overlay": {
    "enabled": true,
    "text_content": "Meine Hochzeit 2025"
  },
  "upload": {
    "enabled": true,
    "http_endpoint": "https://server.com/upload"
  }
}
```

## 🖥️ Kiosk-Modus (Produktiv-Einsatz)

### Autostart einrichten
```bash
# Autostart-Service installieren
chmod +x install_autostart.sh
sudo ./install_autostart.sh

# Service-Status prüfen
sudo systemctl status photobox
sudo systemctl enable photobox
```

### Vollbild-Browser konfigurieren
```bash
# Chromium im Kiosk-Modus starten
chromium-browser --kiosk --noerrdialogs --disable-translate --no-first-run --fast --fast-start --disable-default-apps --disable-popup-blocking http://localhost:5000
```

## 🌐 Server-Upload System

Das Projekt enthält ein vollständiges PHP-Server-Upload-System:

### Server-Seite einrichten
```bash
cd Server_Upload/

# Upload-Skript auf Server hochladen
# Dateien: upload.php, gallery.php, config.php

# Verzeichnisse erstellen
mkdir uploads
chmod 755 uploads

# Server testen
python configure_server.py
```

### Features des Server-Systems
- 🔒 **API-Key Authentifizierung**
- 📁 **Automatische Ordner-Organisation** (Jahr/Monat/Tag)
- 🖼️ **Thumbnail-Generierung**
- 🌐 **Web-Galerie** für alle Uploads
- 🛡️ **Sicherheitsfeatures** (.htaccess, Input-Validation)
- 🔄 **Automatische Bereinigung** alter Dateien

## 📂 Projektstruktur

```
Fotobox/
├── app.py                    # Haupt-Flask-Anwendung
├── config.py                 # Konfigurationsmanagement
├── requirements.txt          # Python-Abhängigkeiten
├── config.json              # App-Konfiguration (wird erstellt)
├── photobox_roadmap.md      # Entwicklungs-Roadmap
│
├── static/                  # Statische Web-Dateien
│   ├── css/style.css       # Haupt-Stylesheet
│   └── js/
│       ├── app.js          # Haupt-JavaScript
│       └── countdown.js    # Countdown-Funktionen (Phase 4)
│
├── templates/              # HTML-Templates
│   ├── base.html          # Basis-Template
│   ├── index.html         # Hauptseite
│   ├── admin.html         # Admin-Panel
│   ├── gallery.html       # Foto-Galerie
│   └── features.html      # Erweiterte Features (Phase 4)
│
├── photos/                # Aufgenommene Fotos (wird erstellt)
├── overlays/              # Logo & Overlay-Dateien
├── temp/                  # Temporäre Dateien
├── backups/               # System-Backups
│
├── Server_Upload/         # PHP Server-Upload System
│   ├── upload.php         # Haupt-Upload-Handler
│   ├── gallery.php        # Server-Galerie
│   ├── config.php         # Server-Konfiguration
│   └── README.md          # Server-Dokumentation
│
├── scripts/               # Setup & Deployment
│   ├── install_complete.sh # Komplette Auto-Installation
│   ├── install_autostart.sh # Autostart-Service
│   └── setup_system.sh     # System-Vorbereitung
│
└── fix_camera_usb.sh      # USB-Kamera Fix Script
```

## 🎯 API Endpoints

### Haupt-Funktionen
- `GET /` - Hauptseite mit Foto-Button
- `GET /gallery` - Foto-Galerie
- `GET /admin` - Admin-Panel
- `GET /features` - Erweiterte Features (Phase 4)

### REST API
- `POST /api/take_photo` - Foto aufnehmen
- `GET /api/camera_status` - Kamera-Status prüfen
- `GET /api/test_camera` - Ausführlicher Kamera-Test
- `GET/POST /api/config` - Konfiguration abrufen/setzen
- `GET/POST /api/countdown` - Countdown-Einstellungen (Phase 4)
- `POST /api/test_upload` - Server-Upload testen
- `POST /api/test_printer` - Drucker-Test
- `GET /photo/<filename>` - Einzelnes Foto abrufen

## 🎨 Bedienung

### Touch-Interface
- **Großer Foto-Button** - Foto mit Countdown aufnehmen
- **Navigation unten** - Zwischen Seiten wechseln
- **Galerie** - Fotos anzeigen, drucken, teilen
- **Admin** - Alle Einstellungen konfigurieren
- **Features** - Erweiterte Funktionen verwalten

### Keyboard-Shortcuts (Entwicklung)
- `Space` - Foto aufnehmen
- `G` - Galerie öffnen
- `A` - Admin-Panel öffnen
- `H` - Zurück zur Hauptseite
- `ESC` - Modal schließen / Countdown abbrechen

## 🔍 Fehlerbehebung

### Häufige Probleme

**Kamera nicht erkannt:**
```bash
# USB-Verbindung prüfen
lsusb | grep Canon

# gphoto2 Prozesse beenden
sudo killall gphoto2

# Kamera neu verbinden und testen
gphoto2 --auto-detect
```

**USB Device Busy Error ("Could not claim the USB device"):**

**🚀 Automatische Lösung (empfohlen):**
```bash
# Automatisches Fix-Script ausführen
chmod +x fix_camera_usb.sh
./fix_camera_usb.sh
```

**📋 Manuelle Lösung:**
```bash
# 1. Schneller Fix (meist ausreichend)
sudo killall gphoto2 gvfs-gphoto2-volume-monitor
sudo systemctl stop gvfs-daemon
# Kamera USB-Kabel ziehen, 10 Sek warten, neu verbinden
gphoto2 --auto-detect

# 2. Erweiterte Lösung bei hartnäckigen Problemen
sudo pkill -f gphoto2
sudo modprobe -r uvcvideo gspca_main
# Kamera neu verbinden
gphoto2 --auto-detect

# 3. Permanente Lösung installieren
echo 'ENV{ID_GPHOTO2}=="1", ENV{UDISKS_IGNORE}="1"' | sudo tee /etc/udev/rules.d/40-gphoto2-disable-gvfs.rules
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{idProduct}=="*", MODE="0666", GROUP="plugdev"' | sudo tee -a /etc/udev/rules.d/40-gphoto2-disable-gvfs.rules
sudo udevadm control --reload-rules

# 4. GVFS vollständig deaktivieren (falls nötig)
sudo systemctl disable gvfs-daemon
sudo systemctl mask gvfs-daemon
```

**Canon EOS spezifische Fixes:**
```bash
# Canon EOS 1500D/2000D USB-Modus prüfen
# Kamera-Menü: Einstellungen > Kommunikation > USB-Verbindung
# Auf "PC-Verbindung" oder "PTP" stellen (NICHT "Mass Storage")

# Kamera-Firmware aktualisieren falls möglich
# Canon Website: Neueste Firmware für EOS 1500D herunterladen

# USB-Port testen
# Verschiedene USB-Ports am Raspberry Pi testen
# USB 2.0 Ports oft stabiler als USB 3.0

# Stromversorgung prüfen
# Starkes USB-Netzteil (min. 3A) für Raspberry Pi verwenden
# Kamera-Akku voll geladen
```

**Port bereits belegt:**
```bash
# Andere Flask-Apps beenden
sudo pkill -f python
sudo pkill -f flask

# Port-Status prüfen
sudo netstat -tulpn | grep :5000
```

**Permissions-Probleme:**
```bash
# Benutzer zu nötigen Gruppen hinzufügen
sudo usermod -a -G dialout,plugdev,lpadmin $USER

# Udev-Regeln für Kamera
sudo cp scripts/99-gphoto2.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules

# Nach Gruppen-Änderung neu anmelden
newgrp lpadmin
```

**Drucker-Probleme:**
```bash
# CUPS-Status prüfen
sudo systemctl status cups

# Verfügbare Drucker anzeigen
lpstat -p -d

# Drucker-Warteschlange anzeigen
lpq

# CUPS Web-Interface
# http://localhost:631

# Drucker-Logs anzeigen
sudo tail -f /var/log/cups/error_log

# Canon-Drucker spezifisch
lsusb | grep -i canon
```

### Log-Dateien
- **App-Logs:** `tail -f logs/photobox.log`
- **System-Logs:** `journalctl -u photobox -f`
- **Upload-Logs:** Siehe Server `uploads/upload_log.json`

### Debug-Modus
```bash
# Flask im Debug-Modus starten
export FLASK_DEBUG=1
python app.py
```

### Kamera-Probleme

**Sofortlösung für "Could not claim USB device":**
```bash
# Schneller Fix (meist ausreichend)
sudo killall gphoto2 gvfs-gphoto2-volume-monitor
sudo systemctl stop gvfs-daemon
# Kamera USB-Kabel ziehen und neu verbinden
gphoto2 --auto-detect

# Erweiterte Diagnose
lsusb | grep Canon                    # Kamera-Erkennung prüfen
ps aux | grep gphoto                  # Laufende Prozesse prüfen
sudo lsof | grep gphoto               # Offene Dateien prüfen
```

**Vollständige Kamera-Diagnose:**
```bash
# 1. USB-Geräte anzeigen
lsusb

# 2. Detaillierte gphoto2 Diagnose
env LANG=C gphoto2 --debug --debug-logfile=camera-debug.txt --auto-detect
cat camera-debug.txt | grep -i error

# 3. Kamera-Konfiguration anzeigen (wenn verbunden)
gphoto2 --list-config
gphoto2 --get-config /main/settings/capturetarget
gphoto2 --get-config /main/other/d402

# 4. USB-Permissions prüfen
ls -la /dev/bus/usb/*/
groups $USER | grep -E "plugdev|dialout"

# 5. Kernel-Module prüfen
lsmod | grep -E "gspca|uvc|v4l2"
dmesg | grep -i canon | tail -10
```

**Häufige Canon EOS Probleme:**
```bash
# Problem: Kamera schaltet sich ab
# Lösung: Power-Saving in Kamera-Menü deaktivieren
gphoto2 --set-config /main/settings/autopoweroff=0

# Problem: Kamera im falschen Modus
# Lösung: PTP-Modus erzwingen
gphoto2 --set-config /main/settings/capturetarget=0  # Kamera-RAM
# oder
gphoto2 --set-config /main/settings/capturetarget=1  # SD-Karte

# Problem: Langsame Aufnahme
# Lösung: Bildqualität anpassen
gphoto2 --set-config /main/imgsettings/imageformat=7  # JPEG Large Fine
gphoto2 --set-config /main/imgsettings/iso=1         # Auto ISO
```

### App-Debugging
- Flask Debug-Modus ist standardmäßig aktiviert
- Browser-Konsole für JavaScript-Fehler
- Netzwerk-Tab für API-Calls prüfen

## 📋 Nächste Schritte (Phase 2)

### Features zu implementieren:
- [ ] Overlay/Branding-System
- [ ] Automatisches Drucken via CUPS
- [ ] Server-Upload (HTTP POST)
## 🗺️ Roadmap

Siehe detaillierte Entwicklungs-Roadmap: [photobox_roadmap.md](photobox_roadmap.md)

### ✅ **Abgeschlossen:**
- **Phase 1** - Grundfunktionen ✅
- **Phase 2** - Overlays, Drucken, Upload ✅  
- **Phase 3** - Kiosk & Deployment ✅
- **Phase 4.1** - Erweiteter Countdown ✅

### 🔄 **Aktuell in Arbeit:**
- **Phase 4.2** - QR-Code für Downloads
- **Phase 4.3** - Mehrfachaufnahme/Collage
- **Phase 4.4** - Layout & Filter-Auswahl

### 🎯 **Geplant:**
- Multi-Language Support
- Cloud-Integration (Google Drive, Dropbox)
- Social Media Sharing
- Event-Management System
- Analytics & Statistiken

## � Beitragen

### Issues & Feature-Requests
- [GitHub Issues](https://github.com/marion909/Fotobox/issues) für Bug-Reports
- [Discussions](https://github.com/marion909/Fotobox/discussions) für Feature-Ideen

### Development
```bash
# Fork des Repositories erstellen
git clone https://github.com/YOUR-USERNAME/Fotobox.git
cd Fotobox

# Feature-Branch erstellen
git checkout -b feature/new-awesome-feature

# Änderungen committen
git commit -m "Add awesome new feature"

# Pull Request erstellen
```

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe [LICENSE](LICENSE) für Details.

## 🙏 Acknowledgments

- **gphoto2** - Kamera-Integration
- **Flask** - Web-Framework
- **Pillow** - Bildverarbeitung
- **Canon** - Kamera-Kompatibilität
- **Raspberry Pi Foundation** - Hardware-Plattform

## 📊 Projekt-Status

| Komponente | Status | Version | Tests |
|------------|--------|---------|--------|
| Core App | ✅ Stabil | 4.1.0 | ✅ Getestet |
| Countdown | ✅ Vollständig | 4.1.0 | ✅ Getestet |
| Server Upload | ✅ Produktiv | 4.0.0 | ✅ Getestet |
| Kiosk Mode | ✅ Funktional | 3.0.0 | ✅ Getestet |
| Print System | ✅ Funktional | 2.0.0 | ⚠️ Hardware-abhängig |
| QR Codes | 🔄 In Entwicklung | 4.2.0 | ❌ Nicht verfügbar |

---

**📸 Happy Photo Booth Building! 🎉**

Erstellt mit ❤️ für unvergessliche Events und Hochzeiten.
3. Flask-Logs im Terminal beachten
4. USB-Kabel und -Anschlüsse testen

---

**Status:** Phase 1 ✅ Abgeschlossen  
**Nächste Phase:** Overlays & Drucken (Phase 2)  
**Zielplattform:** Raspberry Pi 4 mit Touch-Display