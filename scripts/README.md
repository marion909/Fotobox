# 📸 Fotobox Scripts - Management System

## 🎯 Neue vereinfachte Script-Struktur

**Von 13 Scripts auf 4 reduziert!** Das neue Management-System macht alle Fotobox-Operationen einfacher und übersichtlicher.

## 📁 Script-Übersicht

### **🚀 Hauptscripts:**

| Script | Zweck | Verwendung |
|--------|-------|------------|
| `install_complete.sh` | Komplette Fotobox-Installation | `curl -fsSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/install_complete.sh \| sudo bash` |
| `manage_fotobox.sh` | **Unified Management Tool** | `sudo ./manage_fotobox.sh` |
| `setup_printer.sh` | Drucker-spezifische Konfiguration | `sudo ./setup_printer.sh` |
| `install_autostart.sh` | Autostart-Service Installation | `sudo ./install_autostart.sh` |

### **🔧 Management-Tool Features:**

Das `manage_fotobox.sh` ersetzt alle diese Scripts:
- ~~debug_camera_not_connected.sh~~
- ~~debug_gphoto2_file_creation.sh~~
- ~~diagnose_camera.sh~~
- ~~diagnose_installation.sh~~
- ~~fix_camera_busy.sh~~
- ~~fix_camera_usb.sh~~
- ~~quick_fix.sh~~
- ~~update_photobox.sh~~
- ~~cleanup_photobox.sh~~

## 🎮 Management-Tool Verwendung

### **Interaktives Menü:**
```bash
sudo ./manage_fotobox.sh
```

### **Direkte Befehle:**
```bash
# Installation
sudo ./manage_fotobox.sh --install

# Kamera-Diagnose  
./manage_fotobox.sh --diagnose

# USB-Probleme beheben
sudo ./manage_fotobox.sh --fix-usb

# System updaten
sudo ./manage_fotobox.sh --update

# Schnelle Problembehebung
sudo ./manage_fotobox.sh --quick-fix

# System-Status
./manage_fotobox.sh --status

# Vollständige Deinstallation
sudo ./manage_fotobox.sh --cleanup

# Hilfe
./manage_fotobox.sh --help
```

## 📋 Verfügbare Aktionen

### **🔧 Installation & Setup:**
- Komplette Installation
- Optimal Camera Setup
- Drucker Setup
- Autostart konfigurieren

### **🔍 Diagnose & Debug:**
- Vollständige Systemdiagnose
- Kamera-Verbindungsprobleme
- USB-Probleme beheben
- Canon EOS Device Busy Fix
- Foto-Erstellungsprobleme

### **🛠️ Wartung & Update:**
- Fotobox updaten
- Quick-Fix (häufige Probleme)
- Vollständige Deinstallation

### **ℹ️ Info & Hilfe:**
- System-Status anzeigen
- Hilfe & Dokumentation

## 🔄 Migration von alten Scripts

Falls Sie noch alte Scripts haben:

```bash
# Konsolidierung durchführen
chmod +x consolidate_scripts.sh
./consolidate_scripts.sh
```

## 🎯 Vorteile der neuen Struktur

✅ **Einfacher:** 1 Tool statt 13 Scripts  
✅ **Übersichtlich:** Menü-geführte Bedienung  
✅ **Mächtig:** Alle Funktionen in einem Tool  
✅ **Konsistent:** Einheitliche Ausgabe und Bedienung  
✅ **Wartbar:** Ein Script zu pflegen statt 13  
✅ **Flexibel:** Interaktiv oder per Command-Line  

## 🚀 Schnellstart

1. **Erste Installation:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/install_complete.sh | sudo bash
   ```

2. **Management nach Installation:**
   ```bash
   cd /home/pi/Fotobox/scripts
   sudo ./manage_fotobox.sh
   ```

3. **Probleme diagnostizieren:**
   ```bash
   ./manage_fotobox.sh --diagnose
   ```

4. **Updates:**
   ```bash
   sudo ./manage_fotobox.sh --update
   ```

## 📞 Support

Bei Problemen:
1. System-Status prüfen: `./manage_fotobox.sh --status`
2. Diagnose durchführen: `./manage_fotobox.sh --diagnose`
3. Quick-Fix versuchen: `sudo ./manage_fotobox.sh --quick-fix`
4. GitHub Issues: https://github.com/marion909/Fotobox/issues

## 📖 Weitere Ressourcen

- **GitHub Repository:** https://github.com/marion909/Fotobox
- **Installation Guide:** https://github.com/marion909/Fotobox/wiki
- **Troubleshooting:** https://github.com/marion909/Fotobox/wiki/Troubleshooting