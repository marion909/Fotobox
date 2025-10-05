# 📷 Canon EOS Kamera Probleme - Komplette Lösung

## 🚨 Problem: Kamera zeigt an, aber Foto-Aufnahme schlägt fehl

Das ist ein **sehr häufiges Problem** bei Canon EOS Kameras. Hier sind die bewährten Lösungen:

## 🔧 Sofort-Lösung (Automatisch)

```bash
# Führe das automatische Kamera-Fix Script aus:
curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/diagnose_camera.sh | sudo bash
```

## 🎯 Häufigste Ursachen & Manuelle Lösungen

### 1. **"Could not claim USB device" Fehler**

**Ursache:** Andere Prozesse blockieren die Kamera

```bash
# Störende Prozesse beenden:
sudo killall gphoto2 gvfs-gphoto2-volume-monitor
sudo systemctl stop gvfs-daemon

# USB-Module zurücksetzen:
sudo modprobe -r uvcvideo
sleep 2
sudo modprobe uvcvideo

# Test:
gphoto2 --capture-image
```

### 2. **Canon EOS Kamera-Einstellungen**

**KRITISCH:** Diese Einstellungen **müssen** an der Kamera gesetzt werden:

#### 📱 **Kamera-Menü Einstellungen:**
- **USB-Verbindung:** `PC Connect` oder `PTP` (NICHT "Mass Storage")
- **Auto Power Off:** `Deaktivieren` oder mindestens `30min`
- **Shooting Mode:** `Manual (M)` oder `Av (Aperture Priority)`
- **Image Quality:** `JPEG Large Fine` (RAW ist langsam)
- **Fokus:** `Manual Focus` oder `One-Shot AF`

#### 🔧 **Wichtige Canon EOS Menü-Pfade:**
```
Canon EOS 1500D/2000D:
├── Setup Menu → Communication → Wi-Fi/NFC → Disable
├── Setup Menu → Communication → USB → PC Connect  
├── Setup Menu → Power Management → Auto Power Off → Disable
├── Shooting Menu → Image Quality → JPEG L
└── AF Menu → AI Focus → One Shot
```

### 3. **gphoto2 Kamera-Einstellungen optimieren**

```bash
# Capture Target auf RAM setzen (schneller):
gphoto2 --set-config capturetarget=0

# Aktuelle Einstellungen prüfen:
gphoto2 --get-config capturetarget
gphoto2 --get-config imageformat

# Alle verfügbaren Einstellungen anzeigen:
gphoto2 --list-config
```

### 4. **Hardware-Checks**

```bash
# USB-Verbindung prüfen:
lsusb | grep Canon

# gphoto2 Erkennung:
gphoto2 --auto-detect

# Kamera-Status:
gphoto2 --get-config /main/status/serialnumber

# Test-Foto:
gphoto2 --capture-image
```

## 🎭 **Spezifische Canon EOS Fehler**

### **Fehler: "Device Busy (0x2019)"**
```bash
# Spezieller Canon Fix:
sudo killall gphoto2
sudo systemctl stop gvfs-daemon
sleep 5
gphoto2 --reset
gphoto2 --capture-image
```

### **Fehler: "Out of Focus"**
- Kamera auf **manuellen Fokus** stellen oder
- Objektiv auf **Unendlich** fokussieren oder  
- **One-Shot AF** mit Target-Point in der Mitte

### **Fehler: "No Space Left"**
- **SD-Karte** entfernen (bei PC Connect nicht nötig) oder
- **Capture Target** auf `Internal RAM` setzen:
  ```bash
  gphoto2 --set-config capturetarget=0
  ```

## 🔄 **Systematische Problemlösung**

### **Schritt 1: Kamera zurücksetzen**
1. Kamera **ausschalten**
2. USB-Kabel **abziehen** 
3. 10 Sekunden warten
4. Kamera **einschalten**
5. USB **wieder anschließen**
6. Kamera auf **"PC Connect"** stellen

### **Schritt 2: System zurücksetzen**
```bash
# Kompletter Reset:
sudo killall gphoto2 gvfs-gphoto2-volume-monitor
sudo systemctl stop gvfs-daemon
sudo modprobe -r uvcvideo
sleep 5
sudo modprobe uvcvideo
sudo systemctl restart photobox
```

### **Schritt 3: Test-Aufnahme**
```bash
# Direkte Aufnahme testen:
cd /home/pi/Photobox
.venv/bin/python -c "
from camera_manager import CameraManager
cam = CameraManager()
result = cam.capture_photo()
print('✅ Erfolg!' if result['success'] else f'❌ Fehler: {result[\"error\"]}')
"
```

## 📋 **Photobox App Logs prüfen**

```bash
# Live Logs der Photobox App:
sudo journalctl -u photobox -f

# Kamera-spezifische Logs:
tail -f /var/log/photobox_app.log | grep -i camera

# Fehler-Logs:
sudo journalctl -u photobox | grep -i "error\|fail\|exception"
```

## 🎯 **Canon EOS Modell-spezifische Tipps**

### **Canon EOS 1500D/2000D:**
- USB-Kabel: **Original Canon** oder hochwertiges USB-C zu USB-A
- **Scene Intelligent Auto** deaktivieren → Manual Mode
- **Wi-Fi/NFC** komplett deaktivieren
- **Live View** ausschalten während Aufnahme

### **Canon EOS 4000D/3000D:**
- Ähnlich wie 1500D/2000D
- **Auto ISO** auf festen Wert setzen
- **Bildstabilisator** bei Stativ ausschalten

## 🚨 **Notfall-Lösungen**

### **Kamera hängt komplett:**
```bash
# Hardware-Reset:
sudo rmmod uvcvideo
sudo rmmod gphoto2
sudo modprobe gphoto2
sudo modprobe uvcvideo

# Kamera aus/ein schalten
# USB neu anschließen
```

### **Photobox App erkennt Kamera nicht:**
```bash
# App mit Kamera-Debug starten:
cd /home/pi/Photobox
DEBUG=1 .venv/bin/python app.py
```

## 📞 **Support & Weitere Hilfe**

Wenn diese Lösungen nicht helfen:

1. **Führe vollständige Diagnose aus:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/diagnose_camera.sh | sudo bash > kamera_diagnose.txt
   ```

2. **Sammle Debug-Informationen:**
   ```bash
   lsusb | grep Canon > debug_info.txt
   gphoto2 --auto-detect >> debug_info.txt
   gphoto2 --capture-image 2>&1 >> debug_info.txt
   ```

3. **GitHub Issue erstellen:** https://github.com/marion909/Fotobox/issues
   - Kamera-Modell angeben
   - Diagnose-Output anhängen
   - Debug-Informationen beifügen

## ✅ **Erfolgskontrolle**

Nach dem Fix sollten diese Tests erfolgreich sein:

```bash
✅ gphoto2 --auto-detect          # Zeigt Kamera
✅ gphoto2 --capture-image        # Macht Foto
✅ curl http://localhost:5000     # Photobox erreichbar
✅ Foto-Button in Photobox        # Funktioniert
```

**Die meisten Canon EOS Probleme sind USB/Software-Konflikte die sich mit den obigen Schritten lösen lassen!** 📸