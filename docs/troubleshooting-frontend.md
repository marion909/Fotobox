# 🚨 Frontend lädt nicht nach Installation - Schnelle Lösung

## Problem: Frontend lädt nach dem Neustart nicht

Das ist ein häufiges Problem nach der ersten Installation. Hier sind die schnellsten Lösungsansätze:

## 🔧 Schnell-Diagnose (ausführen auf dem Pi)

```bash
# 1. Diagnose-Script herunterladen und ausführen
curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/diagnose_installation.sh | bash
```

## 🚀 Häufigste Probleme & Lösungen

### 1. Service läuft nicht
```bash
# Service Status prüfen
sudo systemctl status photobox

# Service starten
sudo systemctl start photobox

# Service für Autostart aktivieren
sudo systemctl enable photobox

# Live Logs anzeigen
sudo journalctl -u photobox -f
```

### 2. Virtual Environment Problem
```bash
cd /home/pi/Photobox

# Virtual Environment neu erstellen
rm -rf .venv
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# Service neustarten
sudo systemctl restart photobox
```

### 3. Berechtigungen Problem
```bash
# Berechtigungen korrigieren
sudo chown -R pi:pi /home/pi/Photobox
sudo chmod +x /home/pi/Photobox/*.sh

# Service neustarten
sudo systemctl restart photobox
```

### 4. Port bereits belegt
```bash
# Prüfen was Port 5000 belegt
sudo netstat -tlnp | grep :5000

# Prozess beenden falls nötig (PID durch tatsächliche ersetzen)
sudo kill -9 <PID>

# Service neustarten
sudo systemctl restart photobox
```

### 5. Manueller App-Start zum Testen
```bash
cd /home/pi/Photobox

# App manuell starten (zum Debuggen)
.venv/bin/python app.py

# Wenn das funktioniert, ist es ein Service-Problem
# Strg+C zum Beenden, dann Service-Setup prüfen
```

## 🌐 Browser-Zugriff testen

Nach der Fehlerbehebung:

```bash
# Lokale IP herausfinden
hostname -I

# Browser öffnen mit:
http://localhost:5000        # Lokal auf dem Pi
http://[IP-ADRESSE]:5000    # Von anderen Geräten im Netzwerk
```

## 📋 Vollständige Neuinstallation (falls nötig)

```bash
# Cleanup (optional - nur bei größeren Problemen)
curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/cleanup_photobox.sh | bash

# Neuinstallation
curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/install_complete.sh | bash
```

## 🔍 Erweiterte Diagnose

```bash
# Detaillierte Service-Logs
sudo journalctl -u photobox --no-pager -n 50

# System-Status
sudo systemctl --failed

# Python-Module testen
cd /home/pi/Photobox
.venv/bin/python -c "import flask, PIL, requests; print('All modules OK')"

# Netzwerk-Test
curl -v http://localhost:5000
```

## 📞 Support

Falls die Probleme weiterhin bestehen:

1. **Diagnose-Output sammeln:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/diagnose_installation.sh | bash > diagnose.txt
   ```

2. **Service-Logs sammeln:**
   ```bash
   sudo journalctl -u photobox --no-pager > service-logs.txt
   ```

3. **GitHub Issue erstellen:** https://github.com/marion909/Fotobox/issues
   - Diagnose-Output anhängen
   - Service-Logs anhängen
   - Raspberry Pi Model und OS Version angeben

## ⚡ Notfall-Kiosk Start

Falls der Service nicht funktioniert, aber die App manuell läuft:

```bash
# Temporärer Kiosk-Start ohne Service
cd /home/pi/Photobox
.venv/bin/python app.py &

# Chromium im Kiosk-Modus starten
DISPLAY=:0 chromium-browser --kiosk --start-fullscreen http://localhost:5000 &
```